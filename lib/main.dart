import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'google_web_button.dart'
if (dart.library.js_interop) 'google_web_button_web.dart';

void main() {
  runApp(const MisFinanzasApp());
}

const List<Map<String, String>> categoriasPatrimonioIniciales = [
  {'nombre': 'Cash', 'emoji': '💵'},
  {'nombre': 'Banco', 'emoji': '🏦'},
  {'nombre': 'Revolut', 'emoji': '💳'},
  {'nombre': 'Invertido', 'emoji': '📈'},
];

// ============================================================
// APP
// ============================================================

class MisFinanzasApp extends StatefulWidget {
  const MisFinanzasApp({super.key});

  @override
  State<MisFinanzasApp> createState() => _MisFinanzasAppState();
}

class _MisFinanzasAppState extends State<MisFinanzasApp> {
  bool modoOscuro = false;
  bool cargandoTema = true;

  @override
  void initState() {
    super.initState();
    cargarTema();
  }

  Future<void> cargarTema() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      modoOscuro = prefs.getBool('modo_oscuro') ?? false;
      cargandoTema = false;
    });
  }

  Future<void> cambiarModoOscuro(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_oscuro', valor);
    if (!mounted) return;
    setState(() {
      modoOscuro = valor;
    });
  }

  ThemeData temaClaro() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  ThemeData temaOscuro() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargandoTema) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mis Finanzas',
        theme: temaClaro(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mis Finanzas',
      theme: temaClaro(),
      darkTheme: temaOscuro(),
      themeMode: modoOscuro ? ThemeMode.dark : ThemeMode.light,
      home: Aplicacion(
        modoOscuro: modoOscuro,
        onModoOscuroChanged: cambiarModoOscuro,
      ),
    );
  }
}

// ============================================================
// CATEGORÍAS INICIALES
// ============================================================

const List<Map<String, dynamic>> categoriasGastosIniciales = [
  {
    'nombre': 'Alquiler',
    'emoji': '🔑',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Gastos históricos',
    'emoji': '📊',
    'subcategorias': <String>[],
    'ocultaAlAnadir': false,
  },
  {
    'nombre': 'Compras',
    'emoji': '💳',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Deporte',
    'emoji': '🏋️',
    'subcategorias': <String>['Gym', 'Suplementos', 'Otros'],
  },
  {
    'nombre': 'Hipotecas',
    'emoji': '🏦',
    'subcategorias': <String>['Afán', 'Fco Carrera', 'Otros'],
  },
  {
    'nombre': 'Pisos',
    'emoji': '🏠',
    'subcategorias': <String>['Obras', 'Mantenimiento', 'Electrodomésticos', 'Comunidad', 'Seguro hogar', 'IBI', 'Otros'],
  },
  {
    'nombre': 'Salidas',
    'emoji': '🍻',
    'subcategorias': <String>['Cafeterías', 'Comidas', 'Beber y salir', 'Cititas', 'Otros'],
  },
  {
    'nombre': 'Supermercado',
    'emoji': '🛒',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Suscripciones',
    'emoji': '🔄',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Transporte',
    'emoji': '🚌',
    'subcategorias': <String>['Taxis', 'Abono', 'Otros'],
  },
  {
    'nombre': 'Viajes',
    'emoji': '✈️',
    'subcategorias': <String>['Vuelos', 'Hoteles', 'Tours / entradas', 'Otros'],
  },
  {
    'nombre': 'Miscelánea',
    'emoji': '📦',
    'subcategorias': <String>[],
  },
];

const List<Map<String, dynamic>> categoriasIngresosIniciales = [
  {
    'nombre': 'Salario',
    'emoji': '💼',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Pieris',
    'emoji': '💆',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Alquileres',
    'emoji': '🏘️',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Ticket restaurante',
    'emoji': '🍽️',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Miscelánea',
    'emoji': '💰',
    'subcategorias': <String>[],
  },
];

// ============================================================
// UTILIDADES
// ============================================================

String formatearEuros(double valor) {
  return '${valor.toStringAsFixed(2)} €';
}

String formatearEurosRedondeados(double valor) {
  return '${valor.round()} €';
}

String fechaTexto(DateTime fecha) {
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';
}

DateTime convertirFecha(String texto) {
  try {
    final partes = texto.split('/');

    if (partes.length != 3) {
      return DateTime(1900);
    }

    return DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );
  } catch (_) {
    return DateTime(1900);
  }
}

DateTime fechaHoraMovimiento(Map<String, dynamic> movimiento) {
  final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');
  if (fecha.year == 1900) return fecha;

  final horaTexto = movimiento['hora']?.toString() ?? '';
  final partesHora = horaTexto.split(':');
  final hora = partesHora.isNotEmpty ? int.tryParse(partesHora[0]) ?? 0 : 0;
  final minuto = partesHora.length > 1 ? int.tryParse(partesHora[1]) ?? 0 : 0;

  return DateTime(fecha.year, fecha.month, fecha.day, hora, minuto);
}

int compararMovimientosPorFechaHoraDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    ) {
  final porFechaHora = fechaHoraMovimiento(b).compareTo(fechaHoraMovimiento(a));
  if (porFechaHora != 0) return porFechaHora;

  final idA = int.tryParse(a['id']?.toString() ?? '');
  final idB = int.tryParse(b['id']?.toString() ?? '');
  if (idA != null && idB != null) return idB.compareTo(idA);

  return (b['id']?.toString() ?? '').compareTo(a['id']?.toString() ?? '');
}

int compararMovimientosPorFechaHoraAsc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    ) {
  return compararMovimientosPorFechaHoraDesc(b, a);
}

String nombreMes(DateTime fecha) {
  const meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  return meses[fecha.month - 1];
}

DateTime sumarMeses(DateTime fecha, int meses) {
  final objetivo = DateTime(fecha.year, fecha.month + meses, 1);
  final ultimoDia = DateTime(objetivo.year, objetivo.month + 1, 0).day;
  return DateTime(
    objetivo.year,
    objetivo.month,
    fecha.day > ultimoDia ? ultimoDia : fecha.day,
  );
}


// ============================================================
// DIVISAS
// ============================================================

const List<Map<String, String>> monedasDisponibles = [
  {'codigo': 'EUR', 'nombre': 'Euro', 'pais': 'Europa'},
  {'codigo': 'HUF', 'nombre': 'Forinto húngaro', 'pais': 'Hungría'},
  {'codigo': 'USD', 'nombre': 'Dólar estadounidense', 'pais': 'Estados Unidos'},
  {'codigo': 'GBP', 'nombre': 'Libra esterlina', 'pais': 'Reino Unido'},
  {'codigo': 'BRL', 'nombre': 'Real brasileño', 'pais': 'Brasil'},
  {'codigo': 'JPY', 'nombre': 'Yen japonés', 'pais': 'Japón'},
  {'codigo': 'CZK', 'nombre': 'Corona checa', 'pais': 'Chequia'},
  {'codigo': 'PLN', 'nombre': 'Zloty polaco', 'pais': 'Polonia'},
  {'codigo': 'CHF', 'nombre': 'Franco suizo', 'pais': 'Suiza'},
  {'codigo': 'DKK', 'nombre': 'Corona danesa', 'pais': 'Dinamarca'},
  {'codigo': 'SEK', 'nombre': 'Corona sueca', 'pais': 'Suecia'},
  {'codigo': 'NOK', 'nombre': 'Corona noruega', 'pais': 'Noruega'},
  {'codigo': 'CAD', 'nombre': 'Dólar canadiense', 'pais': 'Canadá'},
  {'codigo': 'AUD', 'nombre': 'Dólar australiano', 'pais': 'Australia'},
  {'codigo': 'CNY', 'nombre': 'Yuan chino', 'pais': 'China'},
  {'codigo': 'MXN', 'nombre': 'Peso mexicano', 'pais': 'México'},
  {'codigo': 'NZD', 'nombre': 'Dólar neozelandés', 'pais': 'Nueva Zelanda'},
  {'codigo': 'SGD', 'nombre': 'Dólar de Singapur', 'pais': 'Singapur'},
  {'codigo': 'HKD', 'nombre': 'Dólar de Hong Kong', 'pais': 'Hong Kong'},
  {'codigo': 'KRW', 'nombre': 'Won surcoreano', 'pais': 'Corea del Sur'},
  {'codigo': 'INR', 'nombre': 'Rupia india', 'pais': 'India'},
  {'codigo': 'THB', 'nombre': 'Baht tailandés', 'pais': 'Tailandia'},
  {'codigo': 'MYR', 'nombre': 'Ringgit malasio', 'pais': 'Malasia'},
  {'codigo': 'IDR', 'nombre': 'Rupia indonesia', 'pais': 'Indonesia'},
  {'codigo': 'PHP', 'nombre': 'Peso filipino', 'pais': 'Filipinas'},
  {'codigo': 'ZAR', 'nombre': 'Rand sudafricano', 'pais': 'Sudáfrica'},
  {'codigo': 'TRY', 'nombre': 'Lira turca', 'pais': 'Turquía'},
  {'codigo': 'ILS', 'nombre': 'Nuevo séquel israelí', 'pais': 'Israel'},
  {'codigo': 'RON', 'nombre': 'Leu rumano', 'pais': 'Rumanía'},
  {'codigo': 'BGN', 'nombre': 'Lev búlgaro', 'pais': 'Bulgaria'},
  {'codigo': 'ISK', 'nombre': 'Corona islandesa', 'pais': 'Islandia'},
];

const Set<String> monedasPorDefectoIniciales = {'EUR', 'HUF', 'USD', 'GBP'};

String formatearNumero(double valor) {
  return valor.toStringAsFixed(2).replaceAll('.', ',');
}

String nombreMoneda(String codigo) {
  for (final moneda in monedasDisponibles) {
    if (moneda['codigo'] == codigo) return moneda['nombre']!;
  }
  return codigo;
}

class ServicioDivisas {
  static Future<double> obtenerCambioAEuro(String moneda, DateTime fecha) async {
    if (moneda == 'EUR') return 1.0;

    final fechaInicio = fecha.subtract(const Duration(days: 30));
    final inicio = '${fechaInicio.year.toString().padLeft(4, '0')}-${fechaInicio.month.toString().padLeft(2, '0')}-${fechaInicio.day.toString().padLeft(2, '0')}';
    final fin = '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
      'https://data-api.ecb.europa.eu/service/data/EXR/D.$moneda.EUR.SP00.A?startPeriod=$inicio&endPeriod=$fin&format=csvdata',
    );

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/csv');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final lineas = body.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
        if (lineas.length >= 2) {
          final separador = lineas.first.contains(';') ? ';' : ',';
          final cabecera = lineas.first.split(separador).map((x) => x.trim().replaceAll('"', '')).toList();
          final indiceValor = cabecera.indexOf('OBS_VALUE');
          for (int i = lineas.length - 1; i >= 1; i--) {
            final campos = lineas[i].split(separador).map((x) => x.trim().replaceAll('"', '')).toList();
            final candidatos = <String>[];
            if (indiceValor >= 0 && indiceValor < campos.length) candidatos.add(campos[indiceValor]);
            candidatos.addAll(campos.reversed);
            for (final texto in candidatos) {
              final valor = double.tryParse(texto.replaceAll(',', '.'));
              if (valor != null && valor > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('fx_$moneda', valor);
                return valor;
              }
            }
          }
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getDouble('fx_$moneda');
    if (cache != null && cache > 0) return cache;
    return 0.0;
  }
}


// ============================================================
// GOOGLE / SINCRONIZACIÓN
// ============================================================

/// ID de cliente OAuth de tipo "Aplicación web".
///
/// Todavía no lo rellenamos porque Google Cloud debe tener creado el cliente
/// web además del cliente Android. Cuando lo creemos, sustituiremos este
/// valor por el ID real.
const String googleServerClientId = '32193813079-q9461ho6s57j7k6c46tgcm3p9d51uip5.apps.googleusercontent.com';

const List<String> googleDriveScopes = <String>[
  'https://www.googleapis.com/auth/drive.appdata',
];

class ServicioGoogleDrive {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _usuario;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  GoogleSignInAccount? get usuario => _usuario;
  bool get tieneDriveAutorizado => _driveApi != null;

  void crearDriveDesdeAutorizacion(
      GoogleSignInClientAuthorization autorizacion,
      ) {
    _driveApi = drive.DriveApi(
      autorizacion.authClient(scopes: googleDriveScopes),
    );
  }

  Future<void> inicializar() async {
    // En Web, google_sign_in_web obtiene el Client ID del meta-tag
    // de web/index.html y NO admite serverClientId.
    // En Android sí necesitamos el Web Client ID como serverClientId.
    if (kIsWeb) {
      await _googleSignIn.initialize();
    } else {
      await _googleSignIn.initialize(
        serverClientId:
        googleServerClientId.isEmpty ? null : googleServerClientId,
      );
    }

    await _authSubscription?.cancel();
    _authSubscription = _googleSignIn.authenticationEvents.listen((evento) {
      if (evento is GoogleSignInAuthenticationEventSignIn) {
        _usuario = evento.user;
      } else if (evento is GoogleSignInAuthenticationEventSignOut) {
        _usuario = null;
        _driveApi = null;
      }
    });

    try {
      final cuenta = await _googleSignIn.attemptLightweightAuthentication();
      if (cuenta != null) {
        _usuario = cuenta;
      }
    } catch (_) {
      // Si no existe una sesión previa, el usuario podrá iniciar sesión
      // explícitamente desde Ajustes.
    }
  }

  Future<GoogleSignInAccount?> iniciarSesion() async {
    if (googleServerClientId.isEmpty) {
      throw Exception(
        'Falta configurar el cliente OAuth de Google en la aplicación.',
      );
    }

    if (!_googleSignIn.supportsAuthenticate()) {
      throw Exception(
        'WEB_SIGN_IN_UI_REQUIRED',
      );
    }

    final cuenta = await _googleSignIn.authenticate(
      scopeHint: googleDriveScopes,
    );
    _usuario = cuenta;

    final autorizacion = await cuenta.authorizationClient.authorizeScopes(
      googleDriveScopes,
    );

    _driveApi = drive.DriveApi(
      autorizacion.authClient(scopes: googleDriveScopes),
    );

    return cuenta;
  }

  Future<void> prepararSesionExistente() async {
    final cuenta = _usuario;
    if (cuenta == null) return;

    try {
      final autorizacion =
      await cuenta.authorizationClient.authorizationForScopes(
        googleDriveScopes,
      );
      if (autorizacion != null) {
        crearDriveDesdeAutorizacion(autorizacion);
      }
    } catch (_) {}
  }

  Future<void> cerrarSesion() async {
    _driveApi = null;
    _usuario = null;
    await _googleSignIn.signOut();
  }

  Future<String?> _buscarArchivo() async {
    final api = _driveApi;
    if (api == null) return null;

    final resultado = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = 'mis_finanzas_sync.json' and trashed = false",
      $fields: 'files(id,name)',
      pageSize: 10,
    );

    if (resultado.files == null || resultado.files!.isEmpty) return null;
    return resultado.files!.first.id;
  }

  Future<void> subirDatos(Map<String, dynamic> datos) async {
    final api = _driveApi;
    if (api == null) {
      throw Exception('No hay una cuenta de Google conectada.');
    }

    final contenido = jsonEncode(datos);
    final bytes = utf8.encode(contenido);
    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
    );

    final existente = await _buscarArchivo();

    if (existente == null) {
      final metadata = drive.File()
        ..name = 'mis_finanzas_sync.json'
        ..parents = <String>['appDataFolder'];

      await api.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id,name',
      );
    } else {
      final metadata = drive.File()..name = 'mis_finanzas_sync.json';
      await api.files.update(
        metadata,
        existente,
        uploadMedia: media,
        $fields: 'id,name',
      );
    }
  }

  Future<Map<String, dynamic>?> descargarDatos() async {
    final api = _driveApi;
    if (api == null) {
      throw Exception('No hay una cuenta de Google conectada.');
    }

    final id = await _buscarArchivo();
    if (id == null) return null;

    final respuesta = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (respuesta is! drive.Media) return null;

    final contenido =
    await respuesta.stream.transform(utf8.decoder).join();
    final datos = jsonDecode(contenido);

    if (datos is! Map) return null;
    return Map<String, dynamic>.from(datos);
  }
}

// ============================================================
// APLICACIÓN
// ============================================================

class Aplicacion extends StatefulWidget {
  final bool modoOscuro;
  final Future<void> Function(bool) onModoOscuroChanged;

  const Aplicacion({
    super.key,
    required this.modoOscuro,
    required this.onModoOscuroChanged,
  });

  @override
  State<Aplicacion> createState() => _AplicacionState();
}

class _AplicacionState extends State<Aplicacion> with WidgetsBindingObserver {
  int paginaActual = 0;

  List<Map<String, dynamic>> movimientos = [];

  List<Map<String, dynamic>> categoriasGastos = [];

  List<Map<String, dynamic>> categoriasIngresos = [];

  double balanceInicial = 0;

  List<Map<String, dynamic>> correcciones = [];

  List<Map<String, dynamic>> historicos = [];

  List<Map<String, dynamic>> patrimonios = [];
  List<Map<String, String>> categoriasPatrimonio =
  categoriasPatrimonioIniciales
      .map((e) => Map<String, String>.from(e))
      .toList();

  DateTime mesSeleccionado = DateTime.now();

  bool cargando = true;
  bool _mostrarOpcionesFab = false;
  String? _filtroMovimientosInicio;
  bool _mostrarProximosMovimientos = false;
  Timer? _timerCambiosPendientes;
  Timer? _timerComprobacionSincronizacion;
  Timer? _timerSubidaAutomatica;

  final ServicioGoogleDrive _googleDrive = ServicioGoogleDrive();
  bool _googleInicializado = false;
  bool _googleSincronizando = false;
  bool _datosInicialesCargados = false;
  bool _sincronizacionAutomaticaActiva = false;
  bool _sincronizacionEnCurso = false;
  bool _aplicandoDatosRemotos = false;
  String? _ultimaModificacionLocal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerCambiosPendientes = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) actualizarCambiosPendientes();
    });
    _timerComprobacionSincronizacion = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _comprobarSincronizacionAutomatica();
    });
    _inicializarGoogle();
    cargarDatos();
  }

  Future<void> _inicializarGoogle() async {
    try {
      await _googleDrive.inicializar();
      _googleInicializado = true;
      await _googleDrive.prepararSesionExistente();
      if (mounted) setState(() {});
      await _inicializarSincronizacionAutomaticaSiProcede();
    } catch (_) {
      _googleInicializado = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerCambiosPendientes?.cancel();
    _timerComprobacionSincronizacion?.cancel();
    _timerSubidaAutomatica?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      actualizarCambiosPendientes();
      _comprobarSincronizacionAutomatica();
    }
  }

  // ==========================================================
  // CARGAR
  // ==========================================================

  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    _ultimaModificacionLocal = prefs.getString('ultima_modificacion_local');

    final movimientosGuardados =
    prefs.getString('movimientos');

    final gastosGuardados =
    prefs.getString('categorias_gastos');

    final ingresosGuardados =
    prefs.getString('categorias_ingresos');

    final correccionesGuardadas =
    prefs.getString('correcciones');

    final balanceGuardado =
    prefs.getDouble('balance_inicial');

    final historicosGuardados = prefs.getString('historicos');
    final patrimoniosGuardados = prefs.getString('patrimonios');
    final categoriasPatrimonioGuardadas =
    prefs.getString('categorias_patrimonio');

    setState(() {
      if (movimientosGuardados != null) {
        try {
          movimientos =
          List<Map<String, dynamic>>.from(
            jsonDecode(movimientosGuardados).map(
                  (item) => Map<String, dynamic>.from(item),
            ),
          );

          for (final movimiento in movimientos) {
            if (movimiento['recurrente'] == true) {
              final intervalo =
                  (movimiento['intervaloMeses'] as num?)?.toInt() ?? 1;
              movimiento['intervaloMeses'] = intervalo < 1 ? 1 : intervalo;
            }
          }
        } catch (_) {}
      }

      if (gastosGuardados != null) {
        try {
          categoriasGastos =
          List<Map<String, dynamic>>.from(
            jsonDecode(gastosGuardados).map(
                  (item) {
                final mapa =
                Map<String, dynamic>.from(item);

                mapa['subcategorias'] =
                List<String>.from(
                  mapa['subcategorias'] ?? [],
                );

                return mapa;
              },
            ),
          );
        } catch (_) {
          categoriasGastos =
              copiarCategorias(
                categoriasGastosIniciales,
              );
        }
      } else {
        categoriasGastos =
            copiarCategorias(
              categoriasGastosIniciales,
            );
      }

      if (ingresosGuardados != null) {
        try {
          categoriasIngresos =
          List<Map<String, dynamic>>.from(
            jsonDecode(ingresosGuardados).map(
                  (item) {
                final mapa =
                Map<String, dynamic>.from(item);

                mapa['subcategorias'] =
                List<String>.from(
                  mapa['subcategorias'] ?? [],
                );

                return mapa;
              },
            ),
          );
        } catch (_) {
          categoriasIngresos =
              copiarCategorias(
                categoriasIngresosIniciales,
              );
        }
      } else {
        categoriasIngresos =
            copiarCategorias(
              categoriasIngresosIniciales,
            );
      }

      // Migración de categorías antiguas.
      for (final categoria in categoriasGastos) {
        if (categoria['nombre']?.toString() == 'Otros') {
          categoria['nombre'] = 'Miscelánea';
        }
      }
      for (final categoria in categoriasIngresos) {
        if (categoria['nombre']?.toString() == 'Otros') {
          categoria['nombre'] = 'Miscelánea';
        }
      }
      for (final movimiento in movimientos) {
        if (movimiento['categoria']?.toString() == 'Otros') {
          movimiento['categoria'] = 'Miscelánea';
          movimiento['emoji'] = '📦';
        }
      }
      for (final movimiento in movimientos) {
        movimiento['moneda'] = movimiento['moneda']?.toString() ?? 'EUR';
        movimiento['cantidadOriginal'] = ((movimiento['cantidadOriginal'] as num?) ?? (movimiento['cantidad'] as num?) ?? 0).toDouble();
        movimiento['tipoCambio'] = ((movimiento['tipoCambio'] as num?) ?? 1).toDouble();
        movimiento['tipoCambioPendiente'] = movimiento['tipoCambioPendiente'] == true;
      }

      // Las recurrencias tienen una plantilla separada de las entradas históricas.
      // Esto permite cambiar el sueldo desde un mes en adelante sin modificar meses pasados.
      for (final movimiento in movimientos) {
        if (movimiento['recurrente'] == true && movimiento['recurrenceId'] == null) {
          movimiento['plantillaCantidad'] ??= movimiento['cantidad'];
          movimiento['plantillaCantidadOriginal'] ??= movimiento['cantidadOriginal'];
          movimiento['plantillaMoneda'] ??= movimiento['moneda'] ?? 'EUR';
          movimiento['plantillaTipoCambio'] ??= movimiento['tipoCambio'] ?? 1;
          movimiento['plantillaTipoCambioPendiente'] ??= movimiento['tipoCambioPendiente'] == true;
          movimiento['plantillaCategoria'] ??= movimiento['categoria'];
          movimiento['plantillaSubcategoria'] ??= movimiento['subcategoria'];
          movimiento['plantillaEmoji'] ??= movimiento['emoji'];
          movimiento['plantillaNota'] ??= movimiento['nota'] ?? '';
          movimiento['plantillaFotoPath'] ??= movimiento['fotoPath'];
          movimiento['plantillaIntervaloMeses'] ??= movimiento['intervaloMeses'] ?? 1;
        }
      }

      // GASTOS HISTÓRICOS es una categoría de gasto NORMAL.
      // Se crea automáticamente si no existe y queda visible al añadir gastos.
      // El usuario puede ocultarla después desde Ajustes > Editar gastos.
      final historicosExistentes = categoriasGastos.where(
            (c) => c['nombre']?.toString().trim().toLowerCase() == 'gastos históricos',
      ).toList();

      if (historicosExistentes.isEmpty) {
        categoriasGastos.insert(1, {
          'nombre': 'Gastos históricos',
          'emoji': '📊',
          'subcategorias': <String>[],
          'archivada': false,
          'ocultaAlAnadir': false,
        });
      } else {
        // Normaliza posibles copias antiguas y garantiza que la categoría
        // no quede archivada ni oculta por una configuración anterior.
        final historicos = historicosExistentes.first;
        historicos['nombre'] = 'Gastos históricos';
        historicos['emoji'] = '📊';
        historicos['subcategorias'] = <String>[];
        historicos['archivada'] = false;
        historicos['ocultaAlAnadir'] = false;

        if (historicosExistentes.length > 1) {
          for (final extra in historicosExistentes.skip(1)) {
            categoriasGastos.remove(extra);
          }
        }
      }
      for (final categoria in [...categoriasGastos, ...categoriasIngresos]) {
        categoria['ocultaAlAnadir'] = categoria['ocultaAlAnadir'] == true;
      }

      // Migración de categorías y subcategorías:
      // - Cafeterías pasa a ser subcategoría de Salidas.
      // - Comunidad deja de existir como categoría independiente.
      // - Las categorías que ya tienen subcategorías reciben 'Otros'.
      final salidas = categoriasGastos.cast<Map<String, dynamic>>().where((c) => c['nombre'] == 'Salidas').toList();
      if (salidas.isNotEmpty) {
        final subs = List<String>.from(salidas.first['subcategorias'] ?? []);
        if (!subs.contains('Cafeterías')) subs.insert(0, 'Cafeterías');
        if (!subs.contains('Otros')) subs.add('Otros');
        salidas.first['subcategorias'] = subs;
      }

      for (final categoria in categoriasGastos) {
        final nombre = categoria['nombre']?.toString();
        if (nombre == 'Cafeterías' || nombre == 'Comunidad') {
          categoria['archivada'] = true;
        }
        final subs = List<String>.from(categoria['subcategorias'] ?? []);
        final nombreCategoria = categoria['nombre']?.toString();
        final subcategoriasSolicitadas = <String, List<String>>{
          'Deporte': ['Gym', 'Suplementos', 'Otros'],
          'Hipotecas': ['Afán', 'Fco Carrera', 'Otros'],
          'Pisos': ['Obras', 'Mantenimiento', 'Electrodomésticos', 'Comunidad', 'Seguro hogar', 'IBI', 'Otros'],
          'Salidas': ['Cafeterías', 'Comidas', 'Beber y salir', 'Cititas', 'Otros'],
          'Transporte': ['Taxis', 'Abono', 'Otros'],
          'Viajes': ['Vuelos', 'Hoteles', 'Tours / entradas', 'Otros'],
        };
        if (subcategoriasSolicitadas.containsKey(nombreCategoria)) {
          for (final solicitada in subcategoriasSolicitadas[nombreCategoria]!) {
            if (!subs.contains(solicitada)) subs.add(solicitada);
          }
          categoria['subcategorias'] = subs;
        }
        if (subs.isNotEmpty && !subs.contains('Otros')) {
          subs.add('Otros');
          categoria['subcategorias'] = subs;
        }
      }

      // Los antiguos movimientos de Cafeterías pasan a Salidas > Cafeterías.
      for (final movimiento in movimientos) {
        if (movimiento['categoria']?.toString() == 'Cafeterías') {
          movimiento['categoria'] = 'Salidas';
          movimiento['subcategoria'] = 'Cafeterías';
          movimiento['emoji'] = '🍻';
        }
      }

      if (correccionesGuardadas != null) {
        try {
          correcciones = List<Map<String, dynamic>>.from(
            jsonDecode(correccionesGuardadas).map(
                  (item) => Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {
          correcciones = [];
        }
      }

      // Las correcciones antiguas pasan a ser movimientos de tipo Ajuste.
      // Así aparecen en Movimientos, pero nunca cuentan como gasto o ingreso.
      for (final correccion in correcciones) {
        final fecha = correccion['fecha']?.toString() ?? '';
        final cantidad = ((correccion['cantidad'] as num?) ?? 0).toDouble();
        final yaExiste = movimientos.any((m) =>
        m['tipo'] == 'Ajuste' &&
            m['fecha']?.toString() == fecha &&
            (((m['cantidad'] as num?) ?? 0).toDouble() - cantidad).abs() < 0.005);
        if (!yaExiste && fecha.isNotEmpty && cantidad.abs() >= 0.005) {
          movimientos.add({
            'id': 'ajuste_${DateTime.now().microsecondsSinceEpoch}_${movimientos.length}',
            'cantidad': cantidad,
            'tipo': 'Ajuste',
            'categoria': 'Ajuste de saldo',
            'subcategoria': null,
            'emoji': '🔧',
            'fecha': fecha,
            'nota': 'Ajuste de saldo',
            'fotoPath': null,
            'recurrente': false,
            'intervaloMeses': 1,
            'recurrenceId': null,
          });
        }
      }
      correcciones = [];

      balanceInicial = balanceGuardado ?? 0;

      if (historicosGuardados != null) {
        try {
          historicos = List<Map<String, dynamic>>.from(
            jsonDecode(historicosGuardados).map((item) => Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          historicos = [];
        }
      }

      if (patrimoniosGuardados != null) {
        try {
          patrimonios = List<Map<String, dynamic>>.from(
            jsonDecode(patrimoniosGuardados).map((item) {
              final mapa = Map<String, dynamic>.from(item);
              mapa['cuentas'] = List<Map<String, dynamic>>.from(
                (mapa['cuentas'] ?? []).map((cuenta) => Map<String, dynamic>.from(cuenta)),
              );
              return mapa;
            }),
          );
        } catch (_) {
          patrimonios = [];
        }
      }

      if (categoriasPatrimonioGuardadas != null) {
        try {
          categoriasPatrimonio = List<Map<String, String>>.from(
            jsonDecode(categoriasPatrimonioGuardadas).map(
                  (item) => Map<String, String>.from(item),
            ),
          );
        } catch (_) {
          categoriasPatrimonio = categoriasPatrimonioIniciales
              .map((e) => Map<String, String>.from(e))
              .toList();
        }
      }

      cargando = false;
    });

    await guardarDatos(marcarComoCambioLocal: false);
    await generarRecurrentesPendientes();
    await actualizarCambiosPendientes();
    _datosInicialesCargados = true;
    await _inicializarSincronizacionAutomaticaSiProcede();
  }

  List<Map<String, dynamic>> copiarCategorias(
      List<Map<String, dynamic>> origen,
      ) {
    return origen.map((categoria) {
      return {
        'nombre': categoria['nombre'],
        'emoji': categoria['emoji'],
        'subcategorias':
        List<String>.from(
          categoria['subcategorias'] ?? [],
        ),
        'archivada': categoria['archivada'] == true,
        'ocultaAlAnadir': categoria['ocultaAlAnadir'] == true,
      };
    }).toList();
  }

  // ==========================================================
  // GOOGLE DRIVE
  // ==========================================================

  Map<String, dynamic> _datosParaSincronizar() {
    final fecha = _ultimaModificacionLocal ??
        DateTime.now().toUtc().toIso8601String();

    return {
      'version': 4,
      'fechaModificacion': fecha,
      'fechaSincronizacion': DateTime.now().toUtc().toIso8601String(),
      'movimientos': movimientos,
      'categoriasGastos': categoriasGastos,
      'categoriasIngresos': categoriasIngresos,
      'correcciones': correcciones,
      'balanceInicial': balanceInicial,
      'historicos': historicos,
      'patrimonios': patrimonios,
      'categoriasPatrimonio': categoriasPatrimonio,
    };
  }

  DateTime? _fechaDeDatosRemotos(Map<String, dynamic> datos) {
    final texto = (datos['fechaModificacion'] ??
        datos['fechaSincronizacion'])
        ?.toString();
    if (texto == null || texto.isEmpty) return null;
    return DateTime.tryParse(texto);
  }

  DateTime? _fechaDeDatosLocales() {
    if (_ultimaModificacionLocal == null ||
        _ultimaModificacionLocal!.isEmpty) {
      return null;
    }
    return DateTime.tryParse(_ultimaModificacionLocal!);
  }

  Future<void> _inicializarSincronizacionAutomaticaSiProcede() async {
    if (!_datosInicialesCargados ||
        !_googleInicializado ||
        _sincronizacionAutomaticaActiva) {
      return;
    }

    _sincronizacionAutomaticaActiva = true;
    await _comprobarSincronizacionAutomatica();
  }

  void _programarSubidaAutomatica() {
    if (!_sincronizacionAutomaticaActiva || _aplicandoDatosRemotos) return;

    _timerSubidaAutomatica?.cancel();
    _timerSubidaAutomatica = Timer(
      const Duration(milliseconds: 800),
          () => _subirCambiosAutomaticamente(),
    );
  }

  Future<void> _subirCambiosAutomaticamente() async {
    if (!_sincronizacionAutomaticaActiva ||
        _sincronizacionEnCurso ||
        _aplicandoDatosRemotos) {
      return;
    }

    final usuario = _googleDrive.usuario;
    if (usuario == null) return;

    try {
      await _googleDrive.prepararSesionExistente();
      if (!_googleDrive.tieneDriveAutorizado) return;

      _sincronizacionEnCurso = true;
      await _googleDrive.subirDatos(_datosParaSincronizar());
    } catch (_) {
      // Si no hay conexión, el dato queda guardado localmente y se reintentará.
    } finally {
      _sincronizacionEnCurso = false;
    }
  }

  Future<void> _comprobarSincronizacionAutomatica() async {
    if (!_sincronizacionAutomaticaActiva ||
        _sincronizacionEnCurso ||
        !_datosInicialesCargados ||
        _aplicandoDatosRemotos) {
      return;
    }

    final usuario = _googleDrive.usuario;
    if (usuario == null) return;

    try {
      await _googleDrive.prepararSesionExistente();
      if (!_googleDrive.tieneDriveAutorizado) return;

      _sincronizacionEnCurso = true;
      final datosRemotos = await _googleDrive.descargarDatos();

      if (datosRemotos == null) {
        if (_ultimaModificacionLocal == null) {
          _ultimaModificacionLocal =
              DateTime.now().toUtc().toIso8601String();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'ultima_modificacion_local',
            _ultimaModificacionLocal!,
          );
        }
        await _googleDrive.subirDatos(_datosParaSincronizar());
        return;
      }

      final fechaRemota = _fechaDeDatosRemotos(datosRemotos);
      final fechaLocal = _fechaDeDatosLocales();

      // Si no tenemos fecha local, la copia de Google es la referencia.
      if (fechaLocal == null && fechaRemota != null) {
        await _aplicarDatosSincronizados(datosRemotos);
        return;
      }

      if (fechaRemota != null &&
          fechaLocal != null &&
          fechaRemota.isAfter(fechaLocal)) {
        await _aplicarDatosSincronizados(datosRemotos);
      } else if (fechaLocal != null &&
          (fechaRemota == null || fechaLocal.isAfter(fechaRemota))) {
        await _googleDrive.subirDatos(_datosParaSincronizar());
      }
    } catch (_) {
      // Los fallos de red no interrumpen el uso de la aplicación.
    } finally {
      _sincronizacionEnCurso = false;
    }
  }

  Future<void> sincronizarConGoogle() async {
    try {
      await _asegurarGoogleDrive();
      if (!mounted) return;
      setState(() => _googleSincronizando = true);
      try {
        _ultimaModificacionLocal =
            DateTime.now().toUtc().toIso8601String();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'ultima_modificacion_local',
          _ultimaModificacionLocal!,
        );
        await _googleDrive.subirDatos(_datosParaSincronizar());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos sincronizados con Google')),
          );
        }
      } finally {
        if (mounted) setState(() => _googleSincronizando = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se ha podido sincronizar: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  /// En Web authorizeScopes() abre un popup OAuth y el navegador exige que
  /// la llamada nazca directamente de una acción del usuario.
  Future<bool> _autorizarGoogleDrive() async {
    final usuario = _googleDrive.usuario;
    if (usuario == null) {
      throw Exception('No se ha podido iniciar sesión con Google.');
    }

    await _googleDrive.prepararSesionExistente();
    if (_googleDrive.tieneDriveAutorizado) return true;

    if (!kIsWeb) {
      final autorizacion = await usuario.authorizationClient.authorizeScopes(
        googleDriveScopes,
      );
      _googleDrive.crearDriveDesdeAutorizacion(autorizacion);
      return _googleDrive.tieneDriveAutorizado;
    }

    final autorizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool procesando = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Autorizar Google Drive'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PastApp necesita permiso para guardar y recuperar tu copia de seguridad en Google Drive.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tus datos se guardan en el espacio privado de la aplicación de tu Google Drive.',
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: procesando
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: procesando
                      ? null
                      : () async {
                    setDialogState(() {
                      procesando = true;
                      error = null;
                    });
                    try {
                      // Esta llamada está directamente dentro de
                      // onPressed, por lo que el navegador permite el
                      // popup de autorización de Google.
                      final autorizacion = await usuario
                          .authorizationClient
                          .authorizeScopes(googleDriveScopes);
                      _googleDrive.crearDriveDesdeAutorizacion(
                        autorizacion,
                      );
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop(
                          _googleDrive.tieneDriveAutorizado,
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        procesando = false;
                        error = e
                            .toString()
                            .replaceFirst('Exception: ', '');
                      });
                    }
                  },
                  icon: procesando
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.cloud_done_outlined),
                  label: Text(
                    procesando ? 'Autorizando...' : 'Autorizar Drive',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return autorizado == true && _googleDrive.tieneDriveAutorizado;
  }

  Future<void> _asegurarGoogleDrive() async {
    if (!_googleInicializado) await _inicializarGoogle();

    if (_googleDrive.usuario == null) {
      if (kIsWeb) {
        await conectarGoogleDesdeAjustes();
      } else {
        await _googleDrive.iniciarSesion();
      }
    }

    if (_googleDrive.usuario == null) {
      throw Exception('No se ha podido iniciar sesión con Google.');
    }

    await _googleDrive.prepararSesionExistente();
    if (_googleDrive.tieneDriveAutorizado) return;

    final autorizado = await _autorizarGoogleDrive();
    if (!autorizado || !_googleDrive.tieneDriveAutorizado) {
      throw Exception('No se ha autorizado el acceso a Google Drive.');
    }
  }

  Future<void> restaurarDesdeGoogle() async {
    try {
      await _asegurarGoogleDrive();
      if (!mounted) return;
      setState(() => _googleSincronizando = true);
      try {
        final datos = await _googleDrive.descargarDatos();
        if (datos == null) {
          throw Exception('No existe todavía una copia en Google Drive.');
        }
        await _aplicarDatosSincronizados(datos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos restaurados desde Google')),
          );
        }
      } finally {
        if (mounted) setState(() => _googleSincronizando = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se ha podido restaurar: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _aplicarDatosSincronizados(
      Map<String, dynamic> datos) async {
    _aplicandoDatosRemotos = true;
    final nuevosMovimientos = List<Map<String, dynamic>>.from(
      (datos['movimientos'] ?? []).map(
            (item) => Map<String, dynamic>.from(item),
      ),
    );

    final nuevasCategoriasGastos =
    List<Map<String, dynamic>>.from(
      (datos['categoriasGastos'] ?? []).map((item) {
        final mapa = Map<String, dynamic>.from(item);
        mapa['subcategorias'] =
        List<String>.from(mapa['subcategorias'] ?? []);
        mapa['archivada'] = mapa['archivada'] == true;
        mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
        return mapa;
      }),
    );

    final nuevasCategoriasIngresos =
    List<Map<String, dynamic>>.from(
      (datos['categoriasIngresos'] ?? []).map((item) {
        final mapa = Map<String, dynamic>.from(item);
        mapa['subcategorias'] =
        List<String>.from(mapa['subcategorias'] ?? []);
        mapa['archivada'] = mapa['archivada'] == true;
        mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
        return mapa;
      }),
    );

    final nuevosHistoricos = List<Map<String, dynamic>>.from(
      (datos['historicos'] ?? []).map(
            (item) => Map<String, dynamic>.from(item),
      ),
    );

    final nuevosPatrimonios = List<Map<String, dynamic>>.from(
      (datos['patrimonios'] ?? []).map((item) {
        final mapa = Map<String, dynamic>.from(item);
        mapa['cuentas'] = List<Map<String, dynamic>>.from(
          (mapa['cuentas'] ?? []).map(
                (cuenta) => Map<String, dynamic>.from(cuenta),
          ),
        );
        return mapa;
      }),
    );

    final nuevasCategoriasPatrimonio =
    List<Map<String, String>>.from(
      (datos['categoriasPatrimonio'] ?? []).map(
            (item) => Map<String, String>.from(item),
      ),
    );

    setState(() {
      movimientos = nuevosMovimientos;
      categoriasGastos = nuevasCategoriasGastos.isEmpty
          ? copiarCategorias(categoriasGastosIniciales)
          : nuevasCategoriasGastos;
      categoriasIngresos = nuevasCategoriasIngresos.isEmpty
          ? copiarCategorias(categoriasIngresosIniciales)
          : nuevasCategoriasIngresos;
      correcciones = List<Map<String, dynamic>>.from(
        (datos['correcciones'] ?? []).map(
              (item) => Map<String, dynamic>.from(item),
        ),
      );
      balanceInicial =
          ((datos['balanceInicial'] as num?) ?? 0).toDouble();
      historicos = nuevosHistoricos;
      patrimonios = nuevosPatrimonios;
      if (nuevasCategoriasPatrimonio.isNotEmpty) {
        categoriasPatrimonio = nuevasCategoriasPatrimonio;
      }
    });

    final fechaRemota = _fechaDeDatosRemotos(datos);
    if (fechaRemota != null) {
      _ultimaModificacionLocal = fechaRemota.toUtc().toIso8601String();
    }

    try {
      await guardarDatos(marcarComoCambioLocal: false);
      await generarRecurrentesPendientes();
    } finally {
      _aplicandoDatosRemotos = false;
    }
  }


  Future<void> conectarGoogleDesdeAjustes() async {
    try {
      if (!_googleInicializado) await _inicializarGoogle();

      if (_googleDrive.usuario == null) {
        if (!_googleDriveSoportaAuthenticate()) {
          final conectado = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Conectar con Google'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Inicia sesión con el botón oficial de Google.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    botonGoogleWeb(
                      onSignedIn: () {
                        Navigator.of(dialogContext).pop(true);
                      },
                    ),
                  ],
                ),
              );
            },
          );
          if (conectado != true) return;
        } else {
          await _googleDrive.iniciarSesion();
        }
      }

      if (!mounted) return;
      final usuario = _googleDrive.usuario;
      if (usuario == null) {
        throw Exception('No se ha podido conectar la cuenta.');
      }

      await _googleDrive.prepararSesionExistente();
      if (!_googleDrive.tieneDriveAutorizado) {
        final autorizado = await _autorizarGoogleDrive();
        if (!autorizado) return;
      }

      if (!_googleDrive.tieneDriveAutorizado) {
        throw Exception(
          'Google se ha conectado, pero no se ha autorizado el acceso a Drive.',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google conectado: ${usuario.email}')),
      );
      setState(() {});
      await _inicializarSincronizacionAutomaticaSiProcede();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se ha podido conectar Google: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  bool _googleDriveSoportaAuthenticate() {
    return GoogleSignIn.instance.supportsAuthenticate();
  }

  Future<void> desconectarGoogleDesdeAjustes() async {
    try {
      await _googleDrive.cerrarSesion();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google desconectado'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se ha podido desconectar Google: $e')),
      );
    }
  }

  // ==========================================================
  // GUARDAR
  // ==========================================================

  Future<void> guardarDatos({bool marcarComoCambioLocal = true}) async {
    final prefs = await SharedPreferences.getInstance();

    if (marcarComoCambioLocal &&
        _datosInicialesCargados &&
        !_aplicandoDatosRemotos) {
      _ultimaModificacionLocal =
          DateTime.now().toUtc().toIso8601String();
      await prefs.setString(
        'ultima_modificacion_local',
        _ultimaModificacionLocal!,
      );
    }

    await prefs.setString(
      'movimientos',
      jsonEncode(movimientos),
    );

    await prefs.setString(
      'categorias_gastos',
      jsonEncode(categoriasGastos),
    );

    await prefs.setString(
      'categorias_ingresos',
      jsonEncode(categoriasIngresos),
    );

    await prefs.setString(
      'correcciones',
      jsonEncode(correcciones),
    );

    await prefs.setDouble(
      'balance_inicial',
      balanceInicial,
    );

    await prefs.setString('historicos', jsonEncode(historicos));
    await prefs.setString('patrimonios', jsonEncode(patrimonios));
    await prefs.setString(
      'categorias_patrimonio',
      jsonEncode(categoriasPatrimonio),
    );

    if (marcarComoCambioLocal &&
        _datosInicialesCargados &&
        !_aplicandoDatosRemotos) {
      _programarSubidaAutomatica();
    }
  }

  // ==========================================================
  // COPIA DE SEGURIDAD / RESTAURACIÓN
  // ==========================================================

  Future<void> exportarExcel() async {
    final excelFile = ex.Excel.createExcel();
    final sheet = excelFile['Movimientos'];

    sheet.appendRow([
      ex.TextCellValue('Fecha'),
      ex.TextCellValue('Tipo'),
      ex.TextCellValue('Categoría'),
      ex.TextCellValue('Subcategoría'),
      ex.TextCellValue('Importe original'),
      ex.TextCellValue('Moneda'),
      ex.TextCellValue('Cambio EUR'),
      ex.TextCellValue('Importe EUR'),
      ex.TextCellValue('Recurrente'),
      ex.TextCellValue('Intervalo (meses)'),
      ex.TextCellValue('Nota'),
    ]);

    final ordenados = List<Map<String, dynamic>>.from(movimientos)
      ..sort((a, b) => convertirFecha(a['fecha']?.toString() ?? '')
          .compareTo(convertirFecha(b['fecha']?.toString() ?? '')));

    for (final movimiento in ordenados) {
      sheet.appendRow([
        ex.TextCellValue(movimiento['fecha']?.toString() ?? ''),
        ex.TextCellValue(movimiento['tipo']?.toString() ?? ''),
        ex.TextCellValue(movimiento['categoria']?.toString() ?? ''),
        ex.TextCellValue(movimiento['subcategoria']?.toString() ?? ''),
        ex.DoubleCellValue(((movimiento['cantidadOriginal'] as num?) ?? (movimiento['cantidad'] as num?) ?? 0).toDouble()),
        ex.TextCellValue(movimiento['moneda']?.toString() ?? 'EUR'),
        ex.DoubleCellValue(((movimiento['tipoCambio'] as num?) ?? 1).toDouble()),
        ex.DoubleCellValue(((movimiento['cantidad'] as num?) ?? 0).toDouble()),
        ex.TextCellValue(movimiento['recurrente'] == true ? 'Sí' : 'No'),
        ex.IntCellValue(((movimiento['intervaloMeses'] as num?) ?? 1).toInt()),
        ex.TextCellValue(movimiento['nota']?.toString() ?? ''),
      ]);
    }

    final sheetAjustes = excelFile['Ajustes'];
    sheetAjustes.appendRow([
      ex.TextCellValue('Fecha'),
      ex.TextCellValue('Ajuste (€)'),
    ]);
    for (final ajuste in movimientos.where((m) => m['tipo'] == 'Ajuste')) {
      sheetAjustes.appendRow([
        ex.TextCellValue(ajuste['fecha']?.toString() ?? ''),
        ex.DoubleCellValue(((ajuste['cantidad'] as num?) ?? 0).toDouble()),
      ]);
    }

    final sheetHistorico = excelFile['Histórico'];
    sheetHistorico.appendRow([
      ex.TextCellValue('Año'), ex.TextCellValue('Mes'), ex.TextCellValue('Salario (€)'),
      ex.TextCellValue('Pieris (€)'), ex.TextCellValue('Hipoteca (€)'), ex.TextCellValue('Alquiler (€)'),
      ex.TextCellValue('Gastos totales histórico (€)'),
    ]);
    for (final h in historicos) {
      sheetHistorico.appendRow([
        ex.IntCellValue(((h['anio'] as num?) ?? DateTime.now().year).toInt()),
        ex.IntCellValue(((h['mes'] as num?) ?? 1).toInt()),
        ex.DoubleCellValue(((h['salario'] as num?) ?? 0).toDouble()),
        ex.DoubleCellValue(((h['pieris'] as num?) ?? 0).toDouble()),
        ex.DoubleCellValue(((h['hipoteca'] as num?) ?? 0).toDouble()),
        ex.DoubleCellValue(((h['alquiler'] as num?) ?? 0).toDouble()),
        ex.DoubleCellValue(((h['gastosTotalesHistorico'] as num?) ?? 0).toDouble()),
      ]);
    }

    final bytes = excelFile.save();
    if (bytes == null) return;

    final directorio = await getApplicationDocumentsDirectory();
    final archivo = File(
      '${directorio.path}/mis_finanzas_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.xlsx',
    );
    await archivo.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        text: 'Exportación de Mis Finanzas en Excel',
        files: [XFile(archivo.path)],
      ),
    );
  }

  Future<void> exportarDatos() async {
    final directorio = await getApplicationDocumentsDirectory();
    final marcaTiempo = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final archivo = File(
      '${directorio.path}/mis_finanzas_backup_$marcaTiempo.json',
    );

    final movimientosBackup = <Map<String, dynamic>>[];

    for (final movimiento in movimientos) {
      final copia = Map<String, dynamic>.from(movimiento);
      final rutaFoto = copia['fotoPath']?.toString();

      if (rutaFoto != null && rutaFoto.isNotEmpty) {
        final foto = File(rutaFoto);
        if (await foto.exists()) {
          try {
            copia['fotoBase64'] = base64Encode(await foto.readAsBytes());
            copia['fotoExtension'] = rutaFoto.contains('.')
                ? rutaFoto.substring(rutaFoto.lastIndexOf('.'))
                : '.jpg';
          } catch (_) {}
        }
      }

      movimientosBackup.add(copia);
    }

    final datos = {
      'version': 2,
      'fechaExportacion': DateTime.now().toIso8601String(),
      'movimientos': movimientosBackup,
      'categoriasGastos': categoriasGastos,
      'categoriasIngresos': categoriasIngresos,
      'correcciones': correcciones,
      'balanceInicial': balanceInicial,
      'historicos': historicos,
    };

    await archivo.writeAsString(jsonEncode(datos));

    await SharePlus.instance.share(
      ShareParams(
        text: 'Copia de seguridad de Mis Finanzas',
        files: [XFile(archivo.path)],
      ),
    );
  }

  Future<void> importarDatos() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (resultado == null || resultado.files.isEmpty) return;
    final archivo = resultado.files.first;
    if (archivo.path == null) return;

    final ruta = archivo.path!;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text(
          'Esto sustituirá los movimientos, categorías, correcciones y balance actual por los datos de la copia. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final contenido = await File(ruta).readAsString();
      final datos = Map<String, dynamic>.from(jsonDecode(contenido));

      final nuevosMovimientos = <Map<String, dynamic>>[];
      final directorio = await getApplicationDocumentsDirectory();

      for (final item in (datos['movimientos'] ?? [])) {
        final mapa = Map<String, dynamic>.from(item);
        final base64Foto = mapa['fotoBase64']?.toString();

        if (base64Foto != null && base64Foto.isNotEmpty) {
          try {
            final extension = mapa['fotoExtension']?.toString() ?? '.jpg';
            final archivoFoto = File(
              '${directorio.path}/movimiento_restaurado_${DateTime.now().microsecondsSinceEpoch}$extension',
            );
            await archivoFoto.writeAsBytes(base64Decode(base64Foto));
            mapa['fotoPath'] = archivoFoto.path;
          } catch (_) {
            mapa['fotoPath'] = null;
          }
        }

        mapa.remove('fotoBase64');
        mapa.remove('fotoExtension');
        mapa['moneda'] = mapa['moneda']?.toString() ?? 'EUR';
        mapa['cantidadOriginal'] = ((mapa['cantidadOriginal'] as num?) ?? (mapa['cantidad'] as num?) ?? 0).toDouble();
        mapa['tipoCambio'] = ((mapa['tipoCambio'] as num?) ?? 1).toDouble();
        nuevosMovimientos.add(mapa);
      }

      final nuevasCategoriasGastos = List<Map<String, dynamic>>.from(
        (datos['categoriasGastos'] ?? []).map((item) {
          final mapa = Map<String, dynamic>.from(item);
          mapa['subcategorias'] = List<String>.from(mapa['subcategorias'] ?? []);
          mapa['archivada'] = mapa['archivada'] == true;
          mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
          return mapa;
        }),
      );

      final nuevasCategoriasIngresos = List<Map<String, dynamic>>.from(
        (datos['categoriasIngresos'] ?? []).map((item) {
          final mapa = Map<String, dynamic>.from(item);
          mapa['subcategorias'] = List<String>.from(mapa['subcategorias'] ?? []);
          mapa['archivada'] = mapa['archivada'] == true;
          mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
          return mapa;
        }),
      );

      final nuevasCorrecciones = List<Map<String, dynamic>>.from(
        (datos['correcciones'] ?? []).map(
              (item) => Map<String, dynamic>.from(item),
        ),
      );

      final nuevosHistoricos = List<Map<String, dynamic>>.from(
        (datos['historicos'] ?? []).map((item) => Map<String, dynamic>.from(item)),
      );

      final nuevoBalance = ((datos['balanceInicial'] as num?) ?? 0).toDouble();

      // Las correcciones de copias antiguas también se restauran como movimientos de tipo Ajuste.
      for (final correccion in nuevasCorrecciones) {
        final fecha = correccion['fecha']?.toString() ?? '';
        final cantidad = ((correccion['cantidad'] as num?) ?? 0).toDouble();
        if (fecha.isEmpty || cantidad.abs() < 0.005) continue;
        nuevosMovimientos.add({
          'id': 'ajuste_restaurado_${DateTime.now().microsecondsSinceEpoch}_${nuevosMovimientos.length}',
          'cantidad': cantidad,
          'tipo': 'Ajuste',
          'categoria': 'Ajuste de saldo',
          'subcategoria': null,
          'emoji': '🔧',
          'fecha': fecha,
          'nota': 'Ajuste de saldo',
          'fotoPath': null,
          'recurrente': false,
          'intervaloMeses': 1,
          'recurrenceId': null,
        });
      }

      setState(() {
        movimientos = nuevosMovimientos;
        categoriasGastos = nuevasCategoriasGastos;
        categoriasIngresos = nuevasCategoriasIngresos;
        correcciones = [];
        historicos = nuevosHistoricos;
        balanceInicial = nuevoBalance;
      });

      await guardarDatos();
      await generarRecurrentesPendientes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copia restaurada correctamente')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido restaurar la copia')),
        );
      }
    }
  }

  // ==========================================================
  // ACTUALIZAR TIPOS DE CAMBIO PENDIENTES
  // ==========================================================

  Future<void> actualizarCambiosPendientes() async {
    final pendientes = movimientos.where((m) =>
    m['tipo'] != 'Ajuste' &&
        m['moneda'] != null &&
        m['moneda'] != 'EUR' &&
        m['tipoCambioPendiente'] == true).toList();

    if (pendientes.isEmpty) return;

    bool cambios = false;
    for (final movimiento in pendientes) {
      final moneda = movimiento['moneda']?.toString() ?? 'EUR';
      final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');
      if (fecha.year == 1900) continue;

      final cambio = await ServicioDivisas.obtenerCambioAEuro(moneda, fecha);
      if (cambio > 0) {
        final original = ((movimiento['cantidadOriginal'] as num?) ?? 0).toDouble();
        movimiento['tipoCambio'] = cambio;
        movimiento['cantidad'] = original / cambio;
        movimiento['tipoCambioPendiente'] = false;
        cambios = true;
      }
    }

    if (cambios) {
      await guardarDatos();
      if (mounted) setState(() {});
    }
  }

  // ==========================================================
  // RECURRENTES MENSUALES
  // ==========================================================

  Future<void> generarRecurrentesPendientes() async {
    bool huboCambios = false;

    final recurrentes = movimientos.where(
          (m) => m['recurrente'] == true && m['recurrenceId'] == null,
    ).toList();

    final ahora = DateTime.now();
    final limite = DateTime(ahora.year, ahora.month + 24, ahora.day);

    for (final recurrente in recurrentes) {
      final fechaOriginal = convertirFecha(
        recurrente['fecha']?.toString() ?? '',
      );

      if (fechaOriginal.year == 1900) continue;

      if (recurrente['id'] == null) {
        recurrente['id'] = DateTime.now().microsecondsSinceEpoch.toString();
        huboCambios = true;
      }

      final intervalo =
      (((recurrente['plantillaIntervaloMeses'] as num?)?.toInt() ?? (recurrente['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120)).toInt();
      recurrente['intervaloMeses'] = intervalo;

      DateTime fecha = sumarMeses(fechaOriginal, intervalo);

      while (!fecha.isAfter(limite)) {
        final omitidas = List<String>.from(
          recurrente['recurrenciasOmitidas'] ?? const [],
        );

        final yaExiste = movimientos.any((m) {
          return m['recurrenceId'] == recurrente['id'] &&
              m['fecha'] == fechaTexto(fecha);
        });

        if (!yaExiste && !omitidas.contains(fechaTexto(fecha))) {
          movimientos.add({
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'cantidad': recurrente['plantillaCantidad'] ?? recurrente['cantidad'],
            'cantidadOriginal': recurrente['plantillaCantidadOriginal'] ?? recurrente['cantidadOriginal'] ?? recurrente['cantidad'],
            'moneda': recurrente['plantillaMoneda'] ?? recurrente['moneda'] ?? 'EUR',
            'tipoCambio': recurrente['plantillaTipoCambio'] ?? recurrente['tipoCambio'] ?? 1,
            'tipoCambioPendiente': recurrente['plantillaTipoCambioPendiente'] ?? (recurrente['tipoCambioPendiente'] == true),
            'tipo': recurrente['tipo'],
            'categoria': recurrente['plantillaCategoria'] ?? recurrente['categoria'],
            'subcategoria': recurrente['plantillaSubcategoria'] ?? recurrente['subcategoria'],
            'emoji': recurrente['plantillaEmoji'] ?? recurrente['emoji'],
            'fecha': fechaTexto(fecha),
            'fechaCreacion':
            recurrente['fechaCreacion'] ??
                recurrente['plantillaFechaCreacion'] ??
                fechaTexto(fechaOriginal),
            'hora': recurrente['hora'] ?? '',
            'nota': recurrente['plantillaNota'] ?? recurrente['nota'] ?? '',
            'fotoPath': recurrente['plantillaFotoPath'] ?? recurrente['fotoPath'],
            'recurrente': true,
            'intervaloMeses': intervalo,
            'recurrenceId': recurrente['id'],
          });
          huboCambios = true;
        }

        fecha = sumarMeses(fecha, intervalo);
      }
    }

    if (huboCambios) {
      await guardarDatos();
      if (mounted) setState(() {});
    }
  }

  // ==========================================================
  // MOVIMIENTOS
  // ==========================================================

  Future<void> anadirMovimiento(
      Map<String, dynamic> movimiento,
      ) async {
    setState(() {
      movimientos.add(movimiento);
    });

    await guardarDatos();

    if (movimiento['recurrente'] == true) {
      await generarRecurrentesPendientes();
    }

    final fecha =
    convertirFecha(
      movimiento['fecha'],
    );

    if (fecha.year != 1900) {
      setState(() {
        mesSeleccionado = fecha;
      });
    }
  }

  Future<void> mostrarDetalleMovimiento(
      Map<String, dynamic> movimiento,
      ) async {
    if (movimiento['tipo'] == 'Ajuste') return;

    final tipo = movimiento['tipo']?.toString() ?? '';
    final categoria = movimiento['categoria']?.toString() ?? 'Movimiento';
    final subcategoria = movimiento['subcategoria']?.toString();
    final fechaTextoMov = movimiento['fecha']?.toString() ?? '';
    final fechaMov = convertirFecha(fechaTextoMov);
    final cantidad = ((movimiento['cantidad'] as num?) ?? 0).toDouble().abs();
    final cantidadOriginal = ((movimiento['cantidadOriginal'] as num?) ?? (movimiento['cantidad'] as num?) ?? 0).toDouble().abs();
    String hora = movimiento['hora']?.toString() ?? '';
    if (hora.isEmpty && movimiento['recurrenceId'] != null) {
      final recurrenceId = movimiento['recurrenceId']?.toString();
      final raiz = movimientos.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['id']?.toString() == recurrenceId,
        orElse: () => null,
      );
      hora = raiz?['hora']?.toString() ?? '';
    }
    if (hora.isEmpty) hora = 'No registrada';

    double mesCategoria = 0;
    double anoCategoria = 0;
    double mesSub = 0;
    double anoSub = 0;

    for (final m in movimientos) {
      if (m['tipo'] != tipo || m['categoria'] != categoria) continue;
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      final c = ((m['cantidad'] as num?) ?? 0).toDouble().abs();

      if (f.year == fechaMov.year && f.month == fechaMov.month) {
        mesCategoria += c;
        if (subcategoria != null &&
            m['subcategoria']?.toString() == subcategoria) {
          mesSub += c;
        }
      }
      // En el total anual solo contamos lo que ya ha ocurrido
      // hasta la fecha del movimiento que estamos viendo.
      // Así, si una serie empieza en octubre y estamos viendo noviembre,
      // el año muestra octubre + noviembre, sin sumar diciembre ni meses futuros.
      if (f.year == fechaMov.year && !f.isAfter(fechaMov)) {
        anoCategoria += c;
        if (subcategoria != null &&
            m['subcategoria']?.toString() == subcategoria) {
          anoSub += c;
        }
      }
    }

    double proyeccionAnoRecurrente = 0;

    if (movimiento['recurrente'] == true) {
      final recurrenceId =
          movimiento['recurrenceId']?.toString() ??
              movimiento['id']?.toString();

      final serie = movimientos.where((m) {
        final mismo =
            m['id']?.toString() == recurrenceId ||
                m['recurrenceId']?.toString() == recurrenceId;
        if (!mismo || m['tipo'] != tipo || m['categoria'] != categoria) {
          return false;
        }

        final f = convertirFecha(m['fecha']?.toString() ?? '');
        return f.year == fechaMov.year;
      }).toList();

      // The projection is based on the movements actually scheduled in this
      // calendar year, not on an artificial January start.
      // Example: a €1,000 monthly series starting in September has
      // €4,000 projected for the year (Sep-Dec), not €12,000.
      for (final m in serie) {
        final f = convertirFecha(m['fecha']?.toString() ?? '');
        final importe =
        ((m['cantidad'] as num?) ?? 0).toDouble().abs();

        if (f.year == fechaMov.year) {
          proyeccionAnoRecurrente += importe;
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF1F1F1),
                    child: Text(
                      movimiento['emoji']?.toString() ??
                          (tipo == 'Gasto' ? '💸' : '💰'),
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoria,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (subcategoria != null)
                Padding(
                  padding: const EdgeInsets.only(left: 60, top: 2),
                  child: Text(subcategoria),
                ),
              const SizedBox(height: 12),
              if ((movimiento['moneda']?.toString() ?? 'EUR') == 'EUR')
                Text('Importe: ${formatearEuros(cantidad)} EUR')
              else ...[
                Text(
                  'Original: ${formatearNumero(cantidadOriginal)} ${movimiento['moneda'] ?? ''}',
                ),
                Text(
                  'En euros: ${formatearEuros(cantidad)} EUR',
                ),
              ],
              Text('Fecha del movimiento: $fechaTextoMov'),
              Text(
                'Fecha en que se introdujo: '
                    '${movimiento['fechaCreacion']?.toString() ?? fechaTextoMov}',
              ),
              Text('Hora: $hora'),
              const Divider(),
              const Text(
                'Total de la categoría',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Mes: ${formatearEuros(mesCategoria)}'),
              Text(
                'Año ${fechaMov.year}: ${formatearEuros(anoCategoria)}',
              ),
              if (movimiento['recurrente'] == true &&
                  fechaMov.isAfter(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  ) &&
                  fechaMov.year == DateTime.now().year) ...[
                const SizedBox(height: 10),
                const Text(
                  'Recurrente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Proyectado año completo: '
                      '${formatearEuros(proyeccionAnoRecurrente)}',
                ),
              ],
              if (subcategoria != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Total de la subcategoría',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Mes: ${formatearEuros(mesSub)}'),
                Text(
                  'Año ${fechaMov.year}: ${formatearEuros(anoSub)}',
                ),

              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (mounted) {
                        editarMovimiento(movimiento);
                      }
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> preguntarAlcanceEdicionRecurrente(Map<String, dynamic> original) async {
    if (original['recurrente'] != true) return 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Movimiento periódico'),
          content: const Text(
            '¿Quieres cambiar solo esta entrada o también las siguientes repeticiones?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 0),
              child: const Text('Solo esta entrada'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 1),
              child: const Text('Esta y las siguientes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> editarMovimiento(Map<String, dynamic> original) async {
    final esGasto = original['tipo'] == 'Gasto';
    final cantidadOriginal = ((original['cantidadOriginal'] as num?) ??
        (original['cantidad'] as num?) ??
        0)
        .toDouble();

    final cantidadController = TextEditingController(
      text: cantidadOriginal.toStringAsFixed(2),
    );

    DateTime fecha = convertirFecha(
      original['fecha']?.toString() ?? '',
    );
    if (fecha.year == 1900) fecha = DateTime.now();

    String moneda = original['moneda']?.toString() ?? 'EUR';
    bool recurrenteEditado = original['recurrente'] == true;
    int intervaloEditado =
    ((original['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120);
    final intervaloEditController = TextEditingController(
      text: intervaloEditado.toString(),
    );

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esGasto ? 'Editar gasto' : 'Editar ingreso',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundColor: const Color(0xFFF1F1F1),
                              child: Text(
                                original['emoji'] ??
                                    (esGasto ? '💸' : '💰'),
                                style: const TextStyle(fontSize: 21),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${original['categoria'] ?? 'Movimiento'}'
                                    '${original['subcategoria'] != null ? ' · ${original['subcategoria']}' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Importe y moneda se editan juntos.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cantidadController,
                            autofocus: true,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Importe',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 105,
                          child: DropdownButtonFormField<String>(
                            value: monedasDisponibles.any(
                                  (m) => m['codigo'] == moneda,
                            )
                                ? moneda
                                : 'EUR',
                            decoration: const InputDecoration(
                              labelText: 'Moneda',
                              border: OutlineInputBorder(),
                            ),
                            items: monedasDisponibles.map((m) {
                              final codigo = m['codigo']!;
                              return DropdownMenuItem<String>(
                                value: codigo,
                                child: Text(codigo),
                              );
                            }).toList(),
                            onChanged: (valor) {
                              if (valor != null) {
                                setSheetState(() => moneda = valor);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: const Text('Fecha'),
                      subtitle: Text(fechaTexto(fecha)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final nuevaFecha = await showDatePicker(
                          context: sheetContext,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (nuevaFecha != null) {
                          setSheetState(() => fecha = nuevaFecha);
                        }
                      },
                    ),

                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Recurrente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        recurrenteEditado
                            ? 'Cada $intervaloEditado mes${intervaloEditado == 1 ? '' : 'es'}'
                            : 'No se repetirá',
                      ),
                      value: recurrenteEditado,
                      onChanged: (valor) {
                        setSheetState(() => recurrenteEditado = valor);
                      },
                    ),
                    if (recurrenteEditado)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Text('Cada'),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: TextField(
                                controller: intervaloEditController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (valor) {
                                  final numero = int.tryParse(valor);
                                  if (numero != null && numero >= 1) {
                                    intervaloEditado =
                                        numero.clamp(1, 120).toInt();
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('meses'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final valor = double.tryParse(
                            cantidadController.text
                                .trim()
                                .replaceAll(',', '.'),
                          );
                          if (valor == null || valor < 0) return;

                          Navigator.pop(
                            sheetContext,
                            {
                              'cantidad': valor,
                              'moneda': moneda,
                              'fecha': fecha,
                              'recurrente': recurrenteEditado,
                              'intervaloMeses': intervaloEditado,
                            },
                          );
                        },
                        child: const Text('Guardar cambios'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const Divider(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext, {
                            'eliminar': true,
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Borrar movimiento',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    intervaloEditController.dispose();

    if (resultado == null || !mounted) return;

    if (resultado['eliminar'] == true) {
      await eliminarMovimiento(original);
      return;
    }

    int? alcance = 0;
    final nuevaRecurrente = resultado['recurrente'] == true;
    final nuevoIntervalo = ((resultado['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120);
    if (original['recurrente'] == true && nuevaRecurrente) {
      alcance = await preguntarAlcanceEdicionRecurrente(original);
      if (alcance == null || !mounted) return;
    }

    final valor = (resultado['cantidad'] as num).toDouble();
    final nuevaMoneda = resultado['moneda']?.toString() ?? 'EUR';
    final nuevaFecha = resultado['fecha'] as DateTime;
    final idOriginal = original['id']?.toString();
    final indice = movimientos.indexWhere(
          (m) => m['id']?.toString() == idOriginal,
    );
    if (indice == -1) return;

    double cambio = 1.0;
    bool pendiente = false;

    if (nuevaMoneda != 'EUR') {
      cambio = await ServicioDivisas.obtenerCambioAEuro(
        nuevaMoneda,
        nuevaFecha,
      );
      pendiente = cambio <= 0;
    }

    final actualizado = Map<String, dynamic>.from(
      movimientos[indice],
    );

    actualizado['cantidadOriginal'] = valor;
    actualizado['moneda'] = nuevaMoneda;
    actualizado['tipoCambio'] = cambio;
    actualizado['tipoCambioPendiente'] = pendiente;
    actualizado['cantidad'] = pendiente
        ? 0.0
        : (nuevaMoneda == 'EUR' ? valor : valor / cambio);
    actualizado['fecha'] = fechaTexto(nuevaFecha);
    actualizado['fechaCreacion'] = fechaTexto(DateTime.now());
    actualizado['recurrente'] = nuevaRecurrente;
    actualizado['intervaloMeses'] = nuevoIntervalo;

    final prefs = await SharedPreferences.getInstance();
    final uso = prefs.getStringList('monedas_uso') ?? [];
    if (nuevaMoneda != 'EUR') {
      uso.remove(nuevaMoneda);
      uso.add(nuevaMoneda);
    }
    await prefs.setStringList('monedas_uso', uso);

    if (!mounted) return;

    if (original['recurrente'] == true && !nuevaRecurrente) {
      final recurrenceId =
          original['recurrenceId']?.toString() ?? idOriginal;

      actualizado['recurrente'] = false;
      actualizado['recurrenceId'] = null;
      actualizado['intervaloMeses'] = 1;
      actualizado['plantillaCantidad'] = null;
      actualizado['plantillaCantidadOriginal'] = null;
      actualizado['plantillaMoneda'] = null;
      actualizado['plantillaTipoCambio'] = null;
      actualizado['plantillaTipoCambioPendiente'] = null;
      actualizado['plantillaCategoria'] = null;
      actualizado['plantillaSubcategoria'] = null;
      actualizado['plantillaEmoji'] = null;
      actualizado['plantillaNota'] = null;
      actualizado['plantillaFotoPath'] = null;
      actualizado['plantillaIntervaloMeses'] = null;
      actualizado['recurrenciasOmitidas'] = <String>[];

      movimientos[indice] = actualizado;

      // Si se desactiva desde una repetición futura, también hay que
      // detener la plantilla original; de lo contrario la app la volvería
      // a generar al abrirse.
      final raizIndice = movimientos.indexWhere(
            (m) => m['id']?.toString() == recurrenceId,
      );
      if (raizIndice != -1 && raizIndice != indice) {
        final raiz = Map<String, dynamic>.from(movimientos[raizIndice]);
        raiz['recurrente'] = false;
        raiz['recurrenceId'] = null;
        raiz['intervaloMeses'] = 1;
        raiz['recurrenciasOmitidas'] = <String>[];
        raiz['plantillaCantidad'] = null;
        raiz['plantillaCantidadOriginal'] = null;
        raiz['plantillaMoneda'] = null;
        raiz['plantillaTipoCambio'] = null;
        raiz['plantillaTipoCambioPendiente'] = null;
        raiz['plantillaCategoria'] = null;
        raiz['plantillaSubcategoria'] = null;
        raiz['plantillaEmoji'] = null;
        raiz['plantillaNota'] = null;
        raiz['plantillaFotoPath'] = null;
        raiz['plantillaIntervaloMeses'] = null;
        movimientos[raizIndice] = raiz;
      }

      movimientos.removeWhere((m) {
        final mismo =
            m['id']?.toString() == recurrenceId ||
                m['recurrenceId']?.toString() == recurrenceId;
        if (!mismo) return false;

        final f = convertirFecha(m['fecha']?.toString() ?? '');
        final esOtraEntrada =
            m['id']?.toString() != idOriginal;
        return esOtraEntrada && f.isAfter(nuevaFecha);
      });
    } else if (alcance == 1 && actualizado['recurrente'] == true) {
      final recurrenceId = original['recurrenceId']?.toString() ?? idOriginal;
      final hoy = DateTime.now();
      final inicioFuturo = DateTime(hoy.year, hoy.month, 1);
      final fechaSeleccionada = convertirFecha(original['fecha']?.toString() ?? '');
      final fechaMinima = fechaSeleccionada.isBefore(inicioFuturo)
          ? inicioFuturo
          : fechaSeleccionada;

      // La plantilla guarda el nuevo valor sin tocar las entradas pasadas.
      final fuente = movimientos.firstWhere(
            (m) => m['id']?.toString() == recurrenceId,
        orElse: () => actualizado,
      );
      fuente['plantillaCantidad'] = actualizado['cantidad'];
      fuente['plantillaCantidadOriginal'] = actualizado['cantidadOriginal'];
      fuente['plantillaMoneda'] = actualizado['moneda'];
      fuente['plantillaTipoCambio'] = actualizado['tipoCambio'];
      fuente['plantillaTipoCambioPendiente'] = actualizado['tipoCambioPendiente'];
      fuente['plantillaCategoria'] = actualizado['categoria'];
      fuente['plantillaSubcategoria'] = actualizado['subcategoria'];
      fuente['plantillaEmoji'] = actualizado['emoji'];
      fuente['plantillaNota'] = actualizado['nota'] ?? '';
      fuente['plantillaFotoPath'] = actualizado['fotoPath'];
      fuente['plantillaIntervaloMeses'] = actualizado['intervaloMeses'] ?? 1;

      // Si estamos editando la plantilla (la primera entrada de la serie),
      // actualizamos también esa entrada si está dentro del periodo futuro.
      if (original['recurrenceId'] == null) {
        final fechaFuente = convertirFecha(original['fecha']?.toString() ?? '');
        if (!fechaFuente.isBefore(fechaMinima)) {
          movimientos[indice] = actualizado;
        }
      }

      // Las repeticiones generadas se actualizan desde el mes elegido en adelante.
      for (var i = 0; i < movimientos.length; i++) {
        final m = movimientos[i];
        if (m['recurrenceId']?.toString() == recurrenceId) {
          final fechaM = convertirFecha(m['fecha']?.toString() ?? '');
          if (!fechaM.isBefore(fechaMinima)) {
            final copia = Map<String, dynamic>.from(actualizado);
            copia['id'] = m['id'];
            copia['recurrenceId'] = m['recurrenceId'];
            copia['fecha'] = m['fecha'];
            copia['fechaCreacion'] = actualizado['fechaCreacion'];
            copia['hora'] = m['hora'];
            // Las entradas generadas no son la plantilla.
            copia['plantillaCantidad'] = null;
            copia['plantillaCantidadOriginal'] = null;
            copia['plantillaMoneda'] = null;
            copia['plantillaTipoCambio'] = null;
            copia['plantillaTipoCambioPendiente'] = null;
            copia['plantillaCategoria'] = null;
            copia['plantillaSubcategoria'] = null;
            copia['plantillaEmoji'] = null;
            copia['plantillaNota'] = null;
            copia['plantillaFotoPath'] = null;
            copia['plantillaIntervaloMeses'] = null;
            movimientos[i] = copia;
          }
        }
      }
    } else {
      movimientos[indice] = actualizado;
    }

    setState(() {
      mesSeleccionado = nuevaFecha;
    });

    await guardarDatos();
    await generarRecurrentesPendientes();
  }

  Future<void> editarAjuste(Map<String, dynamic> original) async {
    final cantidadController = TextEditingController(
      text: (((original['cantidad'] as num?) ?? 0).toDouble())
          .toStringAsFixed(2),
    );

    DateTime fecha = convertirFecha(
      original['fecha']?.toString() ?? '',
    );
    if (fecha.year == 1900) fecha = DateTime.now();

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editar ajuste de saldo',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cantidadController,
                      autofocus: true,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Importe del ajuste',
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: const Text('Fecha'),
                      subtitle: Text(fechaTexto(fecha)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final nuevaFecha = await showDatePicker(
                          context: sheetContext,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (nuevaFecha != null) {
                          setSheetState(() => fecha = nuevaFecha);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final valor = double.tryParse(
                            cantidadController.text
                                .trim()
                                .replaceAll(',', '.'),
                          );
                          if (valor == null) return;

                          Navigator.pop(
                            sheetContext,
                            {
                              'cantidad': valor,
                              'fecha': fecha,
                            },
                          );
                        },
                        child: const Text('Guardar cambios'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const Divider(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext, {
                            'eliminar': true,
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Borrar ajuste',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (resultado == null || !mounted) return;

    if (resultado['eliminar'] == true) {
      await eliminarMovimiento(original);
      return;
    }

    final valor = (resultado['cantidad'] as num).toDouble();
    final nuevaFecha = resultado['fecha'] as DateTime;

    final idOriginal = original['id']?.toString();
    final indice = movimientos.indexWhere(
          (m) => m['id']?.toString() == idOriginal,
    );
    if (indice == -1) return;

    final actualizado = Map<String, dynamic>.from(
      movimientos[indice],
    );
    actualizado['cantidad'] = valor;
    actualizado['fecha'] = fechaTexto(nuevaFecha);

    setState(() {
      movimientos[indice] = actualizado;
      mesSeleccionado = nuevaFecha;
    });

    await guardarDatos();
  }

  Future<int?> preguntarAlcanceEliminacionRecurrente(
      Map<String, dynamic> movimiento,
      ) async {
    if (movimiento['recurrente'] != true) return 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar movimiento recurrente'),
        content: const Text(
          '¿Qué quieres borrar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 1),
            child: const Text('Solo esta entrada'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 2),
            child: const Text('Esta y las siguientes'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, 3),
            child: const Text('Toda la serie'),
          ),
        ],
      ),
    );
  }

  Future<void> eliminarMovimiento(Map<String, dynamic> movimiento) async {
    final alcance = await preguntarAlcanceEliminacionRecurrente(movimiento);
    if (alcance == null || !mounted) return;

    if (movimiento['recurrente'] != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Eliminar movimiento'),
          content: const Text('¿Seguro que quieres eliminar este movimiento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final id = movimiento['id']?.toString();
    final recurrenceId =
        movimiento['recurrenceId']?.toString() ?? id;
    final fecha = convertirFecha(
      movimiento['fecha']?.toString() ?? '',
    );

    // Para una serie, el identificador estable es el ID de la plantilla.
    final rootId = recurrenceId;

    if (movimiento['recurrente'] == true && alcance == 3) {
      final serie = movimientos.where((m) {
        return m['id']?.toString() == rootId ||
            m['recurrenceId']?.toString() == rootId;
      }).toList();

      final pasadas = serie
          .where((m) {
        final f = convertirFecha(m['fecha']?.toString() ?? '');
        return f.isBefore(fecha);
      })
          .toList()
        ..sort(
              (a, b) => convertirFecha(
            b['fecha']?.toString() ?? '',
          ).compareTo(
            convertirFecha(
              a['fecha']?.toString() ?? '',
            ),
          ),
        );

      final ejemplos = pasadas
          .take(3)
          .map(
            (m) =>
        '${m['fecha']} · ${m['categoria']} · ${formatearEuros(((m['cantidad'] as num?) ?? 0).toDouble().abs())}',
      )
          .join('\n');

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Borrar toda la serie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se borrarán esta entrada, todas las futuras y también el histórico de esta serie.',
              ),
              if (pasadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'También se eliminarán entradas anteriores, por ejemplo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(ejemplos),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar toda la serie'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;
    }

    setState(() {
      if (movimiento['recurrente'] != true) {
        movimientos.removeWhere(
              (m) => m['id']?.toString() == id,
        );
      } else if (alcance == 1) {
        // Solo esta entrada. La serie sigue activa, pero esta fecha queda
        // registrada como omitida para que no vuelva a generarse.
        final raiz = movimientos.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['id']?.toString() == rootId,
          orElse: () => null,
        );

        if (raiz != null) {
          final omitidas = List<String>.from(
            raiz['recurrenciasOmitidas'] ?? const [],
          );
          final fechaOmitida = fechaTexto(fecha);
          if (!omitidas.contains(fechaOmitida)) {
            omitidas.add(fechaOmitida);
          }
          raiz['recurrenciasOmitidas'] = omitidas;
        }

        movimientos.removeWhere(
              (m) => m['id']?.toString() == id,
        );
      } else if (alcance == 2) {
        // Esta y todas las siguientes. La serie queda detenida para que
        // no se vuelvan a crear al abrir la aplicación.
        final raiz = movimientos.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['id']?.toString() == rootId,
          orElse: () => null,
        );

        if (raiz != null) {
          raiz['recurrente'] = false;
          raiz['intervaloMeses'] = 1;
          raiz['recurrenceId'] = null;
          raiz['plantillaCantidad'] = null;
          raiz['plantillaCantidadOriginal'] = null;
          raiz['plantillaMoneda'] = null;
          raiz['plantillaTipoCambio'] = null;
          raiz['plantillaTipoCambioPendiente'] = null;
          raiz['plantillaCategoria'] = null;
          raiz['plantillaSubcategoria'] = null;
          raiz['plantillaEmoji'] = null;
          raiz['plantillaNota'] = null;
          raiz['plantillaFotoPath'] = null;
          raiz['plantillaIntervaloMeses'] = null;
        }

        movimientos.removeWhere((m) {
          final mismo =
              m['id']?.toString() == rootId ||
                  m['recurrenceId']?.toString() == rootId;
          if (!mismo) return false;

          final f = convertirFecha(m['fecha']?.toString() ?? '');
          return !f.isBefore(fecha);
        });
      } else if (alcance == 3) {
        // Toda la serie.
        movimientos.removeWhere((m) {
          return m['id']?.toString() == rootId ||
              m['recurrenceId']?.toString() == rootId;
        });
      }
    });

    await guardarDatos();
  }

  // ==========================================================
  // PATRIMONIO / RECUENTOS
  // ==========================================================

  Map<String, dynamic>? get ultimoPatrimonio {
    if (patrimonios.isEmpty) return null;
    final hoy = DateTime.now();
    final limite = DateTime(hoy.year, hoy.month, hoy.day);
    final copia = patrimonios.where((p) {
      final f = convertirFecha(p['fecha']?.toString() ?? '');
      return f.year != 1900 && !f.isAfter(limite);
    }).toList();
    if (copia.isEmpty) return null;
    copia.sort((a, b) {
      final fa = convertirFecha(a['fecha']?.toString() ?? '');
      final fb = convertirFecha(b['fecha']?.toString() ?? '');
      return fb.compareTo(fa);
    });
    return copia.first;
  }

  double totalPatrimonio(Map<String, dynamic> patrimonio) {
    return (patrimonio['cuentas'] as List?)
        ?.fold<double>(
      0,
          (total, cuenta) =>
      total + ((cuenta['cantidad'] as num?) ?? 0).toDouble(),
    ) ??
        0;
  }

  double totalPatrimonioLiquido(Map<String, dynamic> patrimonio) {
    return (patrimonio['cuentas'] as List?)
        ?.where(
          (cuenta) =>
      cuenta['nombre']?.toString().toLowerCase() != 'invertido',
    )
        .fold<double>(
      0,
          (total, cuenta) =>
      total + ((cuenta['cantidad'] as num?) ?? 0).toDouble(),
    ) ??
        0;
  }

  double patrimonioInvertido(Map<String, dynamic> patrimonio) {
    return (patrimonio['cuentas'] as List?)
        ?.where(
          (cuenta) =>
      cuenta['nombre']?.toString().toLowerCase() == 'invertido',
    )
        .fold<double>(
      0,
          (total, cuenta) =>
      total + ((cuenta['cantidad'] as num?) ?? 0).toDouble(),
    ) ??
        0;
  }

  double get saldoPatrimonioActual {
    final ultimo = ultimoPatrimonio;
    if (ultimo == null) return saldoActual;

    final fechaRecuento = convertirFecha(
      ultimo['fecha']?.toString() ?? '',
    );
    final base = totalPatrimonioLiquido(ultimo);

    double posteriores = 0;
    for (final m in movimientos) {
      final fechaMovimiento = convertirFecha(
        m['fecha']?.toString() ?? '',
      );

      if (!fechaMovimiento.isAfter(fechaRecuento) ||
          !movimientoYaOcurrio(m)) {
        continue;
      }

      if (m['tipo'] == 'Ingreso') {
        posteriores += ((m['cantidad'] as num?) ?? 0).toDouble();
      } else if (m['tipo'] == 'Gasto') {
        posteriores -= ((m['cantidad'] as num?) ?? 0).toDouble().abs();
      } else if (m['tipo'] == 'Ajuste') {
        posteriores += ((m['cantidad'] as num?) ?? 0).toDouble();
      }
    }

    return base + posteriores;
  }

  double get invertidoActual {
    final ultimo = ultimoPatrimonio;
    return ultimo == null ? 0 : patrimonioInvertido(ultimo);
  }

  double get patrimonioTotalActual {
    final ultimo = ultimoPatrimonio;
    return ultimo == null ? saldoActual : totalPatrimonio(ultimo);
  }

  Future<void> abrirPatrimonio() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PatrimonioPage(
          patrimonios: patrimonios,
          categorias: categoriasPatrimonio,
          onGuardar: (patrimonio) async {
            setState(() {
              patrimonios.add(patrimonio);
            });
            await guardarDatos();
          },
          onCategoriasChanged: (nuevas) async {
            setState(() {
              categoriasPatrimonio = nuevas;
            });
            await guardarDatos();
          },
        ),
      ),
    );
    if (resultado != null && mounted) setState(() {});
  }

  // ==========================================================
  // SALDO
  // ==========================================================

  bool movimientoYaOcurrio(Map<String, dynamic> movimiento) {
    final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');
    if (fecha.year == 1900) return false;
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    return !fecha.isAfter(hoySinHora);
  }

  double get totalCorrecciones {
    return movimientos
        .where((m) => m['tipo'] == 'Ajuste' && movimientoYaOcurrio(m))
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double get totalIngresos {
    return movimientos
        .where((m) => m['tipo'] == 'Ingreso' && movimientoYaOcurrio(m))
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double get totalGastos {
    return movimientos
        .where((m) => m['tipo'] == 'Gasto' && movimientoYaOcurrio(m))
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double get saldoActual {
    return balanceInicial + totalIngresos - totalGastos + totalCorrecciones;
  }

  // ==========================================================
  // CORRECCIÓN
  // ==========================================================

  Future<void> nuevaCorreccion() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const NuevaCorreccionPage()),
    );
    if (resultado == null) return;

    final dineroReal = (resultado['cantidad'] as num?)?.toDouble() ?? 0;
    final fechaAjuste =
        resultado['fecha'] as DateTime? ?? DateTime.now();
    final diferencia = dineroReal - saldoActual;
    if (diferencia.abs() < 0.005) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar saldo actual'),
        content: Text(
          'Vas a cambiar tu saldo actual a ${formatearEuros(dineroReal)} '
              'con fecha ${fechaTexto(fechaAjuste)}.\n\n'
              'El ajuste será de ${diferencia >= 0 ? '+' : ''}'
              '${formatearEuros(diferencia)}.\n\n'
              '¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      movimientos.add({
        'id': 'ajuste_${DateTime.now().microsecondsSinceEpoch}',
        'cantidad': diferencia,
        'tipo': 'Ajuste',
        'categoria': 'Ajuste de saldo',
        'subcategoria': null,
        'emoji': '🔧',
        'fecha': fechaTexto(fechaAjuste),
        'nota': 'Ajuste de saldo',
        'fotoPath': null,
        'recurrente': false,
        'intervaloMeses': 1,
        'recurrenceId': null,
      });
    });
    await guardarDatos();
  }

  // ==========================================================
  // MOVIMIENTOS DEL MES
  // ==========================================================

  List<Map<String, dynamic>> movimientosDelMes(
      DateTime mes,
      ) {
    final resultado =
    movimientos.where(
          (m) {
        final fecha =
        convertirFecha(
          m['fecha']?.toString() ??
              '',
        );

        return fecha.year ==
            mes.year &&
            fecha.month ==
                mes.month;
      },
    ).toList();

    resultado.sort(compararMovimientosPorFechaHoraDesc);

    return resultado;
  }

  List<Map<String, dynamic>> movimientosDelMesHastaHoy(DateTime mes) {
    return movimientosDelMes(mes).where(movimientoYaOcurrio).toList();
  }

  double ingresosMes(DateTime mes) {
    return movimientosDelMesHastaHoy(mes)
        .where((m) => m['tipo'] == 'Ingreso')
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double gastosMes(DateTime mes) {
    return movimientosDelMesHastaHoy(mes)
        .where((m) => m['tipo'] == 'Gasto')
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double ajustesMes(DateTime mes) {
    return movimientosDelMesHastaHoy(mes)
        .where((m) => m['tipo'] == 'Ajuste')
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
  }

  double balanceMes(DateTime mes) {
    return ingresosMes(mes) - gastosMes(mes) + ajustesMes(mes);
  }

  double ingresosAno(int ano) {
    final hoy = DateTime.now();
    return movimientos
        .where((m) {
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      final mismoAno = fecha.year == ano;
      final hastaHoy = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1)));
      return mismoAno && hastaHoy && m['tipo'] == 'Ingreso';
    })
        .fold(
      0.0,
          (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble(),
    );
  }

  double gastosAno(int ano) {
    final hoy = DateTime.now();
    return movimientos
        .where((m) {
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      final mismoAno = fecha.year == ano;
      final hastaHoy = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1)));
      return mismoAno && hastaHoy && m['tipo'] == 'Gasto';
    })
        .fold(
      0.0,
          (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble(),
    );
  }

  double ajustesAno(int ano) {
    final hoy = DateTime.now();
    return movimientos
        .where((m) {
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      final mismoAno = fecha.year == ano;
      final hastaHoy = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1)));
      return mismoAno && hastaHoy && m['tipo'] == 'Ajuste';
    })
        .fold(
      0.0,
          (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble(),
    );
  }

  double balanceAno(int ano) {
    return ingresosAno(ano) - gastosAno(ano) + ajustesAno(ano);
  }

  // ==========================================================
  // INICIO
  // ==========================================================

  Widget pantallaInicio() {
    final movimientosMes = movimientosDelMes(
      mesSeleccionado,
    );

    final movimientosMesFiltrados = _filtroMovimientosInicio == null
        ? movimientosMes
        : movimientosMes
        .where((m) => m['tipo'] == _filtroMovimientosInicio)
        .toList();

    final ingresos = ingresosMes(
      mesSeleccionado,
    );

    final gastos = gastosMes(
      mesSeleccionado,
    );

    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final inicioMesSeleccionado = DateTime(
      mesSeleccionado.year,
      mesSeleccionado.month,
      1,
    );
    final finMesSeleccionado = DateTime(
      mesSeleccionado.year,
      mesSeleccionado.month + 1,
      1,
    );
    final esMesActual =
        mesSeleccionado.year == hoy.year &&
            mesSeleccionado.month == hoy.month;

    final listaBase = movimientos.where((m) {
      if (_filtroMovimientosInicio != null &&
          m['tipo'] != _filtroMovimientosInicio) {
        return false;
      }

      final tipo = m['tipo'];
      if (tipo != 'Gasto' && tipo != 'Ingreso' && tipo != 'Ajuste') {
        return false;
      }

      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isBefore(inicioMesSeleccionado) &&
          f.isBefore(finMesSeleccionado);
    }).toList();

    final movimientosRecientes = listaBase.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isAfter(inicioHoy);
    }).toList()
      ..sort(compararMovimientosPorFechaHoraDesc);

    final movimientosProximos = listaBase.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      if (!f.isAfter(inicioHoy)) return false;

      // En el mes actual no enseñamos las repeticiones automáticas
      // en "Próximos". Si el usuario cambia a otro mes, sí las puede ver.
      if (esMesActual && m['recurrente'] == true) {
        return false;
      }

      return true;
    }).toList()
      ..sort(compararMovimientosPorFechaHoraAsc);

    final movimientosMostrados =
    (_mostrarProximosMovimientos
        ? movimientosProximos
        : movimientosRecientes)
        .take(12)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'PastApp',
        ),
      ),
      body:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo actual',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: abrirPatrimonio,
                      onDoubleTap: nuevaCorreccion,
                      child: Text(
                        formatearEurosRedondeados(saldoPatrimonioActual),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: saldoPatrimonioActual >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final ajustes = movimientos
                            .where(
                              (m) =>
                          m['tipo'] == 'Ajuste' &&
                              movimientoYaOcurrio(m),
                        )
                            .toList()
                          ..sort(
                                (a, b) => convertirFecha(
                              b['fecha']?.toString() ?? '',
                            ).compareTo(
                              convertirFecha(
                                a['fecha']?.toString() ?? '',
                              ),
                            ),
                          );
                        final ultimoAjuste =
                        ajustes.isEmpty ? null : ajustes.first;

                        return Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            ultimoAjuste == null
                                ? 'Sin ajustes'
                                : 'Último ajuste · ${ultimoAjuste['fecha']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                    if (invertidoActual.abs() >= 0.005) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Invertido',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatearEuros(invertidoActual),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total con inversión ${formatearEuros(patrimonioTotalActual)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // SELECTOR MES
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      mesSeleccionado =
                          DateTime(
                            mesSeleccionado
                                .year,
                            mesSeleccionado
                                .month -
                                1,
                          );
                    });
                  },
                  icon:
                  const Icon(
                    Icons
                        .chevron_left,
                  ),
                ),
                Expanded(
                  child:
                  InkWell(
                    onTap:
                    seleccionarMes,
                    child:
                    Center(
                      child:
                      Text(
                        '${nombreMes(mesSeleccionado)} ${mesSeleccionado.year}',
                        style:
                        const TextStyle(
                          fontSize:
                          23,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      mesSeleccionado =
                          DateTime(
                            mesSeleccionado
                                .year,
                            mesSeleccionado
                                .month +
                                1,
                          );
                    });
                  },
                  icon:
                  const Icon(
                    Icons
                        .chevron_right,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: resumenIcono(
                    Icons.calendar_month,
                    'Balance mes',
                    balanceMes(mesSeleccionado),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: resumenIcono(
                    Icons.calendar_today,
                    'Balance año ${mesSeleccionado.year}',
                    balanceAno(mesSeleccionado.year),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filtroMovimientosInicio =
                        _filtroMovimientosInicio == 'Ingreso'
                            ? null
                            : 'Ingreso';
                      });
                    },
                    child: resumenCard(
                      'Ingresos',
                      ingresos,
                      Colors.green,
                      seleccionado: _filtroMovimientosInicio == 'Ingreso',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filtroMovimientosInicio =
                        _filtroMovimientosInicio == 'Gasto'
                            ? null
                            : 'Gasto';
                      });
                    },
                    child: resumenCard(
                      'Gastos',
                      gastos,
                      Colors.red,
                      seleccionado: _filtroMovimientosInicio == 'Gasto',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const SizedBox(
              height: 20,
            ),

            Row(children:[
              const Expanded(child:Text('Movimientos',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
              ChoiceChip(label:const Text('Últimos'),selected:!_mostrarProximosMovimientos,onSelected:(_)=>setState(()=>_mostrarProximosMovimientos=false)),
              const SizedBox(width:6),
              ChoiceChip(label:const Text('Próximos'),selected:_mostrarProximosMovimientos,onSelected:(_)=>setState(()=>_mostrarProximosMovimientos=true)),
            ]),
            const SizedBox(height:8),
            if(movimientosMostrados.isEmpty) Padding(padding:const EdgeInsets.all(30),child:Center(child:Text(_mostrarProximosMovimientos?'No hay movimientos próximos.':'No hay movimientos anteriores.'))),
            ...movimientosMostrados.map((movimiento){
              final esGasto=movimiento['tipo']=='Gasto'; final esAjuste=movimiento['tipo']=='Ajuste';
              final cantidad=((movimiento['cantidad'] as num?)??0).toDouble(); final pendiente=movimiento['tipoCambioPendiente']==true;
              final cantidadOriginal=((movimiento['cantidadOriginal'] as num?)??cantidad).toDouble(); final monedaMovimiento=movimiento['moneda']?.toString()??'EUR';
              final subtitulo = [
                movimiento['fecha']?.toString() ?? '',
                if (movimiento['subcategoria'] != null)
                  movimiento['subcategoria'].toString(),
                if (movimiento['nota']?.toString().trim().isNotEmpty ?? false)
                  '📝',
                if (movimiento['fotoPath']?.toString().trim().isNotEmpty ?? false)
                  '📷',
                if (pendiente) '⏳ cambio pendiente',
              ].where((e) => e.isNotEmpty).join(' · ');

              final textoImporte = pendiente
                  ? '${esGasto ? '-' : '+'}${cantidadOriginal.toStringAsFixed(2).replaceAll('.', ',')} $monedaMovimiento'
                  : '${esAjuste ? (cantidad >= 0 ? '+' : '') : (esGasto ? '-' : '+')}${formatearEuros(cantidad.abs())}';

              return Card(
                child: GestureDetector(
                  onTap: () => mostrarDetalleMovimiento(movimiento),
                  onDoubleTap: () => mostrarOpcionesMovimiento(movimiento),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F1F1),
                      foregroundColor: Colors.black87,
                      child: Text(
                        movimiento['emoji'] ??
                            (esAjuste ? '🔧' : (esGasto ? '💸' : '💰')),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    title: Text(
                      movimiento['categoria']?.toString() ?? movimiento['tipo'].toString(),
                    ),
                    subtitle: Text(subtitulo),
                    trailing: Text(
                      textoImporte,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: esAjuste
                            ? Colors.orange
                            : (esGasto ? Colors.red : Colors.green),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),

    );
  }

  Future<void> mostrarDetalleBalance(String tipo) async {
    final esMes = tipo == 'mes';
    final inicio = esMes
        ? DateTime(mesSeleccionado.year, mesSeleccionado.month, 1)
        : DateTime(mesSeleccionado.year, 1, 1);
    final fin = esMes
        ? DateTime(mesSeleccionado.year, mesSeleccionado.month + 1, 1)
        : DateTime(mesSeleccionado.year + 1, 1, 1);

    final ahora = DateTime.now();
    final hoyFin =
    DateTime(ahora.year, ahora.month, ahora.day).add(const Duration(days: 1));
    final limiteActual = fin.isAfter(hoyFin) ? hoyFin : fin;

    final actuales = movimientos.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isBefore(inicio) && f.isBefore(limiteActual);
    }).toList();

    final previstos = movimientos.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isBefore(inicio) && f.isBefore(fin);
    }).toList();

    double total(List<Map<String, dynamic>> lista, String tipoMovimiento) {
      return lista
          .where((m) => m['tipo'] == tipoMovimiento)
          .fold<double>(
        0.0,
            (s, m) => s + ((m['cantidad'] as num?) ?? 0).toDouble().abs(),
      );
    }

    double ajustes(List<Map<String, dynamic>> lista) {
      return lista
          .where((m) => m['tipo'] == 'Ajuste')
          .fold<double>(
        0.0,
            (s, m) => s + ((m['cantidad'] as num?) ?? 0).toDouble(),
      );
    }

    Map<String, double> agrupar(
        List<Map<String, dynamic>> lista,
        String tipoMovimiento,
        ) {
      final resultado = <String, double>{};

      for (final m in lista) {
        if (m['tipo'] != tipoMovimiento) continue;

        final categoria = m['categoria']?.toString() ?? 'Otros';
        final cantidad = ((m['cantidad'] as num?) ?? 0).toDouble().abs();
        resultado[categoria] = (resultado[categoria] ?? 0) + cantidad;
      }

      return resultado;
    }

    final ingresosActuales = total(actuales, 'Ingreso');
    final gastosActuales = total(actuales, 'Gasto');
    final ajustesActuales = ajustes(actuales);

    final ingresosPrevistos = total(previstos, 'Ingreso');
    final gastosPrevistos = total(previstos, 'Gasto');
    final ajustesPrevistos = ajustes(previstos);

    final balanceActual =
        ingresosActuales - gastosActuales + ajustesActuales;
    final balancePrevisto =
        ingresosPrevistos - gastosPrevistos + ajustesPrevistos;

    final hayFuturo = previstos.length != actuales.length;
    final titulo = esMes
        ? '${nombreMes(mesSeleccionado)} ${mesSeleccionado.year}'
        : 'Año ${mesSeleccionado.year}';

    List<MapEntry<String, double>> ordenar(Map<String, double> datos) {
      final lista = datos.entries.toList();
      lista.sort((a, b) => b.value.compareTo(a.value));
      return lista;
    }

    Widget columna(
        String tituloColumna,
        IconData icono,
        Color color,
        Map<String, double> datos,
        double totalColumna,
        ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(.07),
            border: Border.all(color: color.withOpacity(.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 19),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tituloColumna,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatearEuros(totalColumna),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 18),
              if (datos.isEmpty)
                const Text(
                  'Sin movimientos',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...ordenar(datos).map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        const SizedBox(width: 5),
                        Text(
                          formatearEuros(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget asiento(bool previsto) {
      final lista = previsto ? previstos : actuales;
      final ingresos = previsto ? ingresosPrevistos : ingresosActuales;
      final gastos = previsto ? gastosPrevistos : gastosActuales;
      final ajustesTotal = previsto ? ajustesPrevistos : ajustesActuales;
      final balance = previsto ? balancePrevisto : balanceActual;

      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              columna(
                'INGRESOS',
                Icons.arrow_upward,
                Colors.green,
                agrupar(lista, 'Ingreso'),
                ingresos,
              ),
              const SizedBox(width: 10),
              columna(
                'GASTOS',
                Icons.arrow_downward,
                Colors.red,
                agrupar(lista, 'Gasto'),
                gastos,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formatearEuros(balance),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (ajustesTotal.abs() >= .005)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Ajustes: ${formatearEuros(ajustesTotal)}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Asiento · $titulo',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresos a la izquierda · Gastos a la derecha',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'HASTA HOY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 8),
                asiento(false),
                if (hayFuturo) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 14),
                  const Text(
                    'PREVISTO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Incluye también los movimientos futuros programados.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  asiento(true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget resumenCard(
      String titulo,
      double cantidad,
      Color color, {
        bool seleccionado = false,
      }) {
    return Card(
      elevation: seleccionado ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: seleccionado
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              formatearEurosRedondeados(cantidad),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget resumenIcono(IconData icono, String titulo, double valor) {
    final positivo = valor >= 0;
    return GestureDetector(
      onTap: () => mostrarDetalleBalance(
        titulo == 'Balance mes' ? 'mes' : 'anio',
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icono, size: 24),
              const SizedBox(height: 6),
              Text(titulo, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                formatearEurosRedondeados(valor),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: positivo ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> abrirNuevoMovimiento({String? tipoInicial}) async {
    final resultado =
    await Navigator.push<
        Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NuevoMovimiento(
              tipoInicial: tipoInicial,
              categoriasGastos:
              categoriasGastos,
              categoriasIngresos:
              categoriasIngresos,
            ),
      ),
    );

    if (resultado != null) {
      await anadirMovimiento(
        resultado,
      );
    }
  }

  Future<void>
  mostrarOpcionesMovimiento(
      Map<String, dynamic> movimiento,
      ) async {
    // Al tocar un movimiento se abre directamente su pantalla de edición.
    // No mostramos una pantalla intermedia de "Editar / Eliminar".
    if (movimiento['tipo'] == 'Ajuste') {
      await editarAjuste(movimiento);
    } else {
      await editarMovimiento(movimiento);
    }
  }

  Future<void> seleccionarMes() async {
    final resultado =
    await showDialog<DateTime>(
      context: context,
      builder: (_) =>
          SelectorMes(
            inicial:
            mesSeleccionado,
          ),
    );

    if (resultado != null) {
      setState(() {
        mesSeleccionado =
            resultado;
      });
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  Widget _contenidoPaginaWeb() {
    switch (paginaActual) {
      case 0:
        return pantallaInicio();
      case 1:
        return Calendario(
          movimientos: movimientos,
          mesInicial: mesSeleccionado,
          onMovimientoTap: mostrarDetalleMovimiento,
          onMovimientoLongPress: mostrarOpcionesMovimiento,
        );
      case 2:
        return Estadisticas(
          movimientos: movimientos,
          categoriasGastos: categoriasGastos,
          categoriasIngresos: categoriasIngresos,
          historicos: historicos,
          patrimonios: patrimonios,
        );
      case 3:
        return Ajustes(
          movimientos: movimientos,
          categoriasGastos: categoriasGastos,
          categoriasIngresos: categoriasIngresos,
          onCategoriasChanged: () async {
            setState(() {});
            await guardarDatos();
          },
          onExportarDatos: exportarDatos,
          onExportarExcel: exportarExcel,
          onImportarDatos: importarDatos,
          googleUsuario: _googleDrive.usuario?.email,
          googleSincronizando: _googleSincronizando,
          onGoogleConectar: conectarGoogleDesdeAjustes,
          onGoogleDesconectar: desconectarGoogleDesdeAjustes,
          onGoogleSincronizar: sincronizarConGoogle,
          onGoogleRestaurar: restaurarDesdeGoogle,
          historicos: historicos,
          onHistoricosChanged: () async {
            setState(() {});
            await guardarDatos();
          },
          modoOscuro: widget.modoOscuro,
          onModoOscuroChanged: widget.onModoOscuroChanged,
        );
      default:
        return pantallaInicio();
    }
  }

  Widget _botonNavegacionWeb({
    required int indice,
    required IconData icono,
    required IconData iconoSeleccionado,
    required String texto,
  }) {
    final seleccionado = paginaActual == indice;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: seleccionado
            ? colorScheme.primary.withOpacity(.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => paginaActual = indice),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  seleccionado ? iconoSeleccionado : icono,
                  color: seleccionado ? colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                      color: seleccionado ? colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navegacionWeb() {
    return Container(
      width: 238,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(.55),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PastApp',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _botonNavegacionWeb(indice: 0, icono: Icons.home_outlined, iconoSeleccionado: Icons.home, texto: 'Inicio'),
            _botonNavegacionWeb(indice: 1, icono: Icons.calendar_month_outlined, iconoSeleccionado: Icons.calendar_month, texto: 'Calendario'),
            _botonNavegacionWeb(indice: 2, icono: Icons.bar_chart_outlined, iconoSeleccionado: Icons.bar_chart, texto: 'Estadísticas'),
            _botonNavegacionWeb(indice: 3, icono: Icons.settings_outlined, iconoSeleccionado: Icons.settings, texto: 'Ajustes'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => abrirNuevoMovimiento(tipoInicial: 'Gasto'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo movimiento'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ancho = MediaQuery.of(context).size.width;
    final escritorioWeb = kIsWeb && ancho >= 900;

    if (escritorioWeb) {
      return Scaffold(
        body: Row(
          children: [
            _navegacionWeb(),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _contenidoPaginaWeb(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: paginaActual > 3 ? 0 : paginaActual,
        children: [
          pantallaInicio(),
          Calendario(
            movimientos: movimientos,
            mesInicial: mesSeleccionado,
            onMovimientoTap: mostrarDetalleMovimiento,
            onMovimientoLongPress: mostrarOpcionesMovimiento,
          ),
          Estadisticas(
            movimientos: movimientos,
            categoriasGastos: categoriasGastos,
            categoriasIngresos: categoriasIngresos,
            historicos: historicos,
            patrimonios: patrimonios,
          ),
          Ajustes(
            movimientos: movimientos,
            categoriasGastos: categoriasGastos,
            categoriasIngresos: categoriasIngresos,
            onCategoriasChanged: () async {
              setState(() {});
              await guardarDatos();
            },
            onExportarDatos: exportarDatos,
            onExportarExcel: exportarExcel,
            onImportarDatos: importarDatos,
            googleUsuario: _googleDrive.usuario?.email,
            googleSincronizando: _googleSincronizando,
            onGoogleConectar: conectarGoogleDesdeAjustes,
            onGoogleDesconectar: desconectarGoogleDesdeAjustes,
            onGoogleSincronizar: sincronizarConGoogle,
            onGoogleRestaurar: restaurarDesdeGoogle,
            historicos: historicos,
            onHistoricosChanged: () async {
              setState(() {});
              await guardarDatos();
            },
            modoOscuro: widget.modoOscuro,
            onModoOscuroChanged: widget.onModoOscuroChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: paginaActual > 3 ? 0 : paginaActual,
        onDestinationSelected: (index) {
          setState(() => paginaActual = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Estadísticas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }}

// ============================================================
// NUEVO MOVIMIENTO POR PASOS
// ============================================================


class BuscadorMonedaSheet extends StatefulWidget {
  final List<String> activadas;
  final Set<String> habituales;
  final Future<void> Function(String codigo, bool habitual)
  onHabitualChanged;

  const BuscadorMonedaSheet({
    super.key,
    required this.activadas,
    required this.habituales,
    required this.onHabitualChanged,
  });

  @override
  State<BuscadorMonedaSheet> createState() => _BuscadorMonedaSheetState();
}

class _BuscadorMonedaSheetState extends State<BuscadorMonedaSheet> {
  final controller = TextEditingController();
  String filtro = '';
  late Set<String> habituales;
  late Set<String> activadas;

  @override
  void initState() {
    super.initState();
    habituales = {...widget.habituales};
    activadas = {...widget.activadas};
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = filtro.toLowerCase().trim();
    final lista = monedasDisponibles.where((m) {
      if (q.isEmpty) {
        return habituales.contains(m['codigo']);
      }
      return (m['codigo'] ?? '').toLowerCase().contains(q) ||
          (m['nombre'] ?? '').toLowerCase().contains(q) ||
          (m['pais'] ?? '').toLowerCase().contains(q);
    }).toList();

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Buscar moneda',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'País, moneda o código',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => filtro = v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('No se ha encontrado esa moneda'))
                    : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = lista[i];
                    final codigo = m['codigo']!;
                    final habitual = habituales.contains(codigo);
                    final activada = activadas.contains(codigo);

                    return ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        codigo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('${m['nombre']} · ${m['pais']}'),
                      trailing: IconButton(
                        tooltip: habitual
                            ? 'Quitar de habituales'
                            : 'Guardar como habitual',
                        icon: Icon(
                          habitual
                              ? Icons.star
                              : Icons.star_border,
                        ),
                        onPressed: codigo == 'EUR'
                            ? null
                            : () async {
                          final nuevoEstado = !habitual;
                          setState(() {
                            if (nuevoEstado) {
                              habituales.add(codigo);
                              activadas.add(codigo);
                            } else {
                              habituales.remove(codigo);
                              activadas.remove(codigo);
                            }
                          });
                          await widget.onHabitualChanged(
                            codigo,
                            nuevoEstado,
                          );
                        },
                      ),
                      onTap: () => Navigator.pop(context, codigo),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NuevoMovimiento
    extends StatefulWidget {
  final Map<String, dynamic>?
  movimientoExistente;

  final String? tipoInicial;

  final List<Map<String, dynamic>>
  categoriasGastos;

  final List<Map<String, dynamic>>
  categoriasIngresos;

  const NuevoMovimiento({
    super.key,
    this.movimientoExistente,
    this.tipoInicial,
    required this.categoriasGastos,
    required this.categoriasIngresos,
  });

  @override
  State<NuevoMovimiento> createState() =>
      _NuevoMovimientoState();
}

class _NuevoMovimientoState
    extends State<NuevoMovimiento> {
  int paso = 0;

  String? tipo;

  String? categoria;

  String? subcategoria;

  double? cantidad;
  double? cantidadOriginal;
  double tipoCambio = 1.0;
  bool _tipoCambioPendiente = false;
  String moneda = 'EUR';
  bool cargandoCambio = false;
  List<String> monedasOrdenadas = ['EUR', 'HUF', 'USD', 'GBP'];
  Set<String> monedasPorDefecto = {...monedasPorDefectoIniciales};

  DateTime fecha =
  DateTime.now();

  bool recurrente = false;
  bool crearSubcategoriaDesdeImporte = false;

  int intervaloMeses = 1;

  String? fotoPath;

  final cantidadController = TextEditingController();
  final intervaloController = TextEditingController(text: '1');
  final notaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarOrdenMonedas();

    final existente =
        widget.movimientoExistente;

    if (existente != null) {
      paso = 1;
      tipo =
          existente['tipo']
              ?.toString();

      categoria =
          existente['categoria']
              ?.toString();

      subcategoria =
          existente['subcategoria']
              ?.toString();

      moneda = existente['moneda']?.toString() ?? 'EUR';
      cantidadOriginal = ((existente['cantidadOriginal'] as num?) ?? (existente['cantidad'] as num?) ?? 0).toDouble();
      tipoCambio = ((existente['tipoCambio'] as num?) ?? 1).toDouble();
      _tipoCambioPendiente = existente['tipoCambioPendiente'] == true;

      cantidad =
          ((existente['cantidad']
          as num?) ??
              0)
              .toDouble();

      cantidadController.text = cantidadOriginal!.toString();

      recurrente = existente['recurrente'] == true;

      intervaloMeses =
          (((existente['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120)).toInt();
      intervaloController.text = intervaloMeses.toString();

      notaController.text = existente['nota']?.toString() ?? '';
      fotoPath = existente['fotoPath']?.toString();

      fecha =
          convertirFecha(
            existente['fecha']
                ?.toString() ??
                '',
          );
    } else {
      tipo = widget.tipoInicial ?? 'Gasto';
      paso = 1;
    }
  }

  Future<void> cargarOrdenMonedas() async {
    final prefs = await SharedPreferences.getInstance();
    final guardadas = prefs.getStringList('monedas_por_defecto');
    final activadas = prefs.getStringList('monedas_activadas') ?? [];
    final porDefecto = (guardadas == null || guardadas.isEmpty)
        ? {...monedasPorDefectoIniciales}
        : guardadas.toSet();

    final orden = <String>[];
    for (final codigo in porDefecto) {
      if (monedasDisponibles.any((m) => m['codigo'] == codigo) &&
          !orden.contains(codigo)) {
        orden.add(codigo);
      }
    }
    for (final codigo in activadas) {
      if (monedasDisponibles.any((m) => m['codigo'] == codigo) &&
          !orden.contains(codigo)) {
        orden.add(codigo);
      }
    }

    final existente = widget.movimientoExistente?['moneda']?.toString();
    if (existente != null &&
        monedasDisponibles.any((m) => m['codigo'] == existente) &&
        !orden.contains(existente)) {
      orden.add(existente);
    }

    if (!orden.contains('EUR')) orden.insert(0, 'EUR');

    if (mounted) {
      setState(() {
        monedasPorDefecto = porDefecto;
        monedasOrdenadas = orden;
      });
    }
  }

  Future<void> guardarMonedasPreferidas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'monedas_por_defecto',
      monedasPorDefecto.toList(),
    );
  }

  Future<void> mostrarOpcionesMoneda(String codigo) async {
    final habitual=monedasPorDefecto.contains(codigo), euro=codigo=='EUR';
    final accion=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Wrap(children:[ListTile(leading:const Icon(Icons.currency_exchange),title:Text('$codigo · ${nombreMoneda(codigo)}'),subtitle:Text(habitual?'Moneda habitual':'Moneda disponible para este movimiento')),if(!habitual&&!euro)ListTile(leading:const Icon(Icons.star_border),title:const Text('Guardar como moneda habitual'),onTap:()=>Navigator.pop(c,'guardar')),if(habitual&&!euro)ListTile(leading:const Icon(Icons.star),title:const Text('Quitar de monedas habituales'),onTap:()=>Navigator.pop(c,'quitar')),if(!euro)ListTile(leading:const Icon(Icons.delete_outline),title:const Text('Eliminar de mis monedas'),subtitle:const Text('Podrás volver a encontrarla con el buscador'),onTap:()=>Navigator.pop(c,'eliminar'))])));
    if(accion==null||!mounted)return; final prefs=await SharedPreferences.getInstance(); final activadas=prefs.getStringList('monedas_activadas')??[];
    if(accion=='guardar'){monedasPorDefecto.add(codigo);if(!monedasOrdenadas.contains(codigo))monedasOrdenadas.add(codigo);await guardarMonedasPreferidas();}
    else if(accion=='quitar'){monedasPorDefecto.remove(codigo);await guardarMonedasPreferidas();}
    else{activadas.remove(codigo);monedasPorDefecto.remove(codigo);monedasOrdenadas.remove(codigo);await prefs.setStringList('monedas_activadas',activadas.toSet().toList());await guardarMonedasPreferidas();if(moneda==codigo)moneda='EUR';}
    if(mounted)setState((){});
  }

  Future<void> buscarYAnadirMoneda() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    final activadas = prefs.getStringList('monedas_activadas') ?? [];
    final seleccion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuscadorMonedaSheet(
        activadas: activadas,
        habituales: monedasPorDefecto,
        onHabitualChanged: (codigo, habitual) async {
          if (habitual) {
            monedasPorDefecto.add(codigo);
            if (!monedasOrdenadas.contains(codigo)) {
              monedasOrdenadas.add(codigo);
            }
          } else {
            monedasPorDefecto.remove(codigo);
            monedasOrdenadas.remove(codigo);
            activadas.remove(codigo);
          }

          await prefs.setStringList(
            'monedas_activadas',
            activadas.toList(),
          );
          await guardarMonedasPreferidas();

          if (mounted) setState(() {});
        },
      ),
    );
    if (seleccion == null || !mounted) return;

    if (mounted) setState(() => moneda = seleccion);
  }

  Future<void> registrarUsoMoneda(String codigo) async {
    // Las monedas usadas una vez no se convierten automáticamente en habituales.
    // Solo se mantienen en la lista de monedas activadas cuando el usuario las busca.
    if (mounted && !monedasOrdenadas.contains(codigo)) {
      setState(() => monedasOrdenadas.add(codigo));
    }
  }


  @override
  void dispose() {
    cantidadController.dispose();
    intervaloController.dispose();
    notaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>
  get categorias {
    if (tipo == 'Ingreso') {
      return widget
          .categoriasIngresos;
    }

    return widget
        .categoriasGastos;
  }

  Map<String, dynamic>?
  get categoriaActual {
    for (final c
    in categorias) {
      if (c['nombre']
          ?.toString() ==
          categoria) {
        return c;
      }
    }

    return null;
  }

  List<String>
  get subcategorias {
    final actual =
        categoriaActual;

    if (actual == null) {
      return [];
    }

    return List<String>.from(
      actual['subcategorias'] ??
          [],
    );
  }

  // ==========================================================
  // SELECCIÓN DE TIPO
  // ==========================================================

  void seleccionarTipo(
      String nuevoTipo,
      ) {
    setState(() {
      tipo = nuevoTipo;
      categoria = null;
      subcategoria = null;
      paso = 1;
    });
  }

  // ==========================================================
  // SELECCIÓN DE CATEGORÍA
  // ==========================================================

  void seleccionarCategoria(
      Map<String, dynamic> nuevaCategoria,
      ) {
    setState(() {
      categoria = nuevaCategoria['nombre'];
      final subs = List<String>.from(nuevaCategoria['subcategorias'] ?? []);
      subcategoria = null;
      paso = 2;
    });
  }

  // ==========================================================
  // CREAR SUBCATEGORÍA DESDE EL MOVIMIENTO
  // ==========================================================

  Future<void> crearSubcategoria() async {
    final nombre = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const NuevaSubcategoriaPage()),
    );

    if (nombre == null || nombre.trim().isEmpty) return;

    final actual = categoriaActual;
    if (actual == null) return;

    final texto = nombre.trim();
    final lista = List<String>.from(actual['subcategorias'] ?? []);

    if (!lista.contains(texto)) {
      lista.add(texto);
      if (!lista.contains('Otros')) lista.add('Otros');
      setState(() {
        actual['subcategorias'] = lista;
        subcategoria = texto;
      });
    }
  }

  // ==========================================================
  // SELECCIÓN DE SUBCATEGORÍA
  // ==========================================================

  void seleccionarSubcategoria(
      String? nuevaSubcategoria,
      ) {
    setState(() {
      subcategoria = nuevaSubcategoria;
      paso = 2;
    });
  }

  // ==========================================================
  // CANTIDAD
  // ==========================================================

  Future<void> confirmarCantidad() async {
    final valor =
    double.tryParse(
      cantidadController.text
          .replaceAll(
        ',',
        '.',
      ),
    );

    if (valor == null ||
        valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
          Text(
            'Introduce una cantidad válida',
          ),
        ),
      );

      return;
    }

    cantidadOriginal = valor;
    cargandoCambio = true;
    setState(() {});
    tipoCambio = await ServicioDivisas.obtenerCambioAEuro(moneda, fecha);
    cargandoCambio = false;
    final cambioPendiente = moneda != 'EUR' && tipoCambio <= 0;
    cantidad = cambioPendiente ? 0.0 : (moneda == 'EUR' ? valor : valor / tipoCambio);
    if (cambioPendiente && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardaremos la operación con el cambio pendiente y la completaremos al recuperar internet.')),
      );
    }
    _tipoCambioPendiente = cambioPendiente;

    if (crearSubcategoriaDesdeImporte) {
      final nombre = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const NuevaSubcategoriaPage()),
      );

      if (!mounted) return;
      if (nombre == null || nombre.trim().isEmpty) {
        setState(() {});
        return;
      }

      final actual = categoriaActual;
      if (actual != null) {
        final lista = List<String>.from(actual['subcategorias'] ?? []);
        final texto = nombre.trim();
        if (!lista.contains(texto)) lista.add(texto);
        if (!lista.contains('Otros')) lista.add('Otros');
        actual['subcategorias'] = lista;
        subcategoria = texto;
      }
    }

    // Si no se ha elegido ninguna subcategoría, se guarda automáticamente
    // como 'Otros'. 'Otros' no se muestra como opción en la pantalla.
    if (subcategorias.isNotEmpty &&
        (subcategoria == null || subcategoria!.trim().isEmpty)) {
      subcategoria = subcategorias.contains('Otros') ? 'Otros' : 'Otros';
    }

    setState(() {
      paso = 3;
    });
  }

  // ==========================================================
  // FECHA
  // ==========================================================

  Future<void>
  seleccionarFecha() async {
    final nueva = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        DateTime seleccionada = fecha;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 35, left: 12, right: 12),
                child: Material(
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: CalendarDatePicker(
                    initialDate: seleccionada,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onDateChanged: (valor) {
                      setDialogState(() => seleccionada = valor);
                      Navigator.pop(dialogContext, valor);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (nueva != null) {
      setState(() {
        fecha = nueva;
      });
    }
  }

  // ==========================================================
  // FOTO
  // ==========================================================

  Future<void> seleccionarFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Añadir foto',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.camera_alt_outlined),
                  ),
                  title: const Text('Hacer una foto'),
                  subtitle: const Text('Abrir la cámara ahora'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Elegir de la galería'),
                  subtitle: const Text('Usar una foto que ya tienes'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (origen == null) return;

    final picker = ImagePicker();
    final imagen = await picker.pickImage(
      source: origen,
      imageQuality: 85,
    );

    if (imagen == null) return;

    final directorio = await getApplicationDocumentsDirectory();
    final extension = imagen.path.contains('.')
        ? imagen.path.substring(imagen.path.lastIndexOf('.'))
        : '.jpg';
    final destino = File(
      '${directorio.path}/movimiento_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await File(imagen.path).copy(destino.path);

    if (mounted) {
      setState(() {
        fotoPath = destino.path;
      });
    }
  }

  void quitarFoto() {
    setState(() {
      fotoPath = null;
    });
  }

  // ==========================================================
  // GUARDAR
  // ==========================================================

  Future<void> guardar() async {
    final valor = double.tryParse(
      cantidadController.text.trim().replaceAll(',', '.'),
    );

    if (tipo == null || categoria == null || valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el tipo, categoría e importe.'),
        ),
      );
      return;
    }

    if (subcategorias.isNotEmpty &&
        (subcategoria == null || subcategoria!.trim().isEmpty)) {
      subcategoria = 'Otros';
    }

    cargandoCambio = true;
    if (mounted) setState(() {});

    cantidadOriginal = valor;

    if (moneda == 'EUR') {
      tipoCambio = 1.0;
      _tipoCambioPendiente = false;
      cantidad = valor;
    } else {
      tipoCambio = await ServicioDivisas.obtenerCambioAEuro(
        moneda,
        fecha,
      );
      _tipoCambioPendiente = tipoCambio <= 0;
      cantidad = _tipoCambioPendiente ? 0.0 : valor / tipoCambio;
    }

    cargandoCambio = false;
    if (!mounted) return;
    setState(() {});

    final emoji = categoriaActual?['emoji'];

    final movimiento = {
      'id':
      widget.movimientoExistente?['id'] ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      'cantidad': cantidad!,
      'cantidadOriginal': cantidadOriginal ?? cantidad!,
      'moneda': moneda,
      'tipoCambio': tipoCambio,
      'tipoCambioPendiente': _tipoCambioPendiente,

      'tipo':
      tipo!,

      'categoria':
      categoria!,

      'subcategoria':
      subcategoria,

      'fecha':
      fechaTexto(fecha),

      'fechaCreacion':
      fechaTexto(DateTime.now()),

      'hora':
      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',

      'emoji':
      emoji,

      'recurrente': recurrente,

      'intervaloMeses': recurrente
          ? ((int.tryParse(intervaloController.text.trim()) ?? intervaloMeses).clamp(1, 120))
          : 1,

      'recurrenceId':
      widget.movimientoExistente?[
      'recurrenceId'],

      // La plantilla solo se usa para la serie recurrente.
      // Las entradas ya generadas conservan su importe histórico.
      'plantillaCantidad': recurrente ? cantidad! : null,
      'plantillaCantidadOriginal': recurrente ? (cantidadOriginal ?? cantidad!) : null,
      'plantillaMoneda': recurrente ? moneda : null,
      'plantillaTipoCambio': recurrente ? tipoCambio : null,
      'plantillaTipoCambioPendiente': recurrente ? _tipoCambioPendiente : null,
      'plantillaCategoria': recurrente ? categoria : null,
      'plantillaSubcategoria': recurrente ? subcategoria : null,
      'plantillaEmoji': recurrente ? emoji : null,
      'plantillaNota': recurrente ? notaController.text.trim() : null,
      'plantillaFotoPath': recurrente ? fotoPath : null,
      'plantillaIntervaloMeses': recurrente ? ((int.tryParse(intervaloController.text.trim()) ?? intervaloMeses).clamp(1, 120)) : null,

      'nota': notaController.text.trim(),
      'fotoPath': fotoPath,
    };

    await registrarUsoMoneda(moneda);
    if (!mounted) return;

    Navigator.pop(
      context,
      movimiento,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final tipoTexto = tipo == 'Ingreso' ? 'Ingreso' : 'Gasto';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.movimientoExistente == null
              ? 'Nuevo $tipoTexto'
              : 'Editar $tipoTexto',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Gasto',
                    icon: Icon(Icons.arrow_downward),
                    label: Text('Gasto'),
                  ),
                  ButtonSegment(
                    value: 'Ingreso',
                    icon: Icon(Icons.arrow_upward),
                    label: Text('Ingreso'),
                  ),
                ],
                selected: {tipo ?? 'Gasto'},
                onSelectionChanged: (seleccion) {
                  seleccionarTipo(seleccion.first);
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categorias.map((c) {
                  final nombre = c['nombre']?.toString() ?? '';
                  return ChoiceChip(
                    selected: categoria == nombre,
                    avatar: Text(
                      c['emoji']?.toString() ?? '💰',
                      style: const TextStyle(fontSize: 17),
                    ),
                    label: Text(nombre),
                    onSelected: (_) => seleccionarCategoria(c),
                  );
                }).toList(),
              ),
              if (categoria != null && subcategorias.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Subcategoría',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...subcategorias
                        .where((s) => s != 'Otros')
                        .map(
                          (s) => ChoiceChip(
                        label: Text(s),
                        selected: subcategoria == s,
                        onSelected: (_) =>
                            setState(() => subcategoria = s),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva'),
                      onPressed: crearSubcategoria,
                    ),
                  ],
                ),
                if (subcategoria == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Si no eliges ninguna, se guardará en Otros.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Importe',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cantidadController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  suffixIcon: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: buscarYAnadirMoneda,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          moneda,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca la moneda para buscar otra.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Fecha'),
                  subtitle: Text(fechaTexto(fecha)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: seleccionarFecha,
                ),
              ),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Recurrente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        recurrente
                            ? 'Cada $intervaloMeses mes${intervaloMeses == 1 ? '' : 'es'}'
                            : 'No se repetirá',
                      ),
                      value: recurrente,
                      onChanged: (valor) {
                        setState(() => recurrente = valor);
                      },
                    ),
                    if (recurrente)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: TextField(
                          controller: intervaloController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cada cuántos meses',
                            hintText: '1 = cada mes, 2 = cada 2 meses',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (valor) {
                            final numero = int.tryParse(valor);
                            if (numero != null && numero >= 1) {
                              setState(() {
                                intervaloMeses =
                                    numero.clamp(1, 120).toInt();
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notaController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (fotoPath != null && File(fotoPath!).existsSync())
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(fotoPath!),
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: seleccionarFoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Cambiar foto'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: quitarFoto,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: seleccionarFoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Añadir foto'),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: guardar,
                  child: const Text(
                    'GUARDAR MOVIMIENTO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget opcionGrande({
    required IconData icon,
    required String titulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: color),
                const SizedBox(height: 6),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CALENDARIO
// ============================================================

class Calendario
    extends StatefulWidget {
  final List<Map<String, dynamic>>
  movimientos;

  final DateTime mesInicial;
  final Future<void> Function(Map<String, dynamic>) onMovimientoTap;
  final Future<void> Function(Map<String, dynamic>) onMovimientoLongPress;

  const Calendario({
    super.key,
    required this.movimientos,
    required this.mesInicial,
    required this.onMovimientoTap,
    required this.onMovimientoLongPress,
  });

  @override
  State<Calendario> createState() =>
      _CalendarioState();
}

class _CalendarioState
    extends State<Calendario> {
  late DateTime mes;

  @override
  void initState() {
    super.initState();
    mes =
        widget.mesInicial;
  }

  List<Map<String, dynamic>>
  movimientosDia(
      DateTime dia,
      ) {
    final resultado = widget.movimientos
        .where(
          (m) =>
      m['fecha'] ==
          fechaTexto(dia) &&
          m['tipo'] != 'Ajuste',
    )
        .toList();

    resultado.sort(compararMovimientosPorFechaHoraDesc);

    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final primerDia =
    DateTime(
      mes.year,
      mes.month,
      1,
    );

    final diasMes =
        DateTime(
          mes.year,
          mes.month + 1,
          0,
        ).day;

    final espacioInicial =
        primerDia.weekday - 1;

    final totalCasillas =
        espacioInicial +
            diasMes;

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Calendario',
        ),
      ),

      body:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          15,
        ),
        child:
        Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      mes =
                          DateTime(
                            mes.year,
                            mes.month -
                                1,
                          );
                    });
                  },
                  icon:
                  const Icon(
                    Icons
                        .chevron_left,
                  ),
                ),

                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: seleccionarMesCalendario,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Center(
                        child: Text(
                          '${nombreMes(mes)} ${mes.year}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      mes =
                          DateTime(
                            mes.year,
                            mes.month +
                                1,
                          );
                    });
                  },
                  icon:
                  const Icon(
                    Icons
                        .chevron_right,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                'L',
                'M',
                'X',
                'J',
                'V',
                'S',
                'D',
              ]
                  .map(
                    (dia) =>
                    Expanded(
                      child:
                      Center(
                        child:
                        Text(
                          dia,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                    ),
              )
                  .toList(),
            ),

            const SizedBox(
              height: 8,
            ),

            GridView.builder(
              shrinkWrap:
              true,
              physics:
              const NeverScrollableScrollPhysics(),
              itemCount:
              totalCasillas,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 64,
              ),
              itemBuilder:
                  (_, index) {
                if (index <
                    espacioInicial) {
                  return const SizedBox();
                }

                final diaNumero =
                    index -
                        espacioInicial +
                        1;

                final dia =
                DateTime(
                  mes.year,
                  mes.month,
                  diaNumero,
                );

                final movimientos =
                movimientosDia(
                  dia,
                );

                final gastos =
                movimientos
                    .where(
                      (m) =>
                  m['tipo'] ==
                      'Gasto',
                )
                    .fold(
                  0.0,
                      (total,
                      m) =>
                  total +
                      ((m['cantidad']
                      as num?) ??
                          0)
                          .toDouble(),
                );

                final ingresos =
                movimientos
                    .where(
                      (m) =>
                  m['tipo'] ==
                      'Ingreso',
                )
                    .fold(
                  0.0,
                      (total,
                      m) =>
                  total +
                      ((m['cantidad']
                      as num?) ??
                          0)
                          .toDouble(),
                );

                return InkWell(
                  onTap:
                  movimientos.isEmpty
                      ? null
                      : () =>
                      mostrarDia(
                        dia,
                        movimientos,
                      ),
                  child:
                  Container(
                    margin:
                    const EdgeInsets.all(
                      2,
                    ),
                    padding:
                    const EdgeInsets.all(
                      4,
                    ),
                    decoration:
                    BoxDecoration(
                      border:
                      Border.all(
                        color:
                        Colors.grey
                            .shade300,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        8,
                      ),
                    ),
                    child:
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            '$diaNumero',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (gastos > 0)
                                Text(
                                  '-${gastos.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (ingresos > 0)
                                Text(
                                  '+${ingresos.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> seleccionarMesCalendario() async {
    final resultado = await showDialog<DateTime>(
      context: context,
      builder: (_) => SelectorMes(inicial: mes),
    );

    if (resultado != null && mounted) {
      setState(() {
        mes = resultado;
      });
    }
  }

  void mostrarDia(
      DateTime dia,
      List<Map<String, dynamic>>
      movimientos,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dia.day} de ${nombreMes(dia)} ${dia.year}',
                      style:
                      const TextStyle(
                        fontSize:
                        22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    ...movimientos.map(
                          (m) {
                        final gasto =
                            m['tipo'] ==
                                'Gasto';

                        final cantidad =
                        ((m['cantidad']
                        as num?) ??
                            0)
                            .toDouble();

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 120), () {
                              if (mounted) {
                                widget.onMovimientoTap(m);
                              }
                            });
                          },
                          onDoubleTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 120), () {
                              if (mounted) {
                                widget.onMovimientoLongPress(m);
                              }
                            });
                          },
                          child: ListTile(
                            leading:
                            CircleAvatar(
                              backgroundColor: const Color(0xFFF1F1F1),
                              child: Text(
                                m['emoji'] ?? (gasto ? '💸' : '💰'),
                                style: const TextStyle(fontSize: 21),
                              ),
                            ),
                            title:
                            Text(
                              m['categoria'] ??
                                  m['tipo'],
                            ),
                            subtitle: Text(
                              '${m['subcategoria']?.toString() ?? ''}'
                                  '${m['nota']?.toString().trim().isNotEmpty == true ? ' · 📝' : ''}'
                                  '${m['fotoPath']?.toString().trim().isNotEmpty == true ? ' · 📷' : ''}',
                            ),
                            trailing:
                            Text(
                              '${gasto ? '-' : '+'}${formatearEuros(cantidad)}',
                              style:
                              TextStyle(
                                color:
                                gasto
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

// ============================================================
// ESTADÍSTICAS
// ============================================================

class Estadisticas
    extends StatefulWidget {
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> categoriasGastos;
  final List<Map<String, dynamic>> categoriasIngresos;
  final List<Map<String, dynamic>> historicos;
  final List<Map<String, dynamic>> patrimonios;

  const Estadisticas({
    super.key,
    required this.movimientos,
    required this.historicos,
    required this.categoriasGastos,
    required this.categoriasIngresos,
    required this.patrimonios,
  });

  @override
  State<Estadisticas> createState() => _EstadisticasState();
}

class _EstadisticasState extends State<Estadisticas> {
  String periodo = 'Mes';
  String? filtroTipo;
  final Set<String> categoriasAbiertas = {};

  List<Map<String, dynamic>> get movimientosFiltrados {
    final ahora = DateTime.now();
    late DateTime inicio;
    late DateTime fin;

    if (periodo == 'Semana') {
      inicio = DateTime(ahora.year, ahora.month, ahora.day - (ahora.weekday - 1));
      fin = inicio.add(const Duration(days: 7));
    } else if (periodo == 'Año') {
      inicio = DateTime(ahora.year, 1, 1);
      fin = DateTime(ahora.year + 1, 1, 1);
    } else {
      inicio = DateTime(ahora.year, ahora.month, 1);
      fin = DateTime(ahora.year, ahora.month + 1, 1);
    }

    return widget.movimientos.where((m) {
      if (m['tipo'] == 'Ajuste') return false;
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      return !fecha.isBefore(inicio) && fecha.isBefore(fin);
    }).toList();
  }

  double cantidad(Map<String, dynamic> m) =>
      ((m['cantidad'] as num?) ?? 0).toDouble();

  double get historicoGastosPeriodo {
    if (periodo != 'Año') return 0;
    final ahora = DateTime.now();
    return widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year).fold(0.0, (t, h) =>
    t + ((h['hipoteca'] as num?) ?? 0).toDouble() + ((h['alquiler'] as num?) ?? 0).toDouble() + ((h['gastosTotalesHistorico'] as num?) ?? 0).toDouble());
  }

  double get historicoIngresosPeriodo {
    if (periodo != 'Año') return 0;
    final ahora = DateTime.now();
    return widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year).fold(0.0, (t, h) =>
    t + ((h['salario'] as num?) ?? 0).toDouble() + ((h['pieris'] as num?) ?? 0).toDouble());
  }

  List<Map<String, dynamic>> get movimientosSegunFiltro {
    if (filtroTipo == null) return movimientosFiltrados;
    return movimientosFiltrados
        .where((m) => m['tipo'] == filtroTipo)
        .toList();
  }

  double get totalGastos => movimientosFiltrados
      .where((m) => m['tipo'] == 'Gasto')
      .fold(0.0, (total, m) => total + cantidad(m)) +
      (filtroTipo == 'Ingreso' ? 0 : historicoGastosPeriodo);

  double get totalIngresos => movimientosFiltrados
      .where((m) => m['tipo'] == 'Ingreso')
      .fold(0.0, (total, m) => total + cantidad(m)) +
      (filtroTipo == 'Gasto' ? 0 : historicoIngresosPeriodo);

  Map<String, double> gastosPorCategoria() {
    final mapa = <String, double>{};
    for (final m in movimientosSegunFiltro) {
      if (m['tipo'] != 'Gasto') continue;
      final categoria = m['categoria']?.toString() ?? 'Miscelánea';
      mapa[categoria] = (mapa[categoria] ?? 0) + cantidad(m);
    }
    if (periodo == 'Año') {
      final ahora = DateTime.now();
      for (final h in widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year)) {
        mapa['Hipotecas'] = (mapa['Hipotecas'] ?? 0) + ((h['hipoteca'] as num?) ?? 0).toDouble();
        mapa['Alquiler'] = (mapa['Alquiler'] ?? 0) + ((h['alquiler'] as num?) ?? 0).toDouble();
      }
    }
    return mapa;
  }

  Map<String, double> ingresosPorCategoria() {
    final mapa = <String, double>{};
    for (final m in movimientosSegunFiltro) {
      if (m['tipo'] != 'Ingreso') continue;
      final categoria = m['categoria']?.toString() ?? 'Miscelánea';
      mapa[categoria] = (mapa[categoria] ?? 0) + cantidad(m);
    }
    if (periodo == 'Año') {
      final ahora = DateTime.now();
      for (final h in widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year)) {
        mapa['Salario'] = (mapa['Salario'] ?? 0) + ((h['salario'] as num?) ?? 0).toDouble();
        mapa['Pieris'] = (mapa['Pieris'] ?? 0) + ((h['pieris'] as num?) ?? 0).toDouble();
      }
    }
    return mapa;
  }

  Map<String, double> gastosPorSubcategoria(String categoria) {
    final mapa = <String, double>{};
    for (final m in movimientosSegunFiltro) {
      if (m['tipo'] != 'Gasto' || m['categoria']?.toString() != categoria) continue;
      final sub = m['subcategoria']?.toString().trim();
      final nombre = sub == null || sub.isEmpty ? 'Otros' : sub;
      mapa[nombre] = (mapa[nombre] ?? 0) + cantidad(m);
    }
    return mapa;
  }

  String emojiCategoria(String nombre) {
    for (final c in widget.categoriasGastos) {
      if (c['nombre']?.toString() == nombre) {
        return c['emoji']?.toString() ?? '📦';
      }
    }
    return '📦';
  }

  String emojiIngreso(String nombre) {
    for (final c in widget.categoriasIngresos) {
      if (c['nombre']?.toString() == nombre) {
        return c['emoji']?.toString() ?? '💰';
      }
    }
    return '💰';
  }

  @override
  Widget build(BuildContext context) {
    final categorias = filtroTipo == 'Ingreso'
        ? ingresosPorCategoria()
        : gastosPorCategoria();
    final ordenadas = categorias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Semana', label: Text('Semana')),
                ButtonSegment(value: 'Mes', label: Text('Mes')),
                ButtonSegment(value: 'Año', label: Text('Año')),
              ],
              selected: {periodo},
              onSelectionChanged: (seleccion) {
                setState(() {
                  periodo = seleccion.first;
                  categoriasAbiertas.clear();
                });
              },
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: resumenEstadistica('Ingresos', totalIngresos, Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: resumenEstadistica('Gastos', totalGastos, Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            resumenEstadistica(
              'Balance',
              totalIngresos - totalGastos,
              totalIngresos - totalGastos >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GraficasFinanzas(
                        movimientos: widget.movimientos,
                        historicos: widget.historicos,
                        categoriasGastos: widget.categoriasGastos,
                        categoriasIngresos: widget.categoriasIngresos,
                        patrimonios: widget.patrimonios,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver gráficas'),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _filtroEstadisticaChip(
                    'Todos',
                    null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filtroEstadisticaChip(
                    'Ingresos',
                    'Ingreso',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filtroEstadisticaChip(
                    'Gastos',
                    'Gasto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (filtroTipo == null) ...[
              const Text(
                'Gastos por categoría',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._listaCategorias(gastosPorCategoria(), 'Gasto'),
              const SizedBox(height: 24),
              const Text(
                'Ingresos por categoría',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._listaCategorias(ingresosPorCategoria(), 'Ingreso'),
            ] else if (ordenadas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No hay movimientos en este periodo.'),
                ),
              )
            else
              ...ordenadas.map((entrada) {
                final abierta = categoriasAbiertas.contains(entrada.key);
                final subcategorias =
                subcategoriasPorTipo(entrada.key, filtroTipo!)
                    .entries
                    .toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final totalPeriodo =
                filtroTipo == 'Ingreso' ? totalIngresos : totalGastos;
                final porcentaje =
                totalPeriodo > 0 ? entrada.value / totalPeriodo : 0.0;

                return Card(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (abierta) {
                              categoriasAbiertas.remove(entrada.key);
                            } else {
                              categoriasAbiertas.add(entrada.key);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Text(
                                filtroTipo == 'Ingreso'
                                    ? emojiIngreso(entrada.key)
                                    : emojiCategoria(entrada.key),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entrada.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 7),
                                    LinearProgressIndicator(value: porcentaje),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatearEuros(entrada.value)),
                                  Text('${(porcentaje * 100).toStringAsFixed(1)}%'),
                                ],
                              ),
                              Icon(abierta ? Icons.expand_less : Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      if (abierta)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                          child: Column(
                            children: subcategorias.map((sub) {
                              final porcentajeSub =
                              totalPeriodo > 0 ? sub.value / totalPeriodo : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(sub.key)),
                                    Text('${formatearEuros(sub.value)} · ${(porcentajeSub * 100).toStringAsFixed(1)}%'),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Widget> _listaCategorias(
      Map<String, double> datos,
      String tipo,
      ) {
    final entradas = datos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entradas.isEmpty) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay movimientos en este periodo.'),
          ),
        ),
      ];
    }

    final total = tipo == 'Ingreso' ? totalIngresos : totalGastos;

    return entradas.map((entrada) {
      final clave = '$tipo:${entrada.key}';
      final abierta = categoriasAbiertas.contains(clave);
      final subcategorias =
      subcategoriasPorTipo(entrada.key, tipo).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final porcentaje = total > 0 ? entrada.value / total : 0.0;

      return Card(
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (abierta) {
                    categoriasAbiertas.remove(clave);
                  } else {
                    categoriasAbiertas.add(clave);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      tipo == 'Ingreso'
                          ? emojiIngreso(entrada.key)
                          : emojiCategoria(entrada.key),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entrada.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(value: porcentaje),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatearEuros(entrada.value)),
                        Text('${(porcentaje * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                    Icon(
                      abierta ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (abierta && subcategorias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                child: Column(
                  children: subcategorias.map((sub) {
                    final porcentajeSub =
                    total > 0 ? sub.value / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(child: Text(sub.key)),
                          Text(
                            '${formatearEuros(sub.value)} · '
                                '${(porcentajeSub * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Map<String, double> subcategoriasPorTipo(
      String categoria,
      String tipo,
      ) {
    final mapa = <String, double>{};

    for (final m in movimientosFiltrados) {
      if (m['tipo'] != tipo ||
          m['categoria']?.toString() != categoria) {
        continue;
      }

      final sub = m['subcategoria']?.toString().trim();
      final nombre = sub == null || sub.isEmpty ? 'Otros' : sub;
      mapa[nombre] = (mapa[nombre] ?? 0) + cantidad(m);
    }

    return mapa;
  }

  Widget _filtroEstadisticaChip(String label, String? tipo) {
    final seleccionado = filtroTipo == tipo;
    return ChoiceChip(
      label: Center(child: Text(label)),
      selected: seleccionado,
      onSelected: (_) {
        setState(() {
          filtroTipo = tipo;
          categoriasAbiertas.clear();
        });
      },
    );
  }

  Widget resumenEstadistica(String titulo, double cantidad, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo),
            const SizedBox(height: 5),
            Text(
              formatearEuros(cantidad),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GRÁFICAS
// ============================================================

class GraficasFinanzas extends StatefulWidget {
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> historicos;
  final List<Map<String, dynamic>> categoriasGastos;
  final List<Map<String, dynamic>> categoriasIngresos;
  final List<Map<String, dynamic>> patrimonios;

  const GraficasFinanzas({
    super.key,
    required this.movimientos,
    required this.historicos,
    required this.categoriasGastos,
    required this.categoriasIngresos,
    required this.patrimonios,
  });

  @override
  State<GraficasFinanzas> createState() => _GraficasFinanzasState();
}

class _GraficasFinanzasState extends State<GraficasFinanzas> {
  String modo = 'Gastos';
  String periodoDistribucion = 'Mes';

  double cantidad(Map<String, dynamic> m) =>
      ((m['cantidad'] as num?) ?? 0).toDouble();

  DateTime fechaMovimiento(Map<String, dynamic> m) =>
      convertirFecha(m['fecha']?.toString() ?? '');

  List<Map<String, dynamic>> hastaHoy() {
    final ahora = DateTime.now();
    return widget.movimientos.where((m) {
      final tipo = m['tipo']?.toString();
      if (tipo != 'Gasto' && tipo != 'Ingreso') return false;
      final fecha = fechaMovimiento(m);
      return fecha.year == ahora.year && !fecha.isAfter(ahora);
    }).toList();
  }

  Map<String, double> porCategoria(String tipo, {String? periodo}) {
    final ahora = DateTime.now();
    DateTime inicio;
    DateTime fin;
    final p = periodo ?? periodoDistribucion;
    if (p == 'Semana') {
      inicio = DateTime(ahora.year, ahora.month, ahora.day - (ahora.weekday - 1));
      fin = inicio.add(const Duration(days: 7));
    } else if (p == 'Año') {
      inicio = DateTime(ahora.year, 1, 1);
      fin = ahora.add(const Duration(days: 1));
    } else {
      inicio = DateTime(ahora.year, ahora.month, 1);
      fin = DateTime(ahora.year, ahora.month + 1, 1);
    }

    final mapa = <String, double>{};
    for (final m in widget.movimientos) {
      if (m['tipo'] != tipo) continue;
      final fecha = fechaMovimiento(m);
      if (fecha.isBefore(inicio) || !fecha.isBefore(fin)) continue;
      final categoria = m['categoria']?.toString() ?? 'Miscelánea';
      mapa[categoria] = (mapa[categoria] ?? 0) + cantidad(m);
    }
    if (p == 'Año') {
      final ahora = DateTime.now();
      for (final h in widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year && ((h['mes'] as num?)?.toInt() ?? 0) <= ahora.month)) {
        if (tipo == 'Ingreso') {
          mapa['Salario'] = (mapa['Salario'] ?? 0) + ((h['salario'] as num?) ?? 0).toDouble();
          mapa['Pieris'] = (mapa['Pieris'] ?? 0) + ((h['pieris'] as num?) ?? 0).toDouble();
        } else {
          mapa['Hipotecas'] = (mapa['Hipotecas'] ?? 0) + ((h['hipoteca'] as num?) ?? 0).toDouble();
          mapa['Alquiler'] = (mapa['Alquiler'] ?? 0) + ((h['alquiler'] as num?) ?? 0).toDouble();
        }
      }
    }
    return mapa;
  }

  Map<String, List<double>> evolucionPorCategoria(String tipo) {
    final ahora = DateTime.now();
    final resultado = <String, List<double>>{};
    for (final m in widget.movimientos) {
      if (m['tipo'] != tipo) continue;
      final fecha = fechaMovimiento(m);
      if (fecha.year != ahora.year || fecha.isAfter(ahora)) continue;
      final categoria = m['categoria']?.toString() ?? 'Miscelánea';
      resultado.putIfAbsent(categoria, () => List<double>.filled(ahora.month, 0));
      resultado[categoria]![fecha.month - 1] += cantidad(m);
    }
    if (tipo == 'Gasto' || tipo == 'Ingreso') {
      final ahora = DateTime.now();
      for (final h in widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year)) {
        final mes = ((h['mes'] as num?) ?? 0).toInt();
        if (mes < 1 || mes > ahora.month) continue;
        if (tipo == 'Ingreso') {
          resultado.putIfAbsent('Salario', () => List<double>.filled(ahora.month, 0));
          resultado.putIfAbsent('Pieris', () => List<double>.filled(ahora.month, 0));
          resultado['Salario']![mes - 1] += ((h['salario'] as num?) ?? 0).toDouble();
          resultado['Pieris']![mes - 1] += ((h['pieris'] as num?) ?? 0).toDouble();
        } else {
          resultado.putIfAbsent('Hipotecas', () => List<double>.filled(ahora.month, 0));
          resultado.putIfAbsent('Alquiler', () => List<double>.filled(ahora.month, 0));
          resultado['Hipotecas']![mes - 1] += ((h['hipoteca'] as num?) ?? 0).toDouble();
          resultado['Alquiler']![mes - 1] += ((h['alquiler'] as num?) ?? 0).toDouble();
        }
      }
    }
    return resultado;
  }

  List<double> totalesMensuales(String tipo) {
    final ahora = DateTime.now();
    final valores = List<double>.filled(ahora.month, 0);
    for (final m in widget.movimientos) {
      if (m['tipo'] != tipo) continue;
      final fecha = fechaMovimiento(m);
      if (fecha.year != ahora.year || fecha.isAfter(ahora)) continue;
      valores[fecha.month - 1] += cantidad(m);
    }
    for (final h in widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == ahora.year)) {
      final mes = ((h['mes'] as num?) ?? 0).toInt();
      if (mes < 1 || mes > ahora.month) continue;
      if (tipo == 'Ingreso') {
        valores[mes - 1] += ((h['salario'] as num?) ?? 0).toDouble() + ((h['pieris'] as num?) ?? 0).toDouble();
      } else {
        valores[mes - 1] += ((h['hipoteca'] as num?) ?? 0).toDouble() + ((h['alquiler'] as num?) ?? 0).toDouble() + ((h['gastosTotalesHistorico'] as num?) ?? 0).toDouble();
      }
    }
    return valores;
  }

  String nombreMesCorto(int mes) {
    const nombres = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return nombres[mes - 1];
  }

  String emojiCategoria(String nombre, String tipo) {
    final lista = tipo == 'Gasto' ? widget.categoriasGastos : widget.categoriasIngresos;
    for (final c in lista) {
      if (c['nombre']?.toString() == nombre) return c['emoji']?.toString() ?? '📦';
    }
    return tipo == 'Gasto' ? '📦' : '💰';
  }

  @override
  Widget build(BuildContext context) {
    final gastos = porCategoria('Gasto');
    final ingresos = porCategoria('Ingreso');
    final evolucionGastos = evolucionPorCategoria('Gasto');
    final evolucionIngresos = evolucionPorCategoria('Ingreso');
    final ahora = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Gráficas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Qué quieres ver', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Gastos', label: Text('Gastos')),
                ButtonSegment(value: 'Ingresos', label: Text('Ingresos')),
                ButtonSegment(value: 'Total', label: Text('Total')),
              ],
              selected: {modo},
              onSelectionChanged: (s) => setState(() => modo = s.first),
            ),
            const SizedBox(height: 25),
            if (modo == 'Gastos') ...[
              const Text('Evolución de gastos por categoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('2026 · Enero hasta ${nombreMesCorto(ahora.month)}'),
              const SizedBox(height: 12),
              _cardGrafica(LineasCategoriaChart(datos: evolucionGastos, maxMeses: ahora.month)),
              const SizedBox(height: 25),
              const Text('Distribución de gastos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Periodo: $periodoDistribucion'),
              const SizedBox(height: 10),
              _selectorPeriodo(),
              const SizedBox(height: 12),
              _cardGrafica(PieCategoriasChart(datos: porCategoria('Gasto'))),
            ],
            if (modo == 'Ingresos') ...[
              const Text('Evolución de ingresos por categoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('2026 · Enero hasta ${nombreMesCorto(ahora.month)}'),
              const SizedBox(height: 12),
              _cardGrafica(LineasCategoriaChart(datos: evolucionIngresos, maxMeses: ahora.month)),
              const SizedBox(height: 25),
              const Text('Distribución de ingresos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Periodo: $periodoDistribucion'),
              const SizedBox(height: 10),
              _selectorPeriodo(),
              const SizedBox(height: 12),
              _cardGrafica(PieCategoriasChart(datos: porCategoria('Ingreso'))),
            ],
            if (modo == 'Total') ...[
              const Text('Gastos vs ingresos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Cada columna se divide por categoría. Toca un segmento para ver qué categoría representa.'),
              const SizedBox(height: 12),
              _cardGrafica(
                TotalApiladoChart(
                  movimientos: widget.movimientos,
                  historicos: widget.historicos,
                  maxMeses: ahora.month,
                  nombresMeses: List.generate(ahora.month, (i) => nombreMesCorto(i + 1)),
                ),
              ),
              const SizedBox(height: 25),
              const Text('Distribución de gastos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _cardGrafica(PieCategoriasChart(datos: gastos)),
              const SizedBox(height: 25),
              const Text('Distribución de ingresos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _cardGrafica(PieCategoriasChart(datos: ingresos)),
            ],
            const SizedBox(height: 32),
            const Text(
              'Patrimonio',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Evolución de tu patrimonio según los recuentos guardados.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _cardGrafica(patrimonioGrafica()),
          ],
        ),
      ),
    );
  }

  Widget patrimonioGrafica() {
    final porMes = <String, Map<String, dynamic>>{};

    for (final p in widget.patrimonios) {
      final f = convertirFecha(p['fecha']?.toString() ?? '');
      if (f.year == 1900 || f.isAfter(DateTime.now())) continue;

      final key = '${f.year}-${f.month.toString().padLeft(2, '0')}';
      final anterior = porMes[key];

      if (anterior == null ||
          convertirFecha(
            anterior['fecha']?.toString() ?? '',
          ).isBefore(f)) {
        porMes[key] = p;
      }
    }

    final lista = porMes.values.toList()
      ..sort(
            (a, b) => convertirFecha(
          a['fecha']?.toString() ?? '',
        ).compareTo(
          convertirFecha(
            b['fecha']?.toString() ?? '',
          ),
        ),
      );

    if (lista.isEmpty) {
      return const Center(
        child: Text('No hay recuentos de patrimonio todavía.'),
      );
    }

    final puntos = lista.map((p) {
      final cuentas = List<Map<String, dynamic>>.from(
        (p['cuentas'] as List? ?? []).map(
              (c) => Map<String, dynamic>.from(c),
        ),
      );

      double suma(bool incluirInvertido) {
        return cuentas
            .where((c) {
          final esInvertido =
              c['nombre']?.toString().toLowerCase() == 'invertido';
          return incluirInvertido || !esInvertido;
        })
            .fold<double>(
          0,
              (t, c) =>
          t + ((c['cantidad'] as num?) ?? 0).toDouble(),
        );
      }

      final disponible = suma(false);
      final total = suma(true);

      return _PuntoPatrimonio(
        fecha: convertirFecha(p['fecha']?.toString() ?? ''),
        disponible: disponible,
        invertido: total - disponible,
      );
    }).toList();

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LeyendaPatrimonio(
              label: 'Saldo disponible',
              color: Colors.blue,
            ),
            SizedBox(width: 18),
            _LeyendaPatrimonio(
              label: 'Patrimonio total',
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: CustomPaint(
            painter: _PatrimonioDosLineasChartPainter(puntos),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _selectorPeriodo() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Semana', label: Text('Semana')),
        ButtonSegment(value: 'Mes', label: Text('Mes')),
        ButtonSegment(value: 'Año', label: Text('Año')),
      ],
      selected: {periodoDistribucion},
      onSelectionChanged: (s) => setState(() => periodoDistribucion = s.first),
    );
  }

  Widget _cardGrafica(Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(height: 330, child: child),
      ),
    );
  }
}

const List<Color> _chartColors = [
  Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
  Colors.teal, Colors.pink, Colors.indigo, Colors.brown, Colors.cyan,
  Colors.amber, Colors.deepPurple,
];

class LineasCategoriaChart extends StatelessWidget {
  final Map<String, List<double>> datos;
  final int maxMeses;

  const LineasCategoriaChart({super.key, required this.datos, required this.maxMeses});

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return const Center(child: Text('No hay datos todavía.'));
    final ordenadas = datos.entries.toList()
      ..sort((a, b) => b.value.fold(0.0, (x, y) => x + y).compareTo(a.value.fold(0.0, (x, y) => x + y)));
    return Column(
      children: [
        Expanded(child: CustomPaint(painter: LineasCategoriaPainter(datos: ordenadas, maxMeses: maxMeses), child: const SizedBox.expand())),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 5,
              children: ordenadas.map((e) {
                final i = ordenadas.indexOf(e);
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: _chartColors[i % _chartColors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(e.key, style: const TextStyle(fontSize: 11)),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class LineasCategoriaPainter extends CustomPainter {
  final List<MapEntry<String, List<double>>> datos;
  final int maxMeses;

  LineasCategoriaPainter({required this.datos, required this.maxMeses});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const bottom = 30.0;
    const top = 10.0;
    final chartWidth = size.width - left - 8;
    final chartHeight = size.height - top - bottom;
    final maxValor = datos.expand((e) => e.value).fold(0.0, (a, b) => b > a ? b : a);
    final escala = maxValor > 0 ? maxValor : 1;
    final gridPaint = Paint()..color = Colors.grey.withOpacity(.25)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - 8, y), gridPaint);
    }
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    for (int mes = 0; mes < maxMeses; mes++) {
      final x = maxMeses == 1 ? left : left + chartWidth * mes / (maxMeses - 1);
      textPainter.text = TextSpan(text: meses[mes], style: const TextStyle(fontSize: 10, color: Colors.grey));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - bottom + 7));
    }
    for (int i = 0; i < datos.length; i++) {
      final paint = Paint()..color = _chartColors[i % _chartColors.length]..style = PaintingStyle.stroke..strokeWidth = 2.5;
      final path = Path();
      for (int mes = 0; mes < maxMeses; mes++) {
        final valor = mes < datos[i].value.length ? datos[i].value[mes] : 0;
        final x = maxMeses == 1 ? left : left + chartWidth * mes / (maxMeses - 1);
        final y = top + chartHeight - (valor / escala) * chartHeight;
        if (mes == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LineasCategoriaPainter oldDelegate) => true;
}

class PieCategoriasChart extends StatelessWidget {
  final Map<String, double> datos;
  const PieCategoriasChart({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return const Center(child: Text('No hay datos todavía.'));
    final ordenadas = datos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = datos.values.fold(0.0, (a, b) => a + b);
    return Row(
      children: [
        Expanded(flex: 5, child: CustomPaint(painter: PieCategoriasPainter(datos: ordenadas), child: const SizedBox.expand())),
        Expanded(
          flex: 5,
          child: ListView.builder(
            itemCount: ordenadas.length,
            itemBuilder: (_, i) {
              final porcentaje = total > 0 ? ordenadas[i].value / total * 100 : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _chartColors[i % _chartColors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(ordenadas[i].key, overflow: TextOverflow.ellipsis)),
                  Text('${porcentaje.toStringAsFixed(1)}%'),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PieCategoriasPainter extends CustomPainter {
  final List<MapEntry<String, double>> datos;
  PieCategoriasPainter({required this.datos});

  @override
  void paint(Canvas canvas, Size size) {
    final total = datos.fold(0.0, (a, b) => a + b.value);
    if (total <= 0) return;
    final radio = (size.shortestSide * .38).clamp(40.0, 105.0);
    final centro = Offset(size.width / 2, size.height / 2);
    double inicio = -math.pi / 2;
    for (int i = 0; i < datos.length; i++) {
      final barrido = datos[i].value / total * math.pi * 2;
      final paint = Paint()..color = _chartColors[i % _chartColors.length]..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: centro, radius: radio), inicio, barrido, true, paint);
      inicio += barrido;
    }
    final holePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(centro, radio * .48, holePaint);
  }

  @override
  bool shouldRepaint(covariant PieCategoriasPainter oldDelegate) => true;
}

class TotalApiladoChart extends StatefulWidget {
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> historicos;
  final int maxMeses;
  final List<String> nombresMeses;

  const TotalApiladoChart({
    super.key,
    required this.movimientos,
    required this.historicos,
    required this.maxMeses,
    required this.nombresMeses,
  });

  @override
  State<TotalApiladoChart> createState() => _TotalApiladoChartState();
}

class _TotalApiladoChartState extends State<TotalApiladoChart> {
  String? seleccionado;

  Map<String, List<Map<String, double>>> datosPorTipo(String tipo) {
    final ahora = DateTime.now();
    final resultado = List<Map<String, double>>.generate(widget.maxMeses, (_) => {});
    for (final m in widget.movimientos) {
      if (m['tipo'] != tipo) continue;
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      if (fecha.year != ahora.year || fecha.isAfter(ahora)) continue;
      final categoria = m['categoria']?.toString() ?? 'Miscelánea';
      final mapa = resultado[fecha.month - 1];
      mapa[categoria] = (mapa[categoria] ?? 0) + ((m['cantidad'] as num?) ?? 0).toDouble();
    }
    return {'$tipo': resultado};
  }

  @override
  Widget build(BuildContext context) {
    final gastos = datosPorTipo('Gasto')['Gasto']!;
    final ingresos = datosPorTipo('Ingreso')['Ingreso']!;
    final todos = <String>{};
    for (final mapa in [...gastos, ...ingresos]) todos.addAll(mapa.keys);
    final maxTotal = List.generate(widget.maxMeses, (i) {
      final g = gastos[i].values.fold(0.0, (a, b) => a + b);
      final ing = ingresos[i].values.fold(0.0, (a, b) => a + b);
      return math.max(g, ing);
    }).fold(0.0, (a, b) => b > a ? b : a);

    if (maxTotal <= 0) return const Center(child: Text('No hay datos todavía.'));

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  final ancho = constraints.maxWidth;
                  final left = 8.0;
                  final usable = ancho - left - 8;
                  final paso = usable / widget.maxMeses;
                  final mes = ((details.localPosition.dx - left) / paso).floor();
                  if (mes < 0 || mes >= widget.maxMeses) return;
                  final maxH = constraints.maxHeight - 38;
                  final alturaCol = maxH;
                  final baseY = maxH;
                  final valorG = gastos[mes].values.fold(0.0, (a,b)=>a+b);
                  final valorI = ingresos[mes].values.fold(0.0, (a,b)=>a+b);
                  final xDentro = (details.localPosition.dx - left) % paso;
                  final mitad = paso / 2;
                  final tipo = xDentro < mitad ? 'Gasto' : 'Ingreso';
                  final mapa = tipo == 'Gasto' ? gastos[mes] : ingresos[mes];
                  final total = tipo == 'Gasto' ? valorG : valorI;
                  if (total <= 0) return;
                  final y = details.localPosition.dy;
                  final desdeAbajo = baseY - y;
                  final valorTocado = desdeAbajo / alturaCol * maxTotal;
                  double acumulado = 0;
                  for (final e in mapa.entries) {
                    acumulado += e.value;
                    if (valorTocado <= acumulado) {
                      setState(() => seleccionado = '$tipo · ${e.key} · ${e.value.toStringAsFixed(2)} €');
                      return;
                    }
                  }
                },
                child: CustomPaint(
                  painter: TotalApiladoPainter(
                    gastos: gastos,
                    ingresos: ingresos,
                    nombresMeses: widget.nombresMeses,
                    maxTotal: maxTotal,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        if (seleccionado != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(seleccionado!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 8),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _LeyendaTipo(color: Colors.red, texto: 'Gastos'),
            _LeyendaTipo(color: Colors.green, texto: 'Ingresos'),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 45,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: todos.toList().asMap().entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: _chartColors[e.key % _chartColors.length], shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(e.value, style: const TextStyle(fontSize: 10)),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class TotalApiladoPainter extends CustomPainter {
  final List<Map<String, double>> gastos;
  final List<Map<String, double>> ingresos;
  final List<String> nombresMeses;
  final double maxTotal;

  TotalApiladoPainter({required this.gastos, required this.ingresos, required this.nombresMeses, required this.maxTotal});

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 28.0;
    const top = 8.0;
    final chartHeight = size.height - top - bottom;
    final anchoMes = size.width / nombresMeses.length;
    final barWidth = math.min(24.0, anchoMes * .30);
    final claves = <String>{};
    for (final m in [...gastos, ...ingresos]) claves.addAll(m.keys);
    final ordenCategorias = claves.toList();

    final grid = Paint()..color = Colors.grey.withOpacity(.25)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (int i = 0; i < nombresMeses.length; i++) {
      final centro = anchoMes * i + anchoMes / 2;
      _pintaColumna(canvas, gastos[i], centro - barWidth * .65, barWidth, chartHeight, top, ordenCategorias);
      _pintaColumna(canvas, ingresos[i], centro + barWidth * .05, barWidth, chartHeight, top, ordenCategorias);
      final tp = TextPainter(text: TextSpan(text: nombresMeses[i], style: const TextStyle(fontSize: 9, color: Colors.grey)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(centro - tp.width / 2, size.height - bottom + 5));
    }
  }

  void _pintaColumna(Canvas canvas, Map<String, double> mapa, double x, double width, double chartHeight, double top, List<String> categorias) {
    final total = mapa.values.fold(0.0, (a,b)=>a+b);
    if (total <= 0) return;
    double y = top + chartHeight;
    for (final categoria in categorias) {
      final valor = mapa[categoria] ?? 0;
      if (valor <= 0) continue;
      final h = valor / maxTotal * chartHeight;
      y -= h;
      final paint = Paint()..color = _chartColors[categorias.indexOf(categoria) % _chartColors.length];
      canvas.drawRect(Rect.fromLTWH(x, y, width, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TotalApiladoPainter oldDelegate) => true;
}

class _LeyendaTipo extends StatelessWidget {
  final Color color;
  final String texto;
  const _LeyendaTipo({required this.color, required this.texto});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(texto, style: const TextStyle(fontSize: 12)),
  ]);
}

// ============================================================
// AJUSTES
// ============================================================

class Ajustes
    extends StatefulWidget {
  final List<Map<String, dynamic>>
  categoriasGastos;

  final List<Map<String, dynamic>>
  categoriasIngresos;

  final List<Map<String, dynamic>> movimientos;

  final Future<void> Function()
  onCategoriasChanged;

  final Future<void> Function() onExportarDatos;
  final Future<void> Function() onExportarExcel;
  final Future<void> Function() onImportarDatos;
  final String? googleUsuario;
  final bool googleSincronizando;
  final Future<void> Function() onGoogleConectar;
  final Future<void> Function() onGoogleDesconectar;
  final Future<void> Function() onGoogleSincronizar;
  final Future<void> Function() onGoogleRestaurar;
  final List<Map<String, dynamic>> historicos;
  final Future<void> Function() onHistoricosChanged;
  final bool modoOscuro;
  final Future<void> Function(bool) onModoOscuroChanged;

  const Ajustes({
    super.key,
    required this.categoriasGastos,
    required this.categoriasIngresos,
    required this.movimientos,
    required this.onCategoriasChanged,
    required this.onExportarDatos,
    required this.onExportarExcel,
    required this.onImportarDatos,
    required this.googleUsuario,
    required this.googleSincronizando,
    required this.onGoogleConectar,
    required this.onGoogleDesconectar,
    required this.onGoogleSincronizar,
    required this.onGoogleRestaurar,
    required this.historicos,
    required this.onHistoricosChanged,
    required this.modoOscuro,
    required this.onModoOscuroChanged,
  });

  @override
  State<Ajustes> createState() =>
      _AjustesState();
}

class _AjustesState
    extends State<Ajustes> {
  Future<void>
  editarCategoria(
      List<Map<String, dynamic>>
      lista,
      int indice,
      ) async {
    final categoria =
    lista[indice];

    final nombreController =
    TextEditingController(
      text:
      categoria['nombre']
          ?.toString(),
    );

    final emojiController =
    TextEditingController(
      text:
      categoria['emoji']
          ?.toString(),
    );

    final resultado =
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title:
            const Text(
              'Editar categoría',
            ),
            content:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                TextField(
                  controller:
                  nombreController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Nombre',
                  ),
                ),
                TextField(
                  controller:
                  emojiController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Emoji',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),
                child:
                const Text(
                  'Cancelar',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nombreController
                      .text
                      .trim()
                      .isEmpty) {
                    return;
                  }

                  categoria[
                  'nombre'] =
                      nombreController
                          .text
                          .trim();

                  categoria[
                  'emoji'] =
                      emojiController
                          .text
                          .trim();

                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child:
                const Text(
                  'Guardar',
                ),
              ),
            ],
          ),
    );

    nombreController.dispose();
    emojiController.dispose();

    if (resultado ==
        true) {
      await widget
          .onCategoriasChanged();

      setState(() {});
    }
  }

  Future<void>
  anadirCategoria(
      List<Map<String, dynamic>>
      lista,
      ) async {
    final nombreController =
    TextEditingController();

    final emojiController =
    TextEditingController();

    final resultado =
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title:
            const Text(
              'Nueva categoría',
            ),
            content:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                TextField(
                  controller:
                  nombreController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Nombre',
                  ),
                ),
                TextField(
                  controller:
                  emojiController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Emoji',
                    hintText:
                    'Ejemplo: 🍕',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),
                child:
                const Text(
                  'Cancelar',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final nombre =
                  nombreController
                      .text
                      .trim();

                  if (nombre.isEmpty) {
                    return;
                  }

                  lista.add({
                    'nombre':
                    nombre,
                    'emoji':
                    emojiController
                        .text
                        .trim()
                        .isEmpty
                        ? '📦'
                        : emojiController
                        .text
                        .trim(),
                    'subcategorias':
                    <String>[],
                    'archivada':
                    false,
                  });

                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child:
                const Text(
                  'Añadir',
                ),
              ),
            ],
          ),
    );

    nombreController.dispose();
    emojiController.dispose();

    if (resultado ==
        true) {
      await widget
          .onCategoriasChanged();

      setState(() {});
    }
  }

  // ==========================================================
  // SUBCATEGORÍAS EN AJUSTES
  // ==========================================================

  Future<void> gestionarSubcategorias(
      Map<String, dynamic> categoria,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GestionSubcategoriasPage(
          categoria: categoria,
          onChanged: widget.onCategoriasChanged,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  // ==========================================================
  // ARCHIVAR
  // ==========================================================

  Future<void>
  archivarCategoria(
      List<Map<String, dynamic>>
      lista,
      int indice,
      ) async {
    final categoria =
    lista[indice];

    final confirmar =
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title:
            const Text(
              'Archivar categoría',
            ),
            content:
            Text(
              '¿Quieres archivar "${categoria['nombre']}"? Dejará de aparecer para nuevos movimientos, pero se conservará el histórico.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),
                child:
                const Text(
                  'Cancelar',
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      true,
                    ),
                child:
                const Text(
                  'Archivar',
                ),
              ),
            ],
          ),
    );

    if (confirmar ==
        true) {
      setState(() {
        categoria[
        'archivada'] =
        true;
      });

      await widget
          .onCategoriasChanged();
    }
  }

  // ==========================================================
  // LISTA CATEGORÍAS
  // ==========================================================

  Widget listaCategorias(
      String titulo,
      List<Map<String, dynamic>>
      lista,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child:
              Text(
                titulo,
                style:
                const TextStyle(
                  fontSize:
                  21,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  () =>
                  anadirCategoria(
                    lista,
                  ),
              icon:
              const Icon(
                Icons.add,
              ),
            ),
          ],
        ),

        ...List.generate(
          lista.length,
              (index) {
            final categoria =
            lista[index];

            if (categoria[
            'archivada'] ==
                true) {
              return const SizedBox();
            }

            final sub =
            List<String>.from(
              categoria[
              'subcategorias'] ??
                  [],
            );

            return Card(
              child:
              ListTile(
                leading:
                CircleAvatar(
                  backgroundColor: const Color(0xFFF1F1F1),
                  child: Text(
                    categoria['emoji'] ?? '📦',
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
                title:
                Text(
                  categoria[
                  'nombre'] ??
                      '',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                subtitle:
                Text(
                  '${sub.length} subcategoría${sub.length == 1 ? '' : 's'}',
                ),
                trailing:
                PopupMenuButton<
                    String>(
                  onSelected:
                      (opcion) async {
                    if (opcion ==
                        'editar') {
                      await editarCategoria(
                        lista,
                        index,
                      );
                    }

                    if (opcion ==
                        'subcategorias') {
                      await gestionarSubcategorias(
                        categoria,
                      );
                    }

                  },
                  itemBuilder:
                      (_) => const [
                    PopupMenuItem(
                      value:
                      'editar',
                      child:
                      Text(
                        'Editar nombre / emoji',
                      ),
                    ),
                    PopupMenuItem(
                      value:
                      'subcategorias',
                      child:
                      Text(
                        'Subcategorías',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================================
  // BUILD AJUSTES
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Ajustes',
        ),
      ),
      body:
      ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Datos',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  widget.googleUsuario == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                ),
              ),
              title: Text(
                widget.googleUsuario == null
                    ? 'Conectar con Google'
                    : 'Google conectado',
              ),
              subtitle: Text(
                widget.googleUsuario == null
                    ? 'Sincroniza tus datos entre dispositivos'
                    : '${widget.googleUsuario!} · Sincronización automática',
              ),
              trailing: widget.googleSincronizando
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.chevron_right),
              onTap: widget.googleSincronizando
                  ? null
                  : () async {
                if (widget.googleUsuario == null) {
                  await widget.onGoogleConectar();
                } else {
                  await showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                              leading: Icon(Icons.sync),
                              title: Text('Sincronización automática activa'),
                              subtitle: Text('Los cambios se guardan y actualizan automáticamente.'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.link_off),
                              title: const Text('Desconectar Google'),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await widget.onGoogleDesconectar();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 25),

          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Exportar copia de seguridad'),
              subtitle: const Text('Guarda todos tus datos en un archivo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onExportarDatos,
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Exportar a Excel'),
              subtitle: const Text('Todos los movimientos y ajustes en .xlsx'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onExportarExcel,
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restaurar copia de seguridad'),
              subtitle: const Text('Importa un archivo JSON guardado anteriormente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onImportarDatos,
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Apariencia',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Modo oscuro'),
              subtitle: const Text('Cambia el aspecto de la aplicación'),
              value: widget.modoOscuro,
              onChanged: (valor) async {
                await widget.onModoOscuroChanged(valor);
                if (mounted) setState(() {});
              },
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Categorías',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                child: Icon(Icons.arrow_downward),
              ),
              title: const Text('Editar gastos'),
              subtitle: const Text('Categorías y subcategorías de gastos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GestionCategoriasPage(
                    titulo: 'Editar gastos',
                    lista: widget.categoriasGastos,
                    movimientos: widget.movimientos,
                    onChanged: widget.onCategoriasChanged,
                  ),
                ),
              ).then((_) { if (mounted) setState(() {}); }),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                child: Icon(Icons.arrow_upward),
              ),
              title: const Text('Editar ingresos'),
              subtitle: const Text('Categorías y subcategorías de ingresos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GestionCategoriasPage(
                    titulo: 'Editar ingresos',
                    lista: widget.categoriasIngresos,
                    movimientos: widget.movimientos,
                    onChanged: widget.onCategoriasChanged,
                  ),
                ),
              ).then((_) { if (mounted) setState(() {}); }),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// HISTÓRICO RESUMIDO
// ============================================================

class HistoricoPage extends StatefulWidget {
  final List<Map<String, dynamic>> historicos;
  final Future<void> Function() onChanged;
  const HistoricoPage({super.key, required this.historicos, required this.onChanged});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  final meses = const ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

  Map<String, dynamic> datosMes(int mes) {
    return widget.historicos.firstWhere(
          (h) => (h['anio'] as num?)?.toInt() == DateTime.now().year && (h['mes'] as num?)?.toInt() == mes,
      orElse: () => {'anio': DateTime.now().year, 'mes': mes, 'salario': 0.0, 'pieris': 0.0, 'hipoteca': 0.0, 'alquiler': 0.0, 'gastosTotalesHistorico': 0.0},
    );
  }

  Future<void> editarMes(int mes) async {
    final h = Map<String, dynamic>.from(datosMes(mes));
    final controllers = <String, TextEditingController>{
      'salario': TextEditingController(text: ((h['salario'] as num?) ?? 0).toString()),
      'pieris': TextEditingController(text: ((h['pieris'] as num?) ?? 0).toString()),
      'hipoteca': TextEditingController(text: ((h['hipoteca'] as num?) ?? 0).toString()),
      'alquiler': TextEditingController(text: ((h['alquiler'] as num?) ?? 0).toString()),
      'gastosTotalesHistorico': TextEditingController(text: ((h['gastosTotalesHistorico'] as num?) ?? 0).toString()),
    };
    final guardar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(meses[mes - 1]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _campo(controllers['salario']!, 'Salario'),
            _campo(controllers['pieris']!, 'Pieris'),
            const Divider(),
            _campo(controllers['hipoteca']!, 'Hipoteca'),
            _campo(controllers['alquiler']!, 'Alquiler'),
            _campo(controllers['gastosTotalesHistorico']!, 'Gastos totales histórico'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (guardar == true) {
      double n(String key) => double.tryParse(controllers[key]!.text.replaceAll(',', '.')) ?? 0;
      final nuevo = {'anio': DateTime.now().year, 'mes': mes, 'salario': n('salario'), 'pieris': n('pieris'), 'hipoteca': n('hipoteca'), 'alquiler': n('alquiler'), 'gastosTotalesHistorico': n('gastosTotalesHistorico')};
      widget.historicos.removeWhere((x) => (x['anio'] as num?)?.toInt() == DateTime.now().year && (x['mes'] as num?)?.toInt() == mes);
      if (nuevo.values.any((v) => v is num && v != 0)) widget.historicos.add(nuevo);
      await widget.onChanged();
      if (mounted) setState(() {});
    }
    for (final c in controllers.values) c.dispose();
  }

  Widget _campo(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, suffixText: '€', border: const OutlineInputBorder())));

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('Histórico ${ahora.year}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ahora.month,
        itemBuilder: (_, i) {
          final mes = i + 1;
          final h = datosMes(mes);
          final ingresos = ((h['salario'] as num?) ?? 0).toDouble() + ((h['pieris'] as num?) ?? 0).toDouble();
          final gastos = ((h['hipoteca'] as num?) ?? 0).toDouble() + ((h['alquiler'] as num?) ?? 0).toDouble() + ((h['gastosTotalesHistorico'] as num?) ?? 0).toDouble();
          return Card(child: ListTile(
            leading: CircleAvatar(child: Text('${mes.toString().padLeft(2, '0')}')),
            title: Text(meses[i], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Ingresos ${formatearEuros(ingresos)} · Gastos ${formatearEuros(gastos)}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => editarMes(mes),
          ));
        },
      ),
    );
  }
}

// ============================================================
// GESTIÓN DE CATEGORÍAS
// ============================================================

class GestionCategoriasPage extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> lista;
  final List<Map<String, dynamic>> movimientos;
  final Future<void> Function() onChanged;

  const GestionCategoriasPage({
    super.key,
    required this.titulo,
    required this.lista,
    required this.movimientos,
    required this.onChanged,
  });

  @override
  State<GestionCategoriasPage> createState() => _GestionCategoriasPageState();
}

class _GestionCategoriasPageState extends State<GestionCategoriasPage> {
  Future<void> editarCategoria(int index) async {
    final categoria = widget.lista[index];
    final nombreController = TextEditingController(text: categoria['nombre']?.toString() ?? '');
    final emojiController = TextEditingController(text: categoria['emoji']?.toString() ?? '📦');

    final guardar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: emojiController, decoration: const InputDecoration(labelText: 'Emoji')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (guardar == true && nombreController.text.trim().isNotEmpty) {
      categoria['nombre'] = nombreController.text.trim();
      categoria['emoji'] = emojiController.text.trim().isEmpty ? '📦' : emojiController.text.trim();
      await widget.onChanged();
      if (mounted) setState(() {});
    }
    nombreController.dispose();
    emojiController.dispose();
  }

  Future<void> anadirCategoria() async {
    final nombreController = TextEditingController();
    final emojiController = TextEditingController();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: emojiController, decoration: const InputDecoration(labelText: 'Emoji', hintText: 'Ejemplo: 🍕')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Añadir')),
        ],
      ),
    );
    if (guardar == true && nombreController.text.trim().isNotEmpty) {
      widget.lista.add({
        'nombre': nombreController.text.trim(),
        'emoji': emojiController.text.trim().isEmpty ? '📦' : emojiController.text.trim(),
        'subcategorias': <String>[],
        'archivada': false,
        'ocultaAlAnadir': false,
      });
      await widget.onChanged();
      if (mounted) setState(() {});
    }
    nombreController.dispose();
    emojiController.dispose();
  }

  Future<void> eliminarCategoria(int index) async {
    final categoria = widget.lista[index];
    final nombre = categoria['nombre']?.toString() ?? '';
    final registros = widget.movimientos.where(
          (m) => m['tipo'] != 'Ajuste' && m['categoria']?.toString() == nombre,
    ).toList();

    String ejemplo(Map<String, dynamic> m) {
      final tipo = m['tipo']?.toString() ?? '';
      final fecha = m['fecha']?.toString() ?? '';
      final importe = ((m['cantidad'] as num?) ?? 0).toDouble();
      final sub = m['subcategoria']?.toString();
      final detalle = sub != null && sub.trim().isNotEmpty ? ' · $sub' : '';
      return '${tipo == 'Gasto' ? '-' : '+'}${importe.toStringAsFixed(2)} € · $fecha$detalle';
    }

    final ejemplos = registros.take(5).map(ejemplo).toList();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Seguro que quieres borrar "$nombre"? Esta acción no se puede deshacer.'),
              const SizedBox(height: 12),
              Text(
                registros.isEmpty
                    ? 'No hay movimientos registrados en esta categoría.'
                    : 'También se borrarán ${registros.length} registro${registros.length == 1 ? '' : 's'} de esta categoría.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ejemplos.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Ejemplos de registros que se borrarían:'),
                const SizedBox(height: 5),
                ...ejemplos.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $e'),
                )),
                if (registros.length > ejemplos.length)
                  Text('• … y ${registros.length - ejemplos.length} más'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    widget.movimientos.removeWhere(
          (m) => m['tipo'] != 'Ajuste' && m['categoria']?.toString() == nombre,
    );
    widget.lista.removeAt(index);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> cambiarOcultarAlAnadir(int index, bool valor) async {
    widget.lista[index]['ocultaAlAnadir'] = valor;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activas = <Map<String, dynamic>>[];
    for (final categoria in widget.lista) {
      if (categoria['archivada'] != true) activas.add(categoria);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [IconButton(onPressed: anadirCategoria, icon: const Icon(Icons.add))],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: activas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final categoria = activas[index];
          final originalIndex = widget.lista.indexOf(categoria);
          final subs = List<String>.from(categoria['subcategorias'] ?? []);
          return Card(
            child: ListTile(
              leading: Text(categoria['emoji'] ?? '📦', style: const TextStyle(fontSize: 28)),
              title: Text(categoria['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${subs.length} subcategoría${subs.length == 1 ? '' : 's'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Mostrar al añadir movimientos',
                    child: Switch(
                      value: categoria['ocultaAlAnadir'] != true,
                      onChanged: (mostrar) => cambiarOcultarAlAnadir(originalIndex, !mostrar),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (opcion) async {
                      if (opcion == 'editar') await editarCategoria(originalIndex);
                      if (opcion == 'sub') {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => GestionSubcategoriasPage(categoria: categoria, onChanged: widget.onChanged)));
                        if (mounted) setState(() {});
                      }
                      if (opcion == 'borrar') await eliminarCategoria(originalIndex);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar nombre / emoji')),
                      PopupMenuItem(value: 'sub', child: Text('Subcategorías')),
                      PopupMenuItem(value: 'borrar', child: Text('Borrar categoría')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// NUEVA SUBCATEGORÍA
// ============================================================

class NuevaSubcategoriaPage extends StatefulWidget {
  const NuevaSubcategoriaPage({super.key});

  @override
  State<NuevaSubcategoriaPage> createState() => _NuevaSubcategoriaPageState();
}

class _NuevaSubcategoriaPageState extends State<NuevaSubcategoriaPage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void guardar() {
    final nombre = controller.text.trim();
    if (nombre.isEmpty) return;
    Navigator.pop(context, nombre);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva subcategoría')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => guardar(),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ejemplo: Gym',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: guardar,
                child: const Text('Añadir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GESTIÓN DE SUBCATEGORÍAS
// ============================================================

class GestionSubcategoriasPage extends StatefulWidget {
  final Map<String, dynamic> categoria;
  final Future<void> Function() onChanged;

  const GestionSubcategoriasPage({
    super.key,
    required this.categoria,
    required this.onChanged,
  });

  @override
  State<GestionSubcategoriasPage> createState() => _GestionSubcategoriasPageState();
}

class _GestionSubcategoriasPageState extends State<GestionSubcategoriasPage> {
  late List<String> subcategorias;

  @override
  void initState() {
    super.initState();
    subcategorias = List<String>.from(widget.categoria['subcategorias'] ?? []);
  }

  Future<void> anadir() async {
    final nombre = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const NuevaSubcategoriaPage()),
    );

    if (nombre == null || nombre.trim().isEmpty) return;
    final texto = nombre.trim();
    if (subcategorias.contains(texto)) return;

    setState(() {
      subcategorias.add(texto);
      if (!subcategorias.contains('Otros')) subcategorias.add('Otros');
      widget.categoria['subcategorias'] = subcategorias;
    });
    await widget.onChanged();
  }

  Future<void> eliminar(int index) async {
    setState(() {
      subcategorias.removeAt(index);
      widget.categoria['subcategorias'] = subcategorias;
    });
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoria['emoji'] ?? '📦'} ${widget.categoria['nombre'] ?? ''}'),
        actions: [
          IconButton(onPressed: anadir, icon: const Icon(Icons.add)),
        ],
      ),
      body: subcategorias.isEmpty
          ? const Center(child: Text('No hay subcategorías todavía.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: subcategorias.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(subcategorias[index]),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => eliminar(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: anadir,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// PATRIMONIO
// ============================================================

class _PuntoPatrimonio {
  final DateTime fecha;
  final double disponible;
  final double invertido;

  const _PuntoPatrimonio({
    required this.fecha,
    required this.disponible,
    required this.invertido,
  });

  double get total => disponible + invertido;
}

class _LeyendaPatrimonio extends StatelessWidget {
  final String label;
  final Color color;

  const _LeyendaPatrimonio({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _PatrimonioDosLineasChartPainter extends CustomPainter {
  final List<_PuntoPatrimonio> puntos;

  _PatrimonioDosLineasChartPainter(this.puntos);

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.isEmpty) return;

    const left = 48.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 30.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final maxValor = puntos
        .map((p) => math.max(p.disponible, p.total).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    final escala = maxValor <= 0 ? 1.0 : maxValor;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(.18)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(.35)
      ..strokeWidth = 1;

    final disponiblePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final totalPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final valor = escala * (4 - i) / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: valor.round().toString(),
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    Offset punto(int index, double valor) {
      final x = puntos.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (puntos.length - 1);
      final y = top + chartHeight * (1 - valor / escala);
      return Offset(x, y);
    }

    void dibujarLinea(List<double> valores, Paint paint) {
      final path = Path();

      for (var i = 0; i < valores.length; i++) {
        final p = punto(i, valores[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      canvas.drawPath(path, paint);

      final puntoPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill;

      for (final entrada in valores.asMap().entries) {
        canvas.drawCircle(
          punto(entrada.key, entrada.value),
          4,
          puntoPaint,
        );
      }
    }

    dibujarLinea(
      puntos.map((p) => p.disponible).toList(),
      disponiblePaint,
    );
    dibujarLinea(
      puntos.map((p) => p.total).toList(),
      totalPaint,
    );

    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

    final paso = puntos.length <= 6 ? 1 : (puntos.length / 6).ceil();

    for (var i = 0; i < puntos.length; i += paso) {
      final offset = punto(i, 0);
      final fecha = puntos[i].fecha;

      final tp = TextPainter(
        text: TextSpan(
          text: '${meses[fecha.month - 1]} ${fecha.year}',
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          offset.dx - tp.width / 2,
          top + chartHeight + 7,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _PatrimonioDosLineasChartPainter oldDelegate,
      ) {
    return oldDelegate.puntos != puntos;
  }
}

class _PatrimonioChartPainter extends CustomPainter {
  final List<_PuntoPatrimonio> puntos;

  _PatrimonioChartPainter(this.puntos);

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.isEmpty) return;

    const left = 48.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 28.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final maxValor = puntos
        .map(
          (p) => math.max(
        p.disponible,
        math.max(p.invertido, p.total),
      ).toDouble(),
    )
        .fold<double>(
      0.0,
          (a, b) => a > b ? a : b,
    );

    final escala = maxValor <= 0 ? 1.0 : maxValor;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(.18)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(.35)
      ..strokeWidth = 1;

    final disponiblePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final invertidoPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final totalPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final valor = escala * (4 - i) / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: valor.round().toString(),
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    Offset punto(int index, double valor) {
      final x = puntos.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (puntos.length - 1);
      final y = top + chartHeight * (1 - valor / escala);
      return Offset(x, y);
    }

    void dibujarLinea(List<double> valores, Paint paint) {
      final path = Path();

      for (var i = 0; i < valores.length; i++) {
        final p = punto(i, valores[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      canvas.drawPath(path, paint);

      final puntoPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill;

      for (final entrada in valores.asMap().entries) {
        canvas.drawCircle(
          punto(entrada.key, entrada.value),
          4,
          puntoPaint,
        );
      }
    }

    dibujarLinea(
      puntos.map((p) => p.disponible).toList(),
      disponiblePaint,
    );
    dibujarLinea(
      puntos.map((p) => p.invertido).toList(),
      invertidoPaint,
    );
    dibujarLinea(
      puntos.map((p) => p.total).toList(),
      totalPaint,
    );

    final paso = puntos.length <= 6
        ? 1
        : (puntos.length / 6).ceil();

    for (var i = 0; i < puntos.length; i += paso) {
      final offset = punto(i, 0);
      final fecha = puntos[i].fecha;

      final tp = TextPainter(
        text: TextSpan(
          text:
          '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}',
          style: const TextStyle(
            fontSize: 8,
            color: Colors.grey,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          offset.dx - tp.width / 2,
          top + chartHeight + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _PatrimonioChartPainter oldDelegate,
      ) {
    return oldDelegate.puntos != puntos;
  }
}

class PatrimonioPage extends StatefulWidget {
  final List<Map<String, dynamic>> patrimonios;
  final List<Map<String, String>> categorias;
  final Future<void> Function(Map<String, dynamic>) onGuardar;
  final Future<void> Function(List<Map<String, String>>) onCategoriasChanged;

  const PatrimonioPage({super.key, required this.patrimonios, required this.categorias, required this.onGuardar, required this.onCategoriasChanged});

  @override
  State<PatrimonioPage> createState() => _PatrimonioPageState();
}

class _PatrimonioPageState extends State<PatrimonioPage> {
  late DateTime fecha;
  late List<Map<String, String>> categorias;
  final Map<String, TextEditingController> controllers = {};
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    fecha = DateTime.now();
    categorias = widget.categorias.map((e) => Map<String, String>.from(e)).toList();
    _crearControllers();
  }

  Map<String, dynamic>? get ultimo {
    if (widget.patrimonios.isEmpty) return null;
    final lista = List<Map<String, dynamic>>.from(widget.patrimonios);
    lista.sort((a, b) => convertirFecha(b['fecha']?.toString() ?? '').compareTo(convertirFecha(a['fecha']?.toString() ?? '')));
    return lista.first;
  }

  void _crearControllers() {
    final cuentas = List.from(ultimo?['cuentas'] ?? []);
    for (final categoria in categorias) {
      final nombre = categoria['nombre'] ?? '';
      Map<String, dynamic>? cuenta;
      for (final c in cuentas) {
        if (c['nombre']?.toString() == nombre) {
          cuenta = Map<String, dynamic>.from(c);
          break;
        }
      }
      final cantidad = ((cuenta?['cantidad'] as num?) ?? 0).toDouble();
      controllers[nombre] = TextEditingController(text: cantidad == 0 ? '' : cantidad.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    super.dispose();
  }

  double cantidad(String nombre) => double.tryParse((controllers[nombre]?.text ?? '').trim().replaceAll(',', '.')) ?? 0;

  double get total => categorias.fold(0.0, (t, c) => t + cantidad(c['nombre'] ?? ''));

  Future<void> seleccionarFecha() async {
    final d = await showDatePicker(context: context, initialDate: fecha, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (d != null && mounted) setState(() => fecha = d);
  }

  Future<void> guardarRecuento() async {
    if (guardando) return;

    final cuentas = categorias.map((c) {
      final nombre = c['nombre'] ?? '';
      return {
        'nombre': nombre,
        'emoji': c['emoji'] ?? '💰',
        'cantidad': cantidad(nombre),
      };
    }).toList();

    final saldoDisponible = cuentas
        .where(
          (c) => (c['nombre']?.toString() ?? '').toLowerCase() != 'invertido',
    )
        .fold<double>(
      0,
          (t, c) => t + ((c['cantidad'] as num?) ?? 0).toDouble(),
    );
    final invertido = cuentas
        .where(
          (c) => (c['nombre']?.toString() ?? '').toLowerCase() == 'invertido',
    )
        .fold<double>(
      0,
          (t, c) => t + ((c['cantidad'] as num?) ?? 0).toDouble(),
    );
    final totalPatrimonio = saldoDisponible + invertido;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar recuento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${fechaTexto(fecha)}'),
              const SizedBox(height: 10),
              ...cuentas.map(
                    (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Text(c['emoji']?.toString() ?? '💰'),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['nombre']?.toString() ?? '')),
                      Text(
                        formatearEuros(
                          ((c['cantidad'] as num?) ?? 0).toDouble(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 18),
              Text('Saldo disponible: ${formatearEuros(saldoDisponible)}'),
              Text('Invertido: ${formatearEuros(invertido)}'),
              Text(
                'Patrimonio total: ${formatearEuros(totalPatrimonio)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('¿Quieres guardar este recuento?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar y guardar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => guardando = true);
    await widget.onGuardar({
      'id': 'patrimonio_${DateTime.now().microsecondsSinceEpoch}',
      'fecha': fechaTexto(fecha),
      'cuentas': cuentas,
    });
    if (!mounted) return;
    setState(() => guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recuento guardado')),
    );
  }

  Future<void> gestionarCategorias() async {
    final resultado = await Navigator.push<List<Map<String, String>>>(context, MaterialPageRoute(builder: (_) => GestionPatrimonioPage(categorias: categorias)));
    if (resultado == null) return;
    final valores = <String, String>{};
    for (final c in categorias) {
      final n = c['nombre'] ?? '';
      valores[n] = controllers[n]?.text ?? '';
    }
    for (final c in controllers.values) c.dispose();
    controllers.clear();
    categorias = resultado.map((e) => Map<String, String>.from(e)).toList();
    for (final c in categorias) {
      final n = c['nombre'] ?? '';
      controllers[n] = TextEditingController(text: valores[n] ?? '');
    }
    await widget.onCategoriasChanged(categorias);
    if (mounted) setState(() {});
  }

  Widget campo(Map<String, String> c) {
    final nombre = c['nombre'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFFF1F1F1), child: Text(c['emoji'] ?? '💰')),
          const SizedBox(width: 12),
          Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 125, child: TextField(controller: controllers[nombre], keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.right, decoration: const InputDecoration(hintText: '0,00', suffixText: '€', border: InputBorder.none), onChanged: (_) => setState(() {}))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi patrimonio'), actions: [IconButton(onPressed: gestionarCategorias, icon: const Icon(Icons.tune))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nuevo recuento', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Cuenta todo lo que tienes y guárdalo como una foto de tu patrimonio.', style: TextStyle(color: Colors.grey)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined), title: const Text('Fecha del recuento'), subtitle: Text(fechaTexto(fecha)), trailing: const Icon(Icons.chevron_right), onTap: seleccionarFecha),
        ]))),
        const SizedBox(height: 8),
        ...categorias.map(campo),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SALDO DISPONIBLE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatearEuros(
                        categorias
                            .where(
                              (c) =>
                          (c['nombre'] ?? '').toLowerCase() !=
                              'invertido',
                        )
                            .fold<double>(
                          0,
                              (t, c) => t + cantidad(c['nombre'] ?? ''),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'INVERTIDO',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      formatearEuros(
                        categorias
                            .where(
                              (c) =>
                          (c['nombre'] ?? '').toLowerCase() ==
                              'invertido',
                        )
                            .fold<double>(
                          0,
                              (t, c) => t + cantidad(c['nombre'] ?? ''),
                        ),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PATRIMONIO TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatearEuros(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: gestionarCategorias, icon: const Icon(Icons.category_outlined), label: const Text('Editar categorías')),
        const SizedBox(height: 6),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: guardando ? null : guardarRecuento, icon: const Icon(Icons.save_outlined), label: Text(guardando ? 'Guardando...' : 'Guardar recuento'))),
      ]),
    );
  }
}

class GestionPatrimonioPage extends StatefulWidget {
  final List<Map<String, String>> categorias;
  const GestionPatrimonioPage({super.key, required this.categorias});
  @override State<GestionPatrimonioPage> createState() => _GestionPatrimonioPageState();
}

class _GestionPatrimonioPageState extends State<GestionPatrimonioPage> {
  late List<Map<String, String>> categorias;
  @override void initState() { super.initState(); categorias = widget.categorias.map((e) => Map<String, String>.from(e)).toList(); }

  Future<void> editar(int index) async {
    final nombre = TextEditingController(text: categorias[index]['nombre'] ?? '');
    final emoji = TextEditingController(text: categorias[index]['emoji'] ?? '💰');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Editar categoría'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')), TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))]));
    if (ok == true && nombre.text.trim().isNotEmpty) setState(() => categorias[index] = {'nombre': nombre.text.trim(), 'emoji': emoji.text.trim().isEmpty ? '💰' : emoji.text.trim()});
    nombre.dispose(); emoji.dispose();
  }

  Future<void> anadir() async {
    final nombre = TextEditingController(); final emoji = TextEditingController(text: '💰');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Nueva categoría'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nombre, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')), TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Añadir'))]));
    if (ok == true && nombre.text.trim().isNotEmpty && !categorias.any((c) => c['nombre']?.toLowerCase() == nombre.text.trim().toLowerCase())) setState(() => categorias.add({'nombre': nombre.text.trim(), 'emoji': emoji.text.trim().isEmpty ? '💰' : emoji.text.trim()}));
    nombre.dispose(); emoji.dispose();
  }

  Future<void> borrar(int index) async {
    if (categorias.length <= 1) return;
    final nombre = categorias[index]['nombre'] ?? '';
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Borrar categoría'), content: Text('¿Borrar "$nombre" de los próximos recuentos? Los recuentos históricos se conservarán.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(foregroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Borrar'))]));
    if (ok == true) setState(() => categorias.removeAt(index));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Categorías de patrimonio'), actions: [IconButton(onPressed: anadir, icon: const Icon(Icons.add))]),
    body: ListView.separated(padding: const EdgeInsets.all(12), itemCount: categorias.length, separatorBuilder: (_, __) => const SizedBox(height: 5), itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFF1F1F1), child: Text(categorias[i]['emoji'] ?? '💰')), title: Text(categorias[i]['nombre'] ?? ''), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => editar(i), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => borrar(i), icon: const Icon(Icons.delete_outline))])))),
    floatingActionButton: FloatingActionButton(onPressed: anadir, child: const Icon(Icons.add)),
  );
}

// ============================================================
// NUEVA CORRECCIÓN
// ============================================================

class NuevaCorreccionPage extends StatefulWidget {
  const NuevaCorreccionPage({super.key});

  @override
  State<NuevaCorreccionPage> createState() => _NuevaCorreccionPageState();
}

class _NuevaCorreccionPageState extends State<NuevaCorreccionPage> {
  final controller = TextEditingController();
  DateTime fecha = DateTime.now();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> seleccionarFecha() async {
    final nueva = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nueva != null && mounted) {
      setState(() => fecha = nueva);
    }
  }

  void guardar() {
    final valor = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    if (valor == null || valor < 0) return;
    Navigator.pop(
      context,
      {
        'cantidad': valor,
        'fecha': fecha,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar saldo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cuenta todo el dinero que tienes realmente y escríbelo aquí. La aplicación calculará automáticamente el ajuste.'),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => guardar(),
              decoration: const InputDecoration(
                labelText: 'Dinero real que tienes',
                hintText: 'Ejemplo: 20000',
                suffixText: '€',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha del ajuste'),
              subtitle: Text(fechaTexto(fecha)),
              trailing: const Icon(Icons.chevron_right),
              onTap: seleccionarFecha,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: guardar,
                child: const Text('Ajustar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SELECTOR DE MES
// ============================================================

class SelectorMes extends StatefulWidget {
  final DateTime inicial;

  const SelectorMes({
    super.key,
    required this.inicial,
  });

  @override
  State<SelectorMes> createState() => _SelectorMesState();
}

class _SelectorMesState extends State<SelectorMes> {
  late int mes;
  late int ano;

  @override
  void initState() {
    super.initState();
    mes = widget.inicial.month;
    ano = widget.inicial.year;
  }

  @override
  Widget build(BuildContext context) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return AlertDialog(
      title: const Text('Seleccionar mes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      ano--;
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$ano',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      ano++;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: GridView.builder(
                itemCount: 12,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final numeroMes = index + 1;
                  final seleccionado = numeroMes == mes;

                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: seleccionado
                          ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          : null,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        DateTime(ano, numeroMes, 1),
                      );
                    },
                    child: Text(
                      meses[index].substring(0, 3),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
