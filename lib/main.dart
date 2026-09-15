import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class _CancelRecurrenceAction implements Exception {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        title: 'PastApp',
        theme: temaClaro(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PastApp',
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
    'nombre': 'Otros préstamos',
    'emoji': '💶',
    'subcategorias': <String>[],
  },
  {
    'nombre': 'Compra inmuebles',
    'emoji': '🏢',
    'subcategorias': <String>['Amortización hipoteca', 'Compra piso'],
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
    'id': 'cat_gastos_hipotecas',
    'nombre': 'Hipotecas',
    'emoji': '🏦',
    'subcategorias': <String>['Bordador', 'Afán', 'Fco Carrera', 'Otros'],
  },
  {
    'id': 'cat_gastos_pisos',
    'nombre': 'Pisos',
    'emoji': '🏠',
    'subcategorias': <String>['Bordador', 'Afán', 'Fco Carrera', 'Otros'],
    'subcategoriaIds': <String, String>{
      'Bordador': 'sub_pisos_bordador',
      'Afán': 'sub_pisos_afan',
      'Fco Carrera': 'sub_pisos_fco_carrera',
      'Otros': 'sub_pisos_otros',
    },
    'subsubcategorias': <String, List<String>>{
      'Bordador': ['IBI', 'Comunidad', 'Electrodomésticos', 'Seguro hogar', 'Obras', 'Mantenimiento', 'Otros'],
      'Afán': ['IBI', 'Comunidad', 'Electrodomésticos', 'Seguro hogar', 'Obras', 'Mantenimiento', 'Otros'],
      'Fco Carrera': ['IBI', 'Comunidad', 'Electrodomésticos', 'Seguro hogar', 'Obras', 'Mantenimiento', 'Otros'],
      'Otros': ['Seguros'],
    },
    'subsubcategoriaIds': <String, Map<String, String>>{
      'Bordador': {'IBI': 'ss_pisos_bordador_ibi', 'Comunidad': 'ss_pisos_bordador_comunidad', 'Electrodomésticos': 'ss_pisos_bordador_electrodomesticos', 'Seguro hogar': 'ss_pisos_bordador_seguro_hogar', 'Obras': 'ss_pisos_bordador_obras', 'Mantenimiento': 'ss_pisos_bordador_mantenimiento', 'Otros': 'ss_pisos_bordador_otros'},
      'Afán': {'IBI': 'ss_pisos_afan_ibi', 'Comunidad': 'ss_pisos_afan_comunidad', 'Electrodomésticos': 'ss_pisos_afan_electrodomesticos', 'Seguro hogar': 'ss_pisos_afan_seguro_hogar', 'Obras': 'ss_pisos_afan_obras', 'Mantenimiento': 'ss_pisos_afan_mantenimiento', 'Otros': 'ss_pisos_afan_otros'},
      'Fco Carrera': {'IBI': 'ss_pisos_fco_carrera_ibi', 'Comunidad': 'ss_pisos_fco_carrera_comunidad', 'Electrodomésticos': 'ss_pisos_fco_carrera_electrodomesticos', 'Seguro hogar': 'ss_pisos_fco_carrera_seguro_hogar', 'Obras': 'ss_pisos_fco_carrera_obras', 'Mantenimiento': 'ss_pisos_fco_carrera_mantenimiento', 'Otros': 'ss_pisos_fco_carrera_otros'},
      'Otros': {'Seguros': 'ss_pisos_otros_seguros'},
    },
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
    'id': 'cat_ingresos_alquileres',
    'nombre': 'Alquileres',
    'emoji': '🏘️',
    'subcategorias': <String>['Bordador', 'Afán', 'Fco Carrera'],
  },
  {
    'nombre': 'Otros ingresos',
    'emoji': '💰',
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

const List<Map<String, dynamic>> historicosInicialesPastApp = [
  {
    'anio': 2022, 'mes': 1, 'nombreMes': 'Enero',
    'salario': 2077.00, 'pieris': 0.00, 'hipoteca': 715.37, 'alquiler': 0.00,
    'totalIngresos': 3397.00, 'gastosFijos': 1340.58, 'gastosHistoricos': 1566.42, 'totalGastos': 2907.00, 'ahorro': 490.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 490.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 670.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 341.25},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Pisos', 'subcategoria': 'Seguros', 'importe': 261.03, 'nota': 'Seguro de vida'},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 2, 'nombreMes': 'Febrero',
    'salario': 2077.00, 'pieris': 0.00, 'hipoteca': 715.37, 'alquiler': 0.00,
    'totalIngresos': 3717.00, 'gastosFijos': 1079.55, 'gastosHistoricos': 2037.45, 'totalGastos': 3117.00, 'ahorro': 600.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 600.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 341.25},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 3, 'nombreMes': 'Marzo',
    'salario': 2077.00, 'pieris': 0.00, 'hipoteca': 715.37, 'alquiler': 0.00,
    'totalIngresos': 3717.00, 'gastosFijos': 1079.55, 'gastosHistoricos': 1930.45, 'totalGastos': 3010.00, 'ahorro': 707.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 707.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 341.25},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 4, 'nombreMes': 'Abril',
    'salario': 2077.00, 'pieris': 0.00, 'hipoteca': 715.37, 'alquiler': 600.00,
    'totalIngresos': 3717.00, 'gastosFijos': 1679.55, 'gastosHistoricos': 3009.45, 'totalGastos': 4689.00, 'ahorro': -972.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -972.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 341.25},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 5, 'nombreMes': 'Mayo',
    'salario': 2077.00, 'pieris': 450.00, 'hipoteca': 715.37, 'alquiler': 600.00,
    'totalIngresos': 4167.00, 'gastosFijos': 1679.55, 'gastosHistoricos': 4627.45, 'totalGastos': 6307.00, 'ahorro': -2140.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -2140.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 450.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 341.25},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 6, 'nombreMes': 'Junio',
    'salario': 2077.00, 'pieris': 1946.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 5913.00, 'gastosFijos': 2288.01, 'gastosHistoricos': 574.99, 'totalGastos': 2863.00, 'ahorro': 3050.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3050.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1946.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 116.63},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 239.72},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 261.35},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 7, 'nombreMes': 'Julio',
    'salario': 2077.00, 'pieris': 2000.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 5967.00, 'gastosFijos': 1670.31, 'gastosHistoricos': 2326.69, 'totalGastos': 3997.00, 'ahorro': 1970.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 1970.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2000.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 8, 'nombreMes': 'Agosto',
    'salario': 2077.00, 'pieris': 2400.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 6367.00, 'gastosFijos': 1670.31, 'gastosHistoricos': 1401.69, 'totalGastos': 3072.00, 'ahorro': 3295.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3295.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2400.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 9, 'nombreMes': 'Septiembre',
    'salario': 2077.00, 'pieris': 4000.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 7967.00, 'gastosFijos': 1670.31, 'gastosHistoricos': 1461.69, 'totalGastos': 3132.00, 'ahorro': 4835.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 4835.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4000.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 10, 'nombreMes': 'Octubre',
    'salario': 2077.00, 'pieris': 3600.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 7567.00, 'gastosFijos': 1670.31, 'gastosHistoricos': 4510.69, 'totalGastos': 6181.00, 'ahorro': 1386.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 1386.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2077.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3600.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 11, 'nombreMes': 'Noviembre',
    'salario': 3285.00, 'pieris': 1900.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 7075.00, 'gastosFijos': 1670.31, 'gastosHistoricos': 1505.69, 'totalGastos': 3176.00, 'ahorro': 3899.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3899.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3285.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1900.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2022, 'mes': 12, 'nombreMes': 'Diciembre',
    'salario': 2610.00, 'pieris': 2200.00, 'hipoteca': 706.13, 'alquiler': 600.00,
    'totalIngresos': 6700.00, 'gastosFijos': 2175.94, 'gastosHistoricos': 5914.06, 'totalGastos': 8090.00, 'ahorro': -1390.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -1390.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2610.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2200.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 374.12},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 121.23},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 249.18},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Bordador', 'importe': 135.22},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 1, 'nombreMes': 'Enero',
    'salario': 2136.00, 'pieris': 1350.00, 'hipoteca': 705.88, 'alquiler': 600.00,
    'totalIngresos': 5376.00, 'gastosFijos': 1922.84, 'gastosHistoricos': 2594.16, 'totalGastos': 4517.00, 'ahorro': 859.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 859.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1350.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 373.87},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguros', 'importe': 252.78, 'nota': 'Seguro de vida'},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 2, 'nombreMes': 'Febrero',
    'salario': 2136.00, 'pieris': 1670.00, 'hipoteca': 899.05, 'alquiler': 600.00,
    'totalIngresos': 5696.00, 'gastosFijos': 2263.23, 'gastosHistoricos': 2071.77, 'totalGastos': 4335.00, 'ahorro': 1361.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 1361.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1670.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 400.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 3, 'nombreMes': 'Marzo',
    'salario': 2136.00, 'pieris': 3300.00, 'hipoteca': 899.05, 'alquiler': 600.00,
    'totalIngresos': 7326.00, 'gastosFijos': 1863.23, 'gastosHistoricos': 1777.77, 'totalGastos': 3641.00, 'ahorro': 3685.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3685.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3300.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 4, 'nombreMes': 'Abril',
    'salario': 2136.00, 'pieris': 4588.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 8614.00, 'gastosFijos': 4978.23, 'gastosHistoricos': 3285.77, 'totalGastos': 8264.00, 'ahorro': 350.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 350.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 650.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4588.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 465.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 2600.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 5, 'nombreMes': 'Mayo',
    'salario': 2136.00, 'pieris': 4850.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 8926.00, 'gastosFijos': 2214.56, 'gastosHistoricos': 2901.67, 'totalGastos': 5116.23, 'ahorro': 3809.77, 'inversionInmobiliaria': 12139.77, 'ahorroSinInversion': 15949.54,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4850.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 301.33},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 12139.77},
    ],
  },
  {
    'anio': 2023, 'mes': 6, 'nombreMes': 'Junio',
    'salario': 2136.00, 'pieris': 4500.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 8576.00, 'gastosFijos': 2269.58, 'gastosHistoricos': 2618.15, 'totalGastos': 4887.73, 'ahorro': 3688.27, 'inversionInmobiliaria': 2190.64, 'ahorroSinInversion': 5878.91,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4500.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 116.63},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 239.72},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 2190.64},
    ],
  },
  {
    'anio': 2023, 'mes': 7, 'nombreMes': 'Julio',
    'salario': 2136.00, 'pieris': 6870.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 10946.00, 'gastosFijos': 1913.23, 'gastosHistoricos': 3795.40, 'totalGastos': 5708.63, 'ahorro': 5237.37, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 5237.37,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 6870.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 8, 'nombreMes': 'Agosto',
    'salario': 2136.00, 'pieris': 3300.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 7156.00, 'gastosFijos': 1963.23, 'gastosHistoricos': 3164.03, 'totalGastos': 5127.26, 'ahorro': 2028.74, 'inversionInmobiliaria': 2523.74, 'ahorroSinInversion': 4552.48,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2136.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 770.00},
      {'categoria': 'Pieris', 'importe': 3300.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 50.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 2523.74},
    ],
  },
  {
    'anio': 2023, 'mes': 9, 'nombreMes': 'Septiembre',
    'salario': 3275.29, 'pieris': 3300.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 8515.29, 'gastosFijos': 1913.23, 'gastosHistoricos': 3794.06, 'totalGastos': 5707.29, 'ahorro': 2808.00, 'inversionInmobiliaria': 3130.00, 'ahorroSinInversion': 5938.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3275.29},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3300.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 3130.00},
    ],
  },
  {
    'anio': 2023, 'mes': 10, 'nombreMes': 'Octubre',
    'salario': 0.00, 'pieris': 1400.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 3340.00, 'gastosFijos': 1963.23, 'gastosHistoricos': 2744.77, 'totalGastos': 4708.00, 'ahorro': -1368.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -1368.00,
    'ingresos': [
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1400.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 50.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2023, 'mes': 11, 'nombreMes': 'Noviembre',
    'salario': 0.00, 'pieris': 2420.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 4360.00, 'gastosFijos': 1913.23, 'gastosHistoricos': 2096.71, 'totalGastos': 4009.94, 'ahorro': 350.06, 'inversionInmobiliaria': 2020.06, 'ahorroSinInversion': 2370.12,
    'ingresos': [
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2420.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 178.73},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 2020.06},
    ],
  },
  {
    'anio': 2023, 'mes': 12, 'nombreMes': 'Diciembre',
    'salario': 3297.00, 'pieris': 1450.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 6687.00, 'gastosFijos': 2455.11, 'gastosHistoricos': 4176.89, 'totalGastos': 6632.00, 'ahorro': 55.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 55.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3297.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1450.00},
      {'categoria': 'Otros ingresos', 'importe': 250.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 122.46},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 251.71},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Bordador', 'importe': 166.25},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 1, 'nombreMes': 'Enero',
    'salario': 2595.00, 'pieris': -200.00, 'hipoteca': 899.05, 'alquiler': 650.00,
    'totalIngresos': 5085.00, 'gastosFijos': 2265.50, 'gastosHistoricos': 1444.50, 'totalGastos': 3710.00, 'ahorro': 1375.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 1375.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2595.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': -200.00},
      {'categoria': 'Otros ingresos', 'importe': 1000.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 567.04},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 50.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguros', 'importe': 300.81, 'nota': 'Seguro de vida'},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 2, 'nombreMes': 'Febrero',
    'salario': 3840.00, 'pieris': 1800.00, 'hipoteca': 911.67, 'alquiler': 650.00,
    'totalIngresos': 7830.00, 'gastosFijos': 1927.31, 'gastosHistoricos': 3882.69, 'totalGastos': 5810.00, 'ahorro': 2020.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 2020.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3840.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 1800.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.66},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 650.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 3, 'nombreMes': 'Marzo',
    'salario': 3300.00, 'pieris': 3550.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 9040.00, 'gastosFijos': 2212.65, 'gastosHistoricos': 3327.35, 'totalGastos': 5540.00, 'ahorro': 3500.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3500.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3300.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3550.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 4, 'nombreMes': 'Abril',
    'salario': 3177.00, 'pieris': 4100.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 9467.00, 'gastosFijos': 2212.65, 'gastosHistoricos': 8554.35, 'totalGastos': 10767.00, 'ahorro': -1300.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -1300.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3177.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4100.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 5, 'nombreMes': 'Mayo',
    'salario': 3280.00, 'pieris': 4000.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 9470.00, 'gastosFijos': 2892.65, 'gastosHistoricos': 5647.35, 'totalGastos': 8540.00, 'ahorro': 930.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 930.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3280.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4000.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 115.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 237.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 328.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 6, 'nombreMes': 'Junio',
    'salario': 3216.00, 'pieris': 5100.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 10506.00, 'gastosFijos': 2312.65, 'gastosHistoricos': 5043.35, 'totalGastos': 7356.00, 'ahorro': 3150.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 3150.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3216.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 5100.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 100.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 7, 'nombreMes': 'Julio',
    'salario': 3200.00, 'pieris': 4300.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 9690.00, 'gastosFijos': 2312.65, 'gastosHistoricos': 4642.35, 'totalGastos': 6955.00, 'ahorro': 2735.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 2735.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3200.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4300.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 100.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2024, 'mes': 8, 'nombreMes': 'Agosto',
    'salario': 3200.00, 'pieris': 3800.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 9190.00, 'gastosFijos': 2262.65, 'gastosHistoricos': 2307.35, 'totalGastos': 4570.00, 'ahorro': 4620.00, 'inversionInmobiliaria': 14550.00, 'ahorroSinInversion': 19170.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3200.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3800.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI atraso', 'importe': 180.19},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 50.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 14550.00},
    ],
  },
  {
    'anio': 2024, 'mes': 9, 'nombreMes': 'Septiembre',
    'salario': 5000.00, 'pieris': 3300.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 10490.00, 'gastosFijos': 2032.46, 'gastosHistoricos': 4092.54, 'totalGastos': 6125.00, 'ahorro': 4365.00, 'inversionInmobiliaria': 5540.00, 'ahorroSinInversion': 9905.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 5000.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3300.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 5540.00},
    ],
  },
  {
    'anio': 2024, 'mes': 10, 'nombreMes': 'Octubre',
    'salario': 3770.00, 'pieris': 4950.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 10910.00, 'gastosFijos': 2082.46, 'gastosHistoricos': 1526.54, 'totalGastos': 3609.00, 'ahorro': 7301.00, 'inversionInmobiliaria': 9361.00, 'ahorroSinInversion': 16662.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3770.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4950.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 50.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 9361.00},
    ],
  },
  {
    'anio': 2024, 'mes': 11, 'nombreMes': 'Noviembre',
    'salario': 4977.00, 'pieris': 5000.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 12167.00, 'gastosFijos': 2032.46, 'gastosHistoricos': 2874.54, 'totalGastos': 4907.00, 'ahorro': 7260.00, 'inversionInmobiliaria': 8410.00, 'ahorroSinInversion': 15670.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4977.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 5000.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 8410.00},
    ],
  },
  {
    'anio': 2024, 'mes': 12, 'nombreMes': 'Diciembre',
    'salario': 3500.00, 'pieris': 2200.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 7890.00, 'gastosFijos': 2722.20, 'gastosHistoricos': 637.80, 'totalGastos': 3360.00, 'ahorro': 4530.00, 'inversionInmobiliaria': 6530.00, 'ahorroSinInversion': 11060.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3500.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2200.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 121.23},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 249.18},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 150.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Bordador', 'importe': 169.33},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 6530.00},
    ],
  },
  {
    'anio': 2025, 'mes': 1, 'nombreMes': 'Enero',
    'salario': 3691.00, 'pieris': 2400.00, 'hipoteca': 927.01, 'alquiler': 920.00,
    'totalIngresos': 8281.00, 'gastosFijos': 2472.46, 'gastosHistoricos': 165.54, 'totalGastos': 2638.00, 'ahorro': 5643.00, 'inversionInmobiliaria': 4625.00, 'ahorroSinInversion': 10268.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3691.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 2400.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 595.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 115.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguros', 'importe': 325.00, 'nota': 'Seguro de vida'},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 4625.00},
    ],
  },
  {
    'anio': 2025, 'mes': 2, 'nombreMes': 'Febrero',
    'salario': 4386.00, 'pieris': 3650.00, 'hipoteca': 911.01, 'alquiler': 920.00,
    'totalIngresos': 10726.00, 'gastosFijos': 2016.46, 'gastosHistoricos': 5059.54, 'totalGastos': 7076.00, 'ahorro': 3650.00, 'inversionInmobiliaria': 4948.00, 'ahorroSinInversion': 8598.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4386.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 3650.00},
      {'categoria': 'Otros ingresos', 'importe': 1000.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 920.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 4948.00},
    ],
  },
  {
    'anio': 2025, 'mes': 3, 'nombreMes': 'Marzo',
    'salario': 4121.00, 'pieris': -3000.00, 'hipoteca': 911.01, 'alquiler': 970.00,
    'totalIngresos': 3311.00, 'gastosFijos': 2396.46, 'gastosHistoricos': 1494.54, 'totalGastos': 3891.00, 'ahorro': -580.00, 'inversionInmobiliaria': 6180.00, 'ahorroSinInversion': 5600.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4121.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': -3000.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 330.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 6180.00},
    ],
  },
  {
    'anio': 2025, 'mes': 4, 'nombreMes': 'Abril',
    'salario': 4470.00, 'pieris': 4440.00, 'hipoteca': 911.01, 'alquiler': 970.00,
    'totalIngresos': 11100.00, 'gastosFijos': 2386.46, 'gastosHistoricos': 4552.54, 'totalGastos': 6939.00, 'ahorro': 4161.00, 'inversionInmobiliaria': 2121.00, 'ahorroSinInversion': 6282.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4470.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 4440.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 320.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 2121.00},
    ],
  },
  {
    'anio': 2025, 'mes': 5, 'nombreMes': 'Mayo',
    'salario': 6017.00, 'pieris': 7400.00, 'hipoteca': 911.01, 'alquiler': 970.00,
    'totalIngresos': 15607.00, 'gastosFijos': 2426.46, 'gastosHistoricos': -1186.95, 'totalGastos': 1239.51, 'ahorro': 14367.49, 'inversionInmobiliaria': 7677.49, 'ahorroSinInversion': 22044.98,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 6017.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 7400.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 360.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 7677.49},
    ],
  },
  {
    'anio': 2025, 'mes': 6, 'nombreMes': 'Junio',
    'salario': 2487.00, 'pieris': 5720.00, 'hipoteca': 911.01, 'alquiler': 970.00,
    'totalIngresos': 10397.00, 'gastosFijos': 4419.23, 'gastosHistoricos': 3933.77, 'totalGastos': 8353.00, 'ahorro': 2044.00, 'inversionInmobiliaria': 4559.00, 'ahorroSinInversion': 6603.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2487.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 990.00},
      {'categoria': 'Pieris', 'importe': 5720.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Bordador', 'importe': 579.00},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 115.46},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 237.31},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 2000.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 4559.00},
    ],
  },
  {
    'anio': 2025, 'mes': 7, 'nombreMes': 'Julio',
    'salario': 3300.00, 'pieris': 4350.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 9860.00, 'gastosFijos': 1650.46, 'gastosHistoricos': 2779.54, 'totalGastos': 4430.00, 'ahorro': 5430.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 5430.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3300.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 4350.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Otros préstamos', 'importe': 115.45},
      {'categoria': 'Alquiler', 'importe': 970.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2025, 'mes': 8, 'nombreMes': 'Agosto',
    'salario': 6027.28, 'pieris': 6000.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 14237.28, 'gastosFijos': 3080.37, 'gastosHistoricos': 4696.91, 'totalGastos': 7777.28, 'ahorro': 6460.00, 'inversionInmobiliaria': 1545.00, 'ahorroSinInversion': 8005.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 6027.28},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 6000.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Otros préstamos', 'importe': 1545.36},
      {'categoria': 'Alquiler', 'importe': 970.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Amortización hipoteca', 'importe': 1545.00},
    ],
  },
  {
    'anio': 2025, 'mes': 9, 'nombreMes': 'Septiembre',
    'salario': 3204.45, 'pieris': 8700.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 14114.45, 'gastosFijos': 1535.01, 'gastosHistoricos': 3209.44, 'totalGastos': 4744.45, 'ahorro': 9370.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 9370.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3204.45},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 8700.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Alquiler', 'importe': 970.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2025, 'mes': 10, 'nombreMes': 'Octubre',
    'salario': 3300.00, 'pieris': 4028.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 9538.00, 'gastosFijos': 1685.01, 'gastosHistoricos': 3395.99, 'totalGastos': 5081.00, 'ahorro': 4457.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 4457.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3300.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 4028.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 150.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2025, 'mes': 11, 'nombreMes': 'Noviembre',
    'salario': 5565.00, 'pieris': 4900.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 12675.00, 'gastosFijos': 3507.89, 'gastosHistoricos': 3354.11, 'totalGastos': 6862.00, 'ahorro': 5813.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 5813.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 5565.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 700.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 4900.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 1904.88},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 68.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2025, 'mes': 12, 'nombreMes': 'Diciembre',
    'salario': 2920.00, 'pieris': 950.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 5730.00, 'gastosFijos': 1924.30, 'gastosHistoricos': 4255.70, 'totalGastos': 6180.00, 'ahorro': -450.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -450.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2920.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 350.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 950.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Bordador', 'importe': 121.23},
      {'categoria': 'Pisos', 'subcategoria': 'IBI Afán', 'importe': 249.18},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Bordador', 'importe': 181.88},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 1, 'nombreMes': 'Enero',
    'salario': 4200.00, 'pieris': 6000.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 11210.00, 'gastosFijos': 6223.40, 'gastosHistoricos': 2046.60, 'totalGastos': 8270.00, 'ahorro': 2940.00, 'inversionInmobiliaria': 5000.00, 'ahorroSinInversion': 7940.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4200.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 6000.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 4500.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguros', 'importe': 351.39, 'nota': 'Seguro de vida'},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Compra piso', 'importe': 5000.00},
    ],
  },
  {
    'anio': 2026, 'mes': 2, 'nombreMes': 'Febrero',
    'salario': 4374.00, 'pieris': 2100.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 9464.00, 'gastosFijos': 6067.01, 'gastosHistoricos': 5966.99, 'totalGastos': 12034.00, 'ahorro': -2570.00, 'inversionInmobiliaria': 9200.00, 'ahorroSinInversion': 6630.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 4374.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 2100.00},
      {'categoria': 'Pieris', 'importe': 2100.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 970.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 4500.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 155.00},
    ],
    'inversiones': [
      {'categoria': 'Compra inmuebles', 'subcategoria': 'Compra piso', 'importe': 9200.00},
    ],
  },
  {
    'anio': 2026, 'mes': 3, 'nombreMes': 'Marzo',
    'salario': 3633.00, 'pieris': 2400.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 8233.00, 'gastosFijos': 1412.01, 'gastosHistoricos': 1950.99, 'totalGastos': 3363.00, 'ahorro': 4870.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 4870.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3633.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Pieris', 'importe': 2400.00},
      {'categoria': 'Otros ingresos', 'importe': 300.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 970.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 4, 'nombreMes': 'Abril',
    'salario': 3200.00, 'pieris': 5300.00, 'hipoteca': 332.01, 'alquiler': 970.00,
    'totalIngresos': 11900.00, 'gastosFijos': 1412.01, 'gastosHistoricos': 39712.99, 'totalGastos': 41125.00, 'ahorro': -29225.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': -29225.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3200.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Fco Carrera', 'importe': 1200.00},
      {'categoria': 'Pieris', 'importe': 5300.00},
      {'categoria': 'Otros ingresos', 'importe': 300.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 970.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 5, 'nombreMes': 'Mayo',
    'salario': 3900.00, 'pieris': 12500.00, 'hipoteca': 751.90, 'alquiler': 1000.00,
    'totalIngresos': 19700.00, 'gastosFijos': 2416.90, 'gastosHistoricos': 7383.10, 'totalGastos': 9800.00, 'ahorro': 9900.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 9900.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3900.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Fco Carrera', 'importe': 900.00},
      {'categoria': 'Pieris', 'importe': 12500.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Fco Carrera', 'importe': 419.89},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Fco Carrera', 'importe': 50.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 1000.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Afán', 'importe': 60.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Fco Carrera', 'importe': 65.00},
      {'categoria': 'Pisos', 'subcategoria': 'Seguro Afán', 'importe': 380.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 6, 'nombreMes': 'Junio',
    'salario': 3370.00, 'pieris': 11000.00, 'hipoteca': 751.90, 'alquiler': 1000.00,
    'totalIngresos': 17670.00, 'gastosFijos': 2101.90, 'gastosHistoricos': 7243.10, 'totalGastos': 9345.00, 'ahorro': 8325.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 8325.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3370.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Fco Carrera', 'importe': 900.00},
      {'categoria': 'Pieris', 'importe': 11000.00},
      {'categoria': 'Otros ingresos', 'importe': 500.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Fco Carrera', 'importe': 419.89},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Fco Carrera', 'importe': 50.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 1000.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros Bordador', 'importe': 190.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 7, 'nombreMes': 'Julio',
    'salario': 3300.00, 'pieris': 7500.00, 'hipoteca': 751.90, 'alquiler': 1000.00,
    'totalIngresos': 13900.00, 'gastosFijos': 1911.90, 'gastosHistoricos': 6613.10, 'totalGastos': 8525.00, 'ahorro': 5375.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 5375.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 3300.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Fco Carrera', 'importe': 900.00},
      {'categoria': 'Pieris', 'importe': 7500.00},
      {'categoria': 'Otros ingresos', 'importe': 300.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Fco Carrera', 'importe': 419.89},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 70.00},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Fco Carrera', 'importe': 50.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 1000.00},
    ],
    'inversiones': [
    ],
  },
  {
    'anio': 2026, 'mes': 8, 'nombreMes': 'Agosto',
    'salario': 2714.00, 'pieris': 4700.00, 'hipoteca': 751.90, 'alquiler': 1000.00,
    'totalIngresos': 10514.00, 'gastosFijos': 2074.90, 'gastosHistoricos': 2014.10, 'totalGastos': 4089.00, 'ahorro': 6425.00, 'inversionInmobiliaria': 0.00, 'ahorroSinInversion': 6425.00,
    'ingresos': [
      {'categoria': 'Salario', 'importe': 2714.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Bordador', 'importe': 890.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Afán', 'importe': 1010.00},
      {'categoria': 'Alquileres', 'subcategoria': 'Fco Carrera', 'importe': 900.00},
      {'categoria': 'Pieris', 'importe': 4700.00},
      {'categoria': 'Otros ingresos', 'importe': 300.00},
    ],
    'gastos': [
      {'categoria': 'Hipotecas', 'subcategoria': 'Fco Carrera', 'importe': 419.89},
      {'categoria': 'Hipotecas', 'subcategoria': 'Afán', 'importe': 332.01},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Bordador', 'importe': 233.00},
      {'categoria': 'Pisos', 'subcategoria': 'Comunidad Fco Carrera', 'importe': 50.00},
      {'categoria': 'Pisos', 'subcategoria': 'Otros', 'importe': 40.00, 'nota': 'Trastero'},
      {'categoria': 'Alquiler', 'importe': 1000.00},
    ],
    'inversiones': [
    ],
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
  // Devuelve cuántas unidades de la moneda extranjera equivalen a 1 EUR.
  // Así el resto de la app puede mantener: euros = cantidad / tipoCambio.
  static Future<double> obtenerCambioAEuro(String moneda, DateTime fecha) async {
    final codigo = moneda.trim().toUpperCase();
    if (codigo == 'EUR') return 1.0;

    final prefs = await SharedPreferences.getInstance();

    Future<double> consultar({String? fechaTexto}) async {
      try {
        final uri = Uri.parse(
          'https://api.frankfurter.dev/v2/rate/eur/${codigo.toLowerCase()}'
              '${fechaTexto == null ? '' : '?date=$fechaTexto'}',
        );
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final datos = jsonDecode(response.body);
          final valor = (datos['rate'] as num?)?.toDouble();
          if (valor != null && valor > 0) {
            await prefs.setDouble('fx_$codigo', valor);
            return valor;
          }
        }
      } catch (_) {}
      return 0.0;
    }

    final fechaTexto = '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';

    // Primero la fecha del movimiento. Si todavía no hay cotización,
    // usamos la última disponible.
    var cambio = await consultar(fechaTexto: fechaTexto);
    if (cambio <= 0) cambio = await consultar();

    if (cambio <= 0) {
      final cache = prefs.getDouble('fx_$codigo');
      if (cache != null && cache > 0) return cache;
    }

    return cambio;
  }
}


// ============================================================
// GOOGLE / FIREBASE / SINCRONIZACIÓN
// ============================================================

const String googleServerClientId =
    '32193813079-q9461ho6s57j7k6c46tgcm3p9d51uip5.apps.googleusercontent.com';

class ServicioFirebase {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignInAccount? _googleAccount;

  User? get usuario => _auth.currentUser;
  bool get tieneSesion => _auth.currentUser != null;

  Future<void> inicializar() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize(
        serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId,
      );
    }
  }

  Future<User?> iniciarSesion() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final resultado = await _auth.signInWithPopup(provider);
      return resultado.user;
    }
    final cuenta = await GoogleSignIn.instance.authenticate();
    _googleAccount = cuenta;
    final authentication = await cuenta.authentication;
    final credential = GoogleAuthProvider.credential(idToken: authentication.idToken);
    final resultado = await _auth.signInWithCredential(credential);
    return resultado.user;
  }

  Future<void> prepararSesionExistente() async {}

  Future<void> cerrarSesion() async {
    _googleAccount = null;
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  DocumentReference<Map<String, dynamic>>? get _documentoDatos {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('datos')
        .doc('principal');
  }

  CollectionReference<Map<String, dynamic>>? get _partesDatos {
    final documento = _documentoDatos;
    if (documento == null) return null;
    return documento.collection('partes');
  }

  static const int _tamanoMaximoParte = 650000;

  List<List<dynamic>> _dividirLista(List<dynamic> lista) {
    if (lista.isEmpty) return <List<dynamic>>[];

    final resultado = <List<dynamic>>[];
    var actual = <dynamic>[];
    var bytesActual = 2; // [ ]

    for (final elemento in lista) {
      final bytesElemento = utf8.encode(jsonEncode(elemento)).length;
      final bytesNecesarios =
          bytesActual + bytesElemento + (actual.isEmpty ? 0 : 1);

      if (actual.isNotEmpty && bytesNecesarios > _tamanoMaximoParte) {
        resultado.add(actual);
        actual = <dynamic>[elemento];
        bytesActual = bytesElemento + 2;
      } else {
        actual.add(elemento);
        bytesActual = bytesNecesarios + (actual.length == 1 ? 1 : 0);
      }

      // Si un elemento individual es excepcionalmente grande, lo dejamos
      // como una parte independiente para que el error sea identificable.
      if (actual.length == 1 &&
          bytesActual > _tamanoMaximoParte) {
        throw Exception(
          'Uno de los elementos de los datos de PastApp es demasiado grande '
              'para guardarlo en Firebase.',
        );
      }
    }

    if (actual.isNotEmpty) resultado.add(actual);
    return resultado;
  }

  Future<void> _guardarParte(
      CollectionReference<Map<String, dynamic>> partes,
      String tipo,
      int indice,
      List<dynamic> datos,
      ) async {
    await partes.doc('${tipo}_${indice.toString().padLeft(5, '0')}').set({
      'version': 6,
      'tipo': tipo,
      'indice': indice,
      'datos': datos,
    });
  }

  Future<void> subirDatos(Map<String, dynamic> datos) async {
    final documento = _documentoDatos;
    final partes = _partesDatos;

    if (documento == null || partes == null) {
      throw Exception('No hay una cuenta de Google conectada.');
    }

    // Firestore tiene un límite de 1 MiB por documento. Antes PastApp
    // intentaba guardar todos los movimientos en "principal", lo que hacía
    // que una copia de varios años acabara superando ese límite.
    //
    // A partir de aquí "principal" contiene solamente metadatos y cada lista
    // grande se guarda en documentos independientes dentro de /partes.
    const camposSeparados = <String>[
      'movimientos',
      'historicos',
      'patrimonios',
      'categoriasGastos',
      'categoriasIngresos',
      'correcciones',
      'categoriasPatrimonio',
      'seguimientoInmuebles',
      'deudas',
      'inversiones',
    ];

    final conteos = <String, int>{};
    final listas = <String, List<List<dynamic>>>{};

    for (final campo in camposSeparados) {
      final valor = datos[campo];
      final lista = valor is List ? List<dynamic>.from(valor) : <dynamic>[];
      final partesCampo = _dividirLista(lista);
      listas[campo] = partesCampo;
      conteos[campo] = partesCampo.length;
    }

    final principal = <String, dynamic>{
      'version': 6,
      'formatoDatos': 2,
      'fechaModificacion':
      datos['fechaModificacion'] ?? DateTime.now().toUtc().toIso8601String(),
      'fechaSincronizacion':
      datos['fechaSincronizacion'] ?? DateTime.now().toUtc().toIso8601String(),
      'balanceInicial': datos['balanceInicial'] ?? 0,
      'conteosPartes': conteos,
    };

    // Guardamos primero las partes nuevas. Así, si una operación falla,
    // "principal" sigue apuntando a la versión anterior.
    for (final entrada in listas.entries) {
      final tipo = entrada.key;
      final partesCampo = entrada.value;

      for (var i = 0; i < partesCampo.length; i++) {
        await _guardarParte(partes, tipo, i, partesCampo[i]);
      }
    }

    // El manifiesto se publica al final. Desde este momento los dispositivos
    // nuevos saben exactamente qué partes deben leer.
    await documento.set(principal);

    // Eliminamos partes antiguas que hayan sobrado de una versión anterior.
    // Solo se hace después de publicar correctamente la nueva versión.
    final snapshotPartes = await partes.get();
    final idsValidos = <String>{};

    for (final entrada in listas.entries) {
      final tipo = entrada.key;
      final partesCampo = entrada.value;
      for (var i = 0; i < partesCampo.length; i++) {
        idsValidos.add('${tipo}_${i.toString().padLeft(5, '0')}');
      }
    }

    final antiguas = snapshotPartes.docs
        .where((doc) => !idsValidos.contains(doc.id))
        .toList();

    for (var inicio = 0; inicio < antiguas.length; inicio += 450) {
      final batch = _firestore.batch();
      final fin = math.min(inicio + 450, antiguas.length);
      for (var i = inicio; i < fin; i++) {
        batch.delete(antiguas[i].reference);
      }
      await batch.commit();
    }
  }

  Future<Map<String, dynamic>?> descargarDatos() async {
    final documento = _documentoDatos;
    final partes = _partesDatos;

    if (documento == null || partes == null) {
      throw Exception('No hay una cuenta de Google conectada.');
    }

    final snapshot = await documento.get();
    if (!snapshot.exists || snapshot.data() == null) return null;

    final principal = Map<String, dynamic>.from(snapshot.data()!);

    // Compatibilidad con la estructura antigua: si todavía no se ha migrado
    // este documento, devolvemos sus campos directamente.
    if (principal['formatoDatos'] != 2) {
      return principal;
    }

    final resultado = <String, dynamic>{
      'version': principal['version'] ?? 6,
      'fechaModificacion': principal['fechaModificacion'],
      'fechaSincronizacion': principal['fechaSincronizacion'],
      'balanceInicial': principal['balanceInicial'] ?? 0,
    };

    const camposSeparados = <String>[
      'movimientos',
      'historicos',
      'patrimonios',
      'categoriasGastos',
      'categoriasIngresos',
      'correcciones',
      'categoriasPatrimonio',
    ];

    final snapshotPartes = await partes.get();
    final porCampo = <String, List<Map<String, dynamic>>>{};

    for (final doc in snapshotPartes.docs) {
      final data = doc.data();
      final tipo = data['tipo']?.toString();
      if (tipo == null || !camposSeparados.contains(tipo)) continue;
      porCampo.putIfAbsent(tipo, () => <Map<String, dynamic>>[]).add(data);
    }

    final conteosEsperados = Map<String, dynamic>.from(
      (principal['conteosPartes'] as Map?) ?? <String, dynamic>{},
    );

    for (final campo in camposSeparados) {
      final docs = porCampo[campo] ?? <Map<String, dynamic>>[];
      docs.sort((a, b) {
        final ai = (a['indice'] as num?)?.toInt() ?? 0;
        final bi = (b['indice'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });

      final esperado = (conteosEsperados[campo] as num?)?.toInt() ?? 0;
      if (docs.length != esperado) {
        throw Exception(
          'Sincronización incompleta: faltan datos de $campo. '
              'Esperadas $esperado partes y se han encontrado ${docs.length}.',
        );
      }

      for (var i = 0; i < docs.length; i++) {
        final indice = (docs[i]['indice'] as num?)?.toInt();
        if (indice != i) {
          throw Exception(
            'Sincronización incompleta: falta una parte de $campo (índice $i).',
          );
        }
      }

      final lista = <dynamic>[];
      for (final doc in docs) {
        final datosParte = doc['datos'];
        if (datosParte is! List) {
          throw Exception(
            'Sincronización incompleta: una parte de $campo no contiene una lista válida.',
          );
        }
        lista.addAll(datosParte);
      }
      resultado[campo] = lista;
    }

    return resultado;
  }
}

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

  // Módulos independientes de gestión.
  List<Map<String, dynamic>> seguimientoInmuebles = [];
  List<Map<String, dynamic>> deudas = [];
  List<Map<String, dynamic>> inversiones = [];

  DateTime mesSeleccionado = DateTime.now();

  bool cargando = true;
  bool _mostrarOpcionesFab = false;
  String? _filtroMovimientosInicio;
  bool _mostrarProximosMovimientos = false;
  int _limiteMovimientosInicio = 12;
  Timer? _timerCambiosPendientes;
  Timer? _timerComprobacionSincronizacion;
  Timer? _timerSubidaAutomatica;

  final ServicioFirebase _firebase = ServicioFirebase();
  bool _firebaseInicializado = false;
  bool _googleSincronizando = false;
  bool _datosInicialesCargados = false;
  bool _sincronizacionAutomaticaActiva = false;
  bool _sincronizacionEnCurso = false;
  bool _aplicandoDatosRemotos = false;
  String? _ultimaModificacionLocal;
  bool _cambiosLocalesPendientesDeSubir = false;
  String? _ultimoErrorSincronizacion;
  bool _tareasInicialesSegundoPlanoProgramadas = false;

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
    _inicializarFirebase();
    cargarDatos();
  }

  Future<void> _inicializarFirebase() async {
    try {
      await _firebase.inicializar();
      _firebaseInicializado = true;
      await _firebase.prepararSesionExistente();
      if (mounted) setState(() {});
      await _inicializarSincronizacionAutomaticaSiProcede();
    } catch (_) {
      _firebaseInicializado = false;
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

  void normalizarIdsCategoriasYDatos() {
    String nuevoId() => DateTime.now().microsecondsSinceEpoch.toString();

    void normalizarLista(List<Map<String, dynamic>> lista, String tipo) {
      for (final c in lista) {
        c['id'] = (c['id']?.toString().trim().isNotEmpty == true) ? c['id'].toString() : nuevoId();
        final subs = List<String>.from(c['subcategorias'] ?? []);
        final ids = <String, String>{};
        final antiguos = Map<String, dynamic>.from(c['subcategoriaIds'] ?? {});
        for (final sub in subs) {
          final existente = antiguos[sub]?.toString();
          ids[sub] = (existente != null && existente.isNotEmpty) ? existente : '${c['id']}_sub_${nuevoId()}';
        }
        c['subcategoriaIds'] = ids;
        final ss = <String, List<String>>{};
        final ssIds = <String, Map<String, String>>{};
        final antiguosSs = Map<String, dynamic>.from(c['subsubcategorias'] ?? {});
        final antiguosSsIds = Map<String, dynamic>.from(c['subsubcategoriaIds'] ?? {});
        for (final sub in subs) {
          final nombres = List<String>.from(antiguosSs[sub] ?? const []);
          ss[sub] = nombres;
          final mapa = <String, String>{};
          final antiguosMapa = Map<String, dynamic>.from(antiguosSsIds[sub] ?? {});
          for (final nombre in nombres) {
            final existente = antiguosMapa[nombre]?.toString();
            mapa[nombre] = (existente != null && existente.isNotEmpty) ? existente : '${ids[sub]}_ss_${nuevoId()}';
          }
          ssIds[sub] = mapa;
        }
        c['subsubcategorias'] = ss;
        c['subsubcategoriaIds'] = ssIds;
        if (c['nombre']?.toString() == 'Pisos') {
          final oldSubs = List<String>.from(c['subcategorias'] ?? []);
          final oldIds = Map<String, dynamic>.from(c['subcategoriaIds'] ?? {});
          final oldSs = Map<String, dynamic>.from(c['subsubcategorias'] ?? {});
          final oldSsIds = Map<String, dynamic>.from(c['subsubcategoriaIds'] ?? {});
          final properties = <String>['Bordador', 'Afán', 'Fco Carrera', 'Otros'];
          final standardTypes = <String>['IBI', 'Comunidad', 'Electrodomésticos', 'Seguro hogar', 'Obras', 'Mantenimiento', 'Otros'];
          final propertyAliases = <String, String>{
            'Cerro': 'Afán', 'Iglesias': 'Fco Carrera',
          };
          final newSubs = <String>[];
          final newIds = <String, String>{};
          final newSs = <String, List<String>>{};
          final newSsIds = <String, Map<String, String>>{};
          for (final property in properties) {
            final id = oldIds[property]?.toString() ?? '${c['id']}_sub_${property.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
            newSubs.add(property);
            newIds[property] = id;
            final existing = <String>[];
            for (final key in oldSs.keys) {
              if (key == property || propertyAliases[key] == property) {
                existing.addAll(List<String>.from(oldSs[key] ?? const []));
              }
            }
            final types = property == 'Otros'
                ? <String>{'IBI atraso', 'Seguros', 'Otros', ...existing}.toList()
                : <String>{...standardTypes, ...existing}.toList();
            newSs[property] = types;
            final typeIds = <String, String>{};
            for (final typeName in types) {
              String? existingId;
              for (final key in oldSsIds.keys) {
                final map = Map<String, dynamic>.from(oldSsIds[key] ?? {});
                if (map[typeName] != null) existingId = map[typeName].toString();
              }
              typeIds[typeName] = existingId ?? '${id}_ss_${typeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
            }
            newSsIds[property] = typeIds;
          }
          c['subcategorias'] = newSubs;
          c['subcategoriaIds'] = newIds;
          c['subsubcategorias'] = newSs;
          c['subsubcategoriaIds'] = newSsIds;
        }
        c['archivada'] = c['archivada'] == true;
        c['ocultaAlAnadir'] = c['ocultaAlAnadir'] == true;
      }
    }

    normalizarLista(categoriasGastos, 'Gasto');
    normalizarLista(categoriasIngresos, 'Ingreso');

    Map<String, dynamic>? encontrar(String tipo, String nombre) {
      final lista = tipo == 'Ingreso' ? categoriasIngresos : categoriasGastos;
      for (final c in lista) {
        if (c['nombre']?.toString() == nombre) return c;
      }
      return null;
    }

    void normalizarMovimiento(Map<String, dynamic> m) {
      final tipo = m['tipo']?.toString();
      if (tipo != 'Ingreso' && tipo != 'Gasto') return;
      final c = encontrar(tipo!, m['categoria']?.toString() ?? '');
      if (c == null) return;
      m['categoriaId'] = c['id'];
      final sub = m['subcategoria']?.toString();
      if (sub != null && sub.isNotEmpty) {
        final ids = Map<String, String>.from(c['subcategoriaIds'] ?? {});
        m['subcategoriaId'] = ids[sub];
        final ssMap = Map<String, dynamic>.from(c['subsubcategorias'] ?? {});
        final ssIdsMap = Map<String, dynamic>.from(c['subsubcategoriaIds'] ?? {});
        final ss = m['subsubcategoria']?.toString();
        if (ss != null && ss.isNotEmpty) {
          m['subsubcategoriaId'] = Map<String, String>.from(ssIdsMap[sub] ?? {})[ss];
        }
        // Migración de los antiguos nombres específicos de Pisos a 3 niveles.
        if (c['nombre'] == 'Pisos' && (m['subsubcategoriaId'] == null)) {
          final legacy = <String, List<String>>{
            'Comunidad Bordador': ['Bordador', 'Comunidad'], 'IBI Bordador': ['Bordador', 'IBI'], 'Otros Bordador': ['Bordador', 'Otros'], 'Seguro Bordador': ['Bordador', 'Seguro hogar'],
            'Comunidad Afán': ['Afán', 'Comunidad'], 'IBI Afán': ['Afán', 'IBI'], 'Otros Afán': ['Afán', 'Otros'], 'Seguro Afán': ['Afán', 'Seguro hogar'],
            'Comunidad Fco Carrera': ['Fco Carrera', 'Comunidad'], 'IBI Fco Carrera': ['Fco Carrera', 'IBI'], 'Otros Fco Carrera': ['Fco Carrera', 'Otros'], 'Seguro Fco Carrera': ['Fco Carrera', 'Seguro hogar'],
            'IBI atraso': ['Otros', 'IBI atraso'], 'Seguros': ['Otros', 'Seguros'], 'Seguro Vida': ['Otros', 'Seguros'],
          };
          final mapped = legacy[sub];
          if (mapped != null) {
            final newSub = mapped[0], newSs = mapped[1];
            m['subcategoria'] = newSub;
            m['subcategoriaId'] = ids[newSub];
            m['subsubcategoria'] = newSs;
            m['subsubcategoriaId'] = Map<String, String>.from(ssIdsMap[newSub] ?? {})[newSs];
          }
          if (sub == 'Seguros' && m['nota']?.toString().toLowerCase() == 'seguro de vida') {
            m['subcategoria'] = 'Otros';
            m['subcategoriaId'] = ids['Otros'];
            m['subsubcategoria'] = 'Seguros';
            m['subsubcategoriaId'] = Map<String, String>.from(ssIdsMap['Otros'] ?? {})['Seguros'];
            m['nota'] = 'Seguro de vida';
          }
        }
      }
    }
    for (final m in movimientos) normalizarMovimiento(m);

    // Los datos descargados de Firestore pueden contener mapas inmutables.
    // Nunca modificamos esos mapas directamente: reconstruimos los históricos
    // como mapas/listas mutables antes de normalizarlos.
    historicos = historicos.map((historicoOriginal) {
      final historico = Map<String, dynamic>.from(historicoOriginal);

      for (final key in ['ingresos', 'gastos']) {
        final listaOriginal = historico[key];
        if (listaOriginal is List) {
          final listaMutable = <Map<String, dynamic>>[];

          for (final item in listaOriginal) {
            if (item is Map) {
              final mapa = Map<String, dynamic>.from(item);
              mapa['tipo'] = key == 'ingresos' ? 'Ingreso' : 'Gasto';
              normalizarMovimiento(mapa);
              listaMutable.add(mapa);
            }
          }

          historico[key] = listaMutable;
        }
      }

      return historico;
    }).toList();
  }

  List<Map<String, dynamic>> _decodificarListaMapas(String? texto) {
    if (texto == null || texto.isEmpty) return [];
    try {
      final decoded = jsonDecode(texto);
      if (decoded is! List) return [];
      return decoded.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _listaMapasRemota(dynamic valor) {
    if (valor is! List) return [];
    return valor.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    _ultimaModificacionLocal = prefs.getString('ultima_modificacion_local');
    _cambiosLocalesPendientesDeSubir =
        prefs.getBool('cambios_locales_pendientes_subir') ?? false;

    // En Web no usamos localStorage para los datos grandes de PastApp.
    // La versión anterior intentaba guardar miles de movimientos, históricos
    // y demás listas en SharedPreferences, cuyo backend web usa localStorage.
    // Eso provoca QuotaExceededError al superar la cuota del navegador.
    // En Web Firebase es la fuente de verdad y estos datos se descargan allí.
    // En Android mantenemos la copia local como hasta ahora.
    final movimientosGuardados = kIsWeb ? null : prefs.getString('movimientos');
    final gastosGuardados = kIsWeb ? null : prefs.getString('categorias_gastos');
    final ingresosGuardados = kIsWeb ? null : prefs.getString('categorias_ingresos');
    final correccionesGuardadas = kIsWeb ? null : prefs.getString('correcciones');
    final balanceGuardado = kIsWeb ? null : prefs.getDouble('balance_inicial');
    final historicosGuardados = kIsWeb ? null : prefs.getString('historicos');
    final patrimoniosGuardados = kIsWeb ? null : prefs.getString('patrimonios');
    final categoriasPatrimonioGuardadas =
    kIsWeb ? null : prefs.getString('categorias_patrimonio');
    final seguimientoInmueblesGuardado =
    kIsWeb ? null : prefs.getString('seguimiento_inmuebles');
    final deudasGuardadas = kIsWeb ? null : prefs.getString('deudas');
    final inversionesGuardadas = kIsWeb ? null : prefs.getString('inversiones');

    // Limpieza única de las claves grandes de la versión antigua en Web.
    // No toca Firebase ni los datos sincronizados; solo elimina la caché local
    // del navegador que puede haber quedado ocupando la cuota.
    if (kIsWeb) {
      for (final clave in const [
        'movimientos',
        'categorias_gastos',
        'categorias_ingresos',
        'correcciones',
        'balance_inicial',
        'historicos',
        'patrimonios',
        'categorias_patrimonio',
        'seguimiento_inmuebles',
        'deudas',
        'inversiones',
      ]) {
        try {
          await prefs.remove(clave);
        } catch (_) {}
      }
    }

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

      seguimientoInmuebles = _decodificarListaMapas(seguimientoInmueblesGuardado);
      deudas = _decodificarListaMapas(deudasGuardadas);
      inversiones = _decodificarListaMapas(inversionesGuardadas);

      normalizarIdsCategoriasYDatos();

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
      // Garantiza las categorías nuevas necesarias para los históricos.
      void asegurarCategoria(
          List<Map<String, dynamic>> lista,
          String nombre,
          String emoji,
          List<String> subcategorias,
          ) {
        final existentes = lista.where((c) => c['nombre']?.toString() == nombre).toList();
        if (existentes.isEmpty) {
          lista.add({
            'nombre': nombre,
            'emoji': emoji,
            'subcategorias': List<String>.from(subcategorias),
            'archivada': false,
            'ocultaAlAnadir': false,
          });
        } else {
          final c = existentes.first;
          c['emoji'] = emoji;
          final subsActuales = List<String>.from(c['subcategorias'] ?? []);
          for (final sub in subcategorias) {
            if (!subsActuales.contains(sub)) subsActuales.add(sub);
          }
          c['subcategorias'] = subsActuales;
          c['archivada'] = false;
        }
      }

      asegurarCategoria(categoriasGastos, 'Otros préstamos', '💶', []);
      asegurarCategoria(categoriasGastos, 'Compra inmuebles', '🏢', [
        'Amortización hipoteca',
        'Compra piso',
      ]);
      asegurarCategoria(categoriasIngresos, 'Otros ingresos', '💰', []);
      asegurarCategoria(categoriasIngresos, 'Alquileres', '🏘️', [
        'Bordador',
        'Afán',
        'Fco Carrera',
      ]);

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
          'Hipotecas': ['Bordador', 'Afán', 'Fco Carrera', 'Otros'],
          'Pisos': [
            'Obras',
            'Mantenimiento',
            'Electrodomésticos',
            'Comunidad',
            'Seguro hogar',
            'IBI',
            'Otros',
            'Comunidad Bordador',
            'Comunidad Afán',
            'Comunidad Fco Carrera',
            'IBI Bordador',
            'IBI Afán',
            'IBI Fco Carrera',
            'IBI atraso',
            'Otros Bordador',
            'Otros Afán',
            'Otros Fco Carrera',
            'Seguro Bordador',
            'Seguro Afán',
            'Seguro Fco Carrera',
            'Seguros',
          ],
          'Alquileres': ['Bordador', 'Afán', 'Fco Carrera'],
          'Compra inmuebles': ['Amortización hipoteca', 'Compra piso'],
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

      // La app parte sin movimientos: cargamos los históricos del Excel
      // una sola vez como datos históricos separados.
      if (historicos.isEmpty) {
        historicos = historicosInicialesPastApp
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
      }

      normalizarIdsCategoriasYDatos();

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

    // La interfaz ya está preparada. La sincronización inicial sigue teniendo
    // prioridad, pero las tareas pesadas de recurrencias y divisas se ejecutan
    // después del primer frame para evitar bloquear el navegador al arrancar.
    _datosInicialesCargados = true;
    await _inicializarSincronizacionAutomaticaSiProcede();
    _programarTareasInicialesEnSegundoPlano();
  }

  void _programarTareasInicialesEnSegundoPlano() {
    if (_tareasInicialesSegundoPlanoProgramadas) return;
    _tareasInicialesSegundoPlanoProgramadas = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      try {
        await generarRecurrentesPendientes();
        await actualizarCambiosPendientes();
      } catch (_) {
        // Son tareas auxiliares: un fallo no debe bloquear la interfaz.
      }
    });
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

// SINCRONIZACIÓN FIREBASE
// ============================================================

  Map<String, dynamic> _datosParaSincronizar() {
    final fecha = _ultimaModificacionLocal ?? DateTime.now().toUtc().toIso8601String();
    return {
      'version': 5,
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
      'seguimientoInmuebles': seguimientoInmuebles,
      'deudas': deudas,
      'inversiones': inversiones,
    };
  }

  DateTime? _fechaDeDatosRemotos(Map<String, dynamic> datos) {
    final texto = (datos['fechaModificacion'] ?? datos['fechaSincronizacion'])?.toString();
    if (texto == null || texto.isEmpty) return null;
    return DateTime.tryParse(texto);
  }

  DateTime? _fechaDeDatosLocales() {
    if (_ultimaModificacionLocal == null || _ultimaModificacionLocal!.isEmpty) return null;
    return DateTime.tryParse(_ultimaModificacionLocal!);
  }

  Future<void> _inicializarSincronizacionAutomaticaSiProcede() async {
    if (!_datosInicialesCargados || !_firebaseInicializado ||
        _sincronizacionAutomaticaActiva || _firebase.usuario == null) return;
    _sincronizacionAutomaticaActiva = true;
    await _comprobarSincronizacionAutomatica();
  }

  void _programarSubidaAutomatica() {
    if (!_sincronizacionAutomaticaActiva || _aplicandoDatosRemotos) return;
    _timerSubidaAutomatica?.cancel();
    _timerSubidaAutomatica = Timer(const Duration(milliseconds: 800), _subirCambiosAutomaticamente);
  }

  Future<void> _subirCambiosAutomaticamente() async {
    if (!_sincronizacionAutomaticaActiva ||
        _sincronizacionEnCurso ||
        _aplicandoDatosRemotos ||
        _firebase.usuario == null ||
        !_cambiosLocalesPendientesDeSubir) {
      return;
    }

    try {
      _sincronizacionEnCurso = true;
      if (movimientos.isEmpty && historicos.isEmpty && _datosInicialesCargados) {
        final prefs = await SharedPreferences.getInstance();
        final movimientosGuardados = prefs.getString('movimientos');
        final historicosGuardados = prefs.getString('historicos');
        final hayDatosLocales =
            (movimientosGuardados != null && movimientosGuardados != '[]') ||
                (historicosGuardados != null && historicosGuardados != '[]');
        if (hayDatosLocales) {
          throw Exception(
            'Se ha evitado subir una copia vacía porque existen datos locales guardados.',
          );
        }
      }
      await _firebase.subirDatos(_datosParaSincronizar());
      _cambiosLocalesPendientesDeSubir = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cambios_locales_pendientes_subir', false);
      _ultimoErrorSincronizacion = null;
    } catch (e) {
      _ultimoErrorSincronizacion = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se han podido guardar los cambios en Firebase: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      _programarSubidaAutomatica();
    } finally {
      _sincronizacionEnCurso = false;
    }
  }

  Future<void> _comprobarSincronizacionAutomatica() async {
    if (!_sincronizacionAutomaticaActiva ||
        _sincronizacionEnCurso ||
        !_datosInicialesCargados ||
        _aplicandoDatosRemotos ||
        _firebase.usuario == null) {
      return;
    }

    try {
      _sincronizacionEnCurso = true;

      // Si este dispositivo tiene cambios que todavía no han llegado a
      // Firebase, SIEMPRE tienen prioridad. Esto evita que al arrancar o al
      // ejecutarse el comprobador periódico una copia remota antigua borre
      // movimientos recién introducidos en septiembre.
      if (_cambiosLocalesPendientesDeSubir) {
        await _firebase.subirDatos(_datosParaSincronizar());
        _cambiosLocalesPendientesDeSubir = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cambios_locales_pendientes_subir', false);
        _ultimoErrorSincronizacion = null;
        return;
      }

      final datosRemotos = await _firebase.descargarDatos();

      if (datosRemotos == null) {
        if (_ultimaModificacionLocal == null) {
          _ultimaModificacionLocal = DateTime.now().toUtc().toIso8601String();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'ultima_modificacion_local',
            _ultimaModificacionLocal!,
          );
        }
        await _firebase.subirDatos(_datosParaSincronizar());
        _ultimoErrorSincronizacion = null;
        return;
      }

      final fechaRemota = _fechaDeDatosRemotos(datosRemotos);
      final fechaLocal = _fechaDeDatosLocales();

      if (fechaLocal == null && fechaRemota != null) {
        await _aplicarDatosSincronizados(datosRemotos);
      } else if (fechaRemota != null &&
          fechaLocal != null &&
          fechaRemota.isAfter(fechaLocal)) {
        await _aplicarDatosSincronizados(datosRemotos);
      } else if (fechaLocal != null &&
          (fechaRemota == null || fechaLocal.isAfter(fechaRemota))) {
        await _firebase.subirDatos(_datosParaSincronizar());
      }
      _ultimoErrorSincronizacion = null;
    } catch (e) {
      _ultimoErrorSincronizacion = e.toString();
      if (mounted) {
        // No interrumpimos la aplicación, pero dejamos el error visible.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error de sincronización: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
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
        _ultimaModificacionLocal = DateTime.now().toUtc().toIso8601String();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ultima_modificacion_local', _ultimaModificacionLocal!);
        await _firebase.subirDatos(_datosParaSincronizar());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos sincronizados con Google')));
      } finally { if (mounted) setState(() => _googleSincronizando = false); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se ha podido sincronizar: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Future<void> restaurarDesdeGoogle() async {
    try {
      await _asegurarGoogleDrive();
      if (!mounted) return;
      setState(() => _googleSincronizando = true);
      try {
        final datos = await _firebase.descargarDatos();
        if (datos == null) throw Exception('No existe todavía una copia sincronizada.');
        await _aplicarDatosSincronizados(datos);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos restaurados desde Google')));
      } finally { if (mounted) setState(() => _googleSincronizando = false); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se ha podido restaurar: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Future<void> _aplicarDatosSincronizados(Map<String, dynamic> datos) async {
    _aplicandoDatosRemotos = true;
    final nuevosMovimientos = List<Map<String, dynamic>>.from((datos['movimientos'] ?? []).map((item) => Map<String, dynamic>.from(item)));
    final nuevasCategoriasGastos = List<Map<String, dynamic>>.from((datos['categoriasGastos'] ?? []).map((item) {
      final mapa = Map<String, dynamic>.from(item);
      mapa['subcategorias'] = List<String>.from(mapa['subcategorias'] ?? []);
      mapa['archivada'] = mapa['archivada'] == true;
      mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
      return mapa;
    }));
    final nuevasCategoriasIngresos = List<Map<String, dynamic>>.from((datos['categoriasIngresos'] ?? []).map((item) {
      final mapa = Map<String, dynamic>.from(item);
      mapa['subcategorias'] = List<String>.from(mapa['subcategorias'] ?? []);
      mapa['archivada'] = mapa['archivada'] == true;
      mapa['ocultaAlAnadir'] = mapa['ocultaAlAnadir'] == true;
      return mapa;
    }));
    // Los históricos incluidos en la app son datos base de PastApp. Si una
    // copia remota antigua todavía no contiene históricos (lista vacía), no
    // debemos borrarlos al sincronizar: conservamos los históricos locales
    // y los subiremos de nuevo a Firebase.
    final historicosRemotos = List<Map<String, dynamic>>.from(
      (datos['historicos'] ?? []).map((item) => Map<String, dynamic>.from(item)),
    );
    final nuevosHistoricos = historicosRemotos.isEmpty && historicos.isNotEmpty
        ? historicos.map((h) => Map<String, dynamic>.from(h)).toList()
        : historicosRemotos;
    final nuevosPatrimonios = List<Map<String, dynamic>>.from((datos['patrimonios'] ?? []).map((item) {
      final mapa = Map<String, dynamic>.from(item);
      mapa['cuentas'] = List<Map<String, dynamic>>.from((mapa['cuentas'] ?? []).map((cuenta) => Map<String, dynamic>.from(cuenta)));
      return mapa;
    }));
    final nuevasCategoriasPatrimonio = List<Map<String, String>>.from((datos['categoriasPatrimonio'] ?? []).map((item) => Map<String, String>.from(item)));
    final nuevoSeguimientoInmuebles = _listaMapasRemota(datos['seguimientoInmuebles']);
    final nuevasDeudas = _listaMapasRemota(datos['deudas']);
    final nuevasInversiones = _listaMapasRemota(datos['inversiones']);
    setState(() {
      movimientos = nuevosMovimientos;
      categoriasGastos = nuevasCategoriasGastos.isEmpty ? copiarCategorias(categoriasGastosIniciales) : nuevasCategoriasGastos;
      categoriasIngresos = nuevasCategoriasIngresos.isEmpty ? copiarCategorias(categoriasIngresosIniciales) : nuevasCategoriasIngresos;
      correcciones = List<Map<String, dynamic>>.from((datos['correcciones'] ?? []).map((item) => Map<String, dynamic>.from(item)));
      balanceInicial = ((datos['balanceInicial'] as num?) ?? 0).toDouble();
      historicos = nuevosHistoricos;
      patrimonios = nuevosPatrimonios;
      if (nuevasCategoriasPatrimonio.isNotEmpty) categoriasPatrimonio = nuevasCategoriasPatrimonio;
      seguimientoInmuebles = nuevoSeguimientoInmuebles;
      deudas = nuevasDeudas;
      inversiones = nuevasInversiones;
    });
    final fechaRemota = _fechaDeDatosRemotos(datos);
    if (fechaRemota != null) _ultimaModificacionLocal = fechaRemota.toUtc().toIso8601String();
    try {
      await guardarDatos(marcarComoCambioLocal: false);
    } finally { _aplicandoDatosRemotos = false; }

    // La reconstrucción de recurrencias puede recorrer miles de movimientos.
    // Se pospone para no bloquear el primer render tras una sincronización.
    if (mounted) {
      Future<void>.delayed(const Duration(milliseconds: 50), () async {
        if (!mounted) return;
        await generarRecurrentesPendientes();
        await actualizarCambiosPendientes();
      });
    }
  }

  Future<void> conectarGoogleDesdeAjustes() async {
    try {
      if (!_firebaseInicializado) await _inicializarFirebase();
      if (_firebase.usuario == null) await _firebase.iniciarSesion();
      if (!mounted) return;
      final usuario = _firebase.usuario;
      if (usuario == null) throw Exception('No se ha podido conectar la cuenta.');
      _sincronizacionAutomaticaActiva = true;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google conectado: ${usuario.email ?? ''}')));
      await _comprobarSincronizacionAutomatica();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se ha podido conectar Google: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Future<void> desconectarGoogleDesdeAjustes() async {
    try {
      await _firebase.cerrarSesion();
      _sincronizacionAutomaticaActiva = false;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google desconectado')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se ha podido desconectar Google: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Future<void> _asegurarGoogleDrive() async {
    if (!_firebaseInicializado) await _inicializarFirebase();
    if (_firebase.usuario == null) await conectarGoogleDesdeAjustes();
    if (_firebase.usuario == null) throw Exception('No se ha podido iniciar sesión con Google.');
  }

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

    if (!kIsWeb) {
      // Android mantiene una copia local completa. En Web NO guardamos estas
      // listas en SharedPreferences porque el backend web usa localStorage y
      // tiene una cuota demasiado pequeña para los datos actuales de PastApp.
      await prefs.setString('movimientos', jsonEncode(movimientos));
      await prefs.setString('categorias_gastos', jsonEncode(categoriasGastos));
      await prefs.setString('categorias_ingresos', jsonEncode(categoriasIngresos));
      await prefs.setString('correcciones', jsonEncode(correcciones));
      await prefs.setDouble('balance_inicial', balanceInicial);
      await prefs.setString('historicos', jsonEncode(historicos));
      await prefs.setString('patrimonios', jsonEncode(patrimonios));
      await prefs.setString('categorias_patrimonio', jsonEncode(categoriasPatrimonio));
      await prefs.setString('seguimiento_inmuebles', jsonEncode(seguimientoInmuebles));
      await prefs.setString('deudas', jsonEncode(deudas));
      await prefs.setString('inversiones', jsonEncode(inversiones));
    }

    if (marcarComoCambioLocal &&
        _datosInicialesCargados &&
        !_aplicandoDatosRemotos) {
      // Marcamos el cambio como pendiente ANTES de intentar la subida.
      // Si Firebase falla, al siguiente arranque no se descargará una copia
      // antigua que pueda hacer desaparecer los cambios locales.
      _cambiosLocalesPendientesDeSubir = true;
      await prefs.setBool('cambios_locales_pendientes_subir', true);
      _timerSubidaAutomatica?.cancel();

      if (_firebase.usuario != null && !_sincronizacionEnCurso) {
        try {
          _sincronizacionEnCurso = true;
          await _firebase.subirDatos(_datosParaSincronizar());
          _cambiosLocalesPendientesDeSubir = false;
          await prefs.setBool('cambios_locales_pendientes_subir', false);
          _ultimoErrorSincronizacion = null;
        } catch (e) {
          _ultimoErrorSincronizacion = e.toString();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se han podido guardar los cambios en Firebase: ${e.toString().replaceFirst('Exception: ', '')}',
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          }
          _programarSubidaAutomatica();
        } finally {
          _sincronizacionEnCurso = false;
        }
      } else {
        _programarSubidaAutomatica();
      }
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
        text: 'Exportación de PastApp en Excel',
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
        text: 'Copia de seguridad de PastApp',
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

    // Se procesa cada movimiento independientemente.
    // Un HUF que falle no bloquea BRL, USD, etc.
    for (final movimiento in pendientes) {
      try {
        final moneda = movimiento['moneda']?.toString() ?? 'EUR';
        final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');
        if (fecha.year == 1900) continue;

        final cambio = await ServicioDivisas.obtenerCambioAEuro(moneda, fecha);

        if (cambio > 0) {
          final original =
          ((movimiento['cantidadOriginal'] as num?) ?? 0).toDouble();

          movimiento['tipoCambio'] = cambio;
          movimiento['cantidad'] = original / cambio;
          movimiento['tipoCambioPendiente'] = false;
          cambios = true;
        }
      } catch (_) {
        // Este movimiento queda pendiente y se intentará de nuevo después.
      }
    }

    if (cambios) {
      // La conversión ya está calculada: la marcamos como un cambio real y
      // la subimos directamente a Firebase. No esperamos al temporizador,
      // porque al recargar la página debe recuperarse ya convertida.
      await guardarDatos(marcarComoCambioLocal: true);

      if (_firebase.usuario != null) {
        try {
          await _firebase.subirDatos(_datosParaSincronizar());
        } catch (_) {
          // Si Firebase falla momentáneamente, queda guardado localmente y
          // la subida automática volverá a intentarlo.
        }
      }

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
    // Las recurrencias se mantienen durante 100 años, tanto en Web como en Android.
    final limite = DateTime(ahora.year + 100, ahora.month, ahora.day);

    // Evita una búsqueda O(n) por cada ocurrencia futura. Con muchos
    // movimientos, el Set reduce muchísimo el trabajo de arranque.
    final clavesRecurrenciasExistentes = <String>{};
    for (final movimiento in movimientos) {
      final recurrenceId = movimiento['recurrenceId']?.toString();
      final fechaExistente = movimiento['fecha']?.toString();
      if (recurrenceId != null && recurrenceId.isNotEmpty &&
          fechaExistente != null && fechaExistente.isNotEmpty) {
        clavesRecurrenciasExistentes.add('$recurrenceId|$fechaExistente');
      }
    }

    var iteracionesDesdeUltimoYield = 0;

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

      final fechaFinTexto =
          recurrente['plantillaFechaFinRecurrencia']?.toString() ??
              recurrente['fechaFinRecurrencia']?.toString() ??
              '';
      final fechaFin = convertirFecha(fechaFinTexto);
      final tieneFechaFin = fechaFin.year != 1900;

      final inicioProgramacion = convertirFecha(recurrente['recurrenceStartDate']?.toString() ?? '');
      DateTime fecha = inicioProgramacion.year != 1900
          ? inicioProgramacion
          : sumarMeses(fechaOriginal, intervalo);

      while (!fecha.isAfter(limite) && (!tieneFechaFin || !fecha.isAfter(fechaFin))) {
        final omitidas = List<String>.from(
          recurrente['recurrenciasOmitidas'] ?? const [],
        );

        final fechaNuevaTexto = fechaTexto(fecha);
        final claveNueva = '${recurrente['id']}|$fechaNuevaTexto';
        final yaExiste = clavesRecurrenciasExistentes.contains(claveNueva);

        if (!yaExiste && !omitidas.contains(fechaNuevaTexto)) {
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
            'subsubcategoria': recurrente['plantillaSubsubcategoria'] ?? recurrente['subsubcategoria'],
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
          clavesRecurrenciasExistentes.add(claveNueva);
          huboCambios = true;
        }

        fecha = sumarMeses(fecha, intervalo);
        iteracionesDesdeUltimoYield++;
        if (iteracionesDesdeUltimoYield >= 250) {
          iteracionesDesdeUltimoYield = 0;
          await Future<void>.delayed(Duration.zero);
        }
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
    if (movimiento['esHistorico'] == true) {
      await editarMovimientoHistorico(movimiento);
      return;
    }
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

  bool _esParteDeSerieRecurrente(Map<String, dynamic> movimiento) {
    if (movimiento['recurrente'] == true) return true;
    final recurrenceId = movimiento['recurrenceId']?.toString();
    if (recurrenceId == null || recurrenceId.isEmpty) return false;
    return movimientos.any((m) => m['id']?.toString() == recurrenceId && m['recurrente'] == true);
  }

  String _idRaizSerieRecurrente(Map<String, dynamic> movimiento) {
    return movimiento['recurrenceId']?.toString() ?? movimiento['id']?.toString() ?? '';
  }

  Map<String, dynamic>? _raizSerie(Map<String, dynamic> movimiento) {
    final rootId = _idRaizSerieRecurrente(movimiento);
    for (final m in movimientos) {
      if (m['id']?.toString() == rootId) return m;
    }
    return null;
  }

  List<Map<String, dynamic>> _entradasSerie(String rootId) {
    return movimientos.where((m) {
      return m['id']?.toString() == rootId || m['recurrenceId']?.toString() == rootId;
    }).toList();
  }

  void _limpiarMetadatosRecurrencia(Map<String, dynamic> movimiento) {
    movimiento['recurrente'] = false;
    movimiento['recurrenceId'] = null;
    movimiento['intervaloMeses'] = 1;
    movimiento['plantillaCantidad'] = null;
    movimiento['plantillaCantidadOriginal'] = null;
    movimiento['plantillaMoneda'] = null;
    movimiento['plantillaTipoCambio'] = null;
    movimiento['plantillaTipoCambioPendiente'] = null;
    movimiento['plantillaCategoria'] = null;
    movimiento['plantillaSubcategoria'] = null;
    movimiento['plantillaEmoji'] = null;
    movimiento['plantillaNota'] = null;
    movimiento['plantillaFotoPath'] = null;
    movimiento['plantillaIntervaloMeses'] = null;
  }

  Future<int?> preguntarAlcanceEdicionRecurrente(
      Map<String, dynamic> original, {
        required bool alDesactivar,
      }) async {
    if (!_esParteDeSerieRecurrente(original)) return 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(alDesactivar ? 'Quitar recurrencia' : 'Movimiento recurrente'),
        content: Text(
          alDesactivar
              ? '¿Hasta dónde quieres detener la recurrencia?'
              : '¿A qué entradas quieres aplicar los cambios?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Solo esta entrada'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 1),
            child: const Text('Esta y las siguientes'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 2),
            child: const Text('Toda la serie'),
          ),
        ],
      ),
    );
  }

  void _copiarPlantilla(Map<String, dynamic> destino, Map<String, dynamic> fuente) {
    const claves = [
      'cantidad', 'cantidadOriginal', 'moneda', 'tipoCambio',
      'tipoCambioPendiente', 'tipo', 'categoria', 'subcategoria', 'emoji',
      'nota', 'fotoPath',
    ];
    for (final clave in claves) {
      destino[clave] = fuente[clave];
    }
  }

  void _guardarPlantillaEnRaiz(Map<String, dynamic> raiz, Map<String, dynamic> datos, int intervalo) {
    raiz['recurrente'] = true;
    raiz['recurrenceId'] = null;
    raiz['intervaloMeses'] = intervalo;
    raiz['plantillaCantidad'] = datos['cantidad'];
    raiz['plantillaCantidadOriginal'] = datos['cantidadOriginal'];
    raiz['plantillaMoneda'] = datos['moneda'];
    raiz['plantillaTipoCambio'] = datos['tipoCambio'];
    raiz['plantillaTipoCambioPendiente'] = datos['tipoCambioPendiente'];
    raiz['plantillaCategoria'] = datos['categoria'];
    raiz['plantillaSubcategoria'] = datos['subcategoria'];
    raiz['plantillaEmoji'] = datos['emoji'];
    raiz['plantillaNota'] = datos['nota'] ?? '';
    raiz['plantillaFotoPath'] = datos['fotoPath'];
    raiz['plantillaIntervaloMeses'] = intervalo;
  }

  Future<void> _confirmarBorradoTodaSerie(
      Map<String, dynamic> movimiento,
      String rootId,
      DateTime fecha,
      ) async {
    final serie = _entradasSerie(rootId);
    final pasadas = serie.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return f.year != 1900 && f.isBefore(fecha);
    }).toList()
      ..sort((a, b) => convertirFecha(b['fecha']?.toString() ?? '')
          .compareTo(convertirFecha(a['fecha']?.toString() ?? '')));

    final ejemplos = pasadas.take(3).map((m) {
      final importe = ((m['cantidad'] as num?) ?? 0).toDouble().abs();
      return '${m['fecha']} · ${m['categoria'] ?? ''} · ${formatearEuros(importe)}';
    }).join('\n');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar toda la serie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se borrará este movimiento, todas las entradas futuras y todo el histórico de esta serie.'),
            if (pasadas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('También se eliminarán entradas anteriores, por ejemplo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(ejemplos),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar toda la serie'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) throw _CancelRecurrenceAction();
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
    String? categoriaEditada = original['categoria']?.toString();
    String? subcategoriaEditada = original['subcategoria']?.toString();
    String? subsubcategoriaEditada = original['subsubcategoria']?.toString();
    final notaEditController = TextEditingController(text: original['nota']?.toString() ?? '');
    bool recurrenteEditado = original['recurrente'] == true;
    int intervaloEditado =
    ((original['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120);
    final intervaloEditController = TextEditingController(
      text: intervaloEditado.toString(),
    );
    DateTime? fechaFinRecurrencia = (() {
      final f = convertirFecha(original['fechaFinRecurrencia']?.toString() ?? original['plantillaFechaFinRecurrencia']?.toString() ?? '');
      return f.year == 1900 ? null : f;
    })();

    List<Map<String, dynamic>> categoriasEdit = List<Map<String, dynamic>>.from(
      esGasto ? categoriasGastos : categoriasIngresos,
    )..sort((a, b) => (a['nombre']?.toString() ?? '').toLowerCase().compareTo((b['nombre']?.toString() ?? '').toLowerCase()));

    List<String> subsEdit(String? cat) {
      final candidatos = categoriasEdit.where((x) => x['nombre']?.toString() == cat).toList();
      final c = candidatos.isEmpty ? null : candidatos.first;
      return List<String>.from(c?['subcategorias'] ?? const []);
    }

    List<String> ssEdit(String? cat, String? sub) {
      final candidatos = categoriasEdit.where((x) => x['nombre']?.toString() == cat).toList();
      final c = candidatos.isEmpty ? null : candidatos.first;
      final mapa = Map<String, dynamic>.from(c?['subsubcategorias'] ?? {});
      return List<String>.from(mapa[sub] ?? const []);
    }

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

                    DropdownButtonFormField<String>(
                      value: categoriasEdit.any((c) => c['nombre']?.toString() == categoriaEditada) ? categoriaEditada : null,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                      items: categoriasEdit.map((c) => DropdownMenuItem<String>(
                        value: c['nombre']?.toString(),
                        child: Text(c['nombre']?.toString() ?? ''),
                      )).toList(),
                      onChanged: (v) => setSheetState(() {
                        categoriaEditada = v;
                        final subs = subsEdit(v);
                        subcategoriaEditada = subs.contains(subcategoriaEditada) ? subcategoriaEditada : (subs.isNotEmpty ? subs.first : null);
                        final ss = ssEdit(v, subcategoriaEditada);
                        subsubcategoriaEditada = ss.contains(subsubcategoriaEditada) ? subsubcategoriaEditada : (ss.isNotEmpty ? ss.first : null);
                      }),
                    ),
                    const SizedBox(height: 10),
                    if (subsEdit(categoriaEditada).isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: subsEdit(categoriaEditada).contains(subcategoriaEditada) ? subcategoriaEditada : null,
                        decoration: InputDecoration(
                          labelText: esGasto && categoriaEditada == 'Pisos' ? 'Inmueble' : 'Subcategoría',
                          border: const OutlineInputBorder(),
                        ),
                        items: subsEdit(categoriaEditada).map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setSheetState(() {
                          subcategoriaEditada = v;
                          final ss = ssEdit(categoriaEditada, v);
                          subsubcategoriaEditada = ss.contains(subsubcategoriaEditada) ? subsubcategoriaEditada : (ss.isNotEmpty ? ss.first : null);
                        }),
                      ),
                    if (ssEdit(categoriaEditada, subcategoriaEditada).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: ssEdit(categoriaEditada, subcategoriaEditada).contains(subsubcategoriaEditada) ? subsubcategoriaEditada : null,
                        decoration: InputDecoration(
                          labelText: esGasto && categoriaEditada == 'Pisos' ? 'Tipo de gasto' : 'Detalle',
                          border: const OutlineInputBorder(),
                        ),
                        items: ssEdit(categoriaEditada, subcategoriaEditada).map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setSheetState(() => subsubcategoriaEditada = v),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: notaEditController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Nota / comentario',
                        border: OutlineInputBorder(),
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
                    if (recurrenteEditado)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Finalizar recurrencia'),
                        subtitle: Text(
                          fechaFinRecurrencia == null
                              ? 'Sin fecha de finalización'
                              : fechaTexto(fechaFinRecurrencia!),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fechaFinRecurrencia != null)
                              IconButton(
                                tooltip: 'Quitar fecha de finalización',
                                onPressed: () => setSheetState(() => fechaFinRecurrencia = null),
                                icon: const Icon(Icons.clear),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () async {
                          final inicial = fechaFinRecurrencia ??
                              DateTime(fecha.year + 1, fecha.month, fecha.day);
                          final d = await showDatePicker(
                            context: context,
                            initialDate: inicial.isBefore(fecha) ? fecha : inicial,
                            firstDate: fecha,
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSheetState(() => fechaFinRecurrencia = d);
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
                          if (valor == null || valor < 0) return;

                          Navigator.pop(
                            sheetContext,
                            {
                              'cantidad': valor,
                              'moneda': moneda,
                              'fecha': fecha,
                              'categoria': categoriaEditada,
                              'subcategoria': subcategoriaEditada,
                              'subsubcategoria': subsubcategoriaEditada,
                              'nota': notaEditController.text.trim(),
                              'fechaFinRecurrencia': fechaFinRecurrencia == null ? null : fechaTexto(fechaFinRecurrencia!),
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
    notaEditController.dispose();

    if (resultado == null || !mounted) return;

    if (resultado['eliminar'] == true) {
      await eliminarMovimiento(original);
      return;
    }

    int? alcance = 0;
    final nuevaRecurrente = resultado['recurrente'] == true;
    final nuevoIntervalo = ((resultado['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120);
    if (original['recurrente'] == true && nuevaRecurrente) {
      alcance = await preguntarAlcanceEdicionRecurrente(original, alDesactivar: !nuevaRecurrente);
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
    actualizado['categoria'] = resultado['categoria']?.toString() ?? actualizado['categoria'];
    actualizado['subcategoria'] = resultado['subcategoria'];
    actualizado['subsubcategoria'] = resultado['subsubcategoria'];
    actualizado['nota'] = resultado['nota']?.toString() ?? '';
    actualizado['recurrente'] = nuevaRecurrente;
    actualizado['intervaloMeses'] = nuevoIntervalo;
    actualizado['fechaFinRecurrencia'] = resultado['fechaFinRecurrencia'];
    final categoriasActuales = esGasto ? categoriasGastos : categoriasIngresos;
    final candidatosCat = categoriasActuales
        .where((c) => c['nombre']?.toString() == actualizado['categoria'])
        .toList();
    final catActual = candidatosCat.isEmpty ? null : candidatosCat.first;
    actualizado['categoriaId'] = catActual?['id'];
    final subIdsActual = Map<String, dynamic>.from(catActual?['subcategoriaIds'] ?? {});
    actualizado['subcategoriaId'] = actualizado['subcategoria'] == null ? null : subIdsActual[actualizado['subcategoria']];
    final ssIdsActual = Map<String, dynamic>.from(catActual?['subsubcategoriaIds'] ?? {});
    final ssMapActual = Map<String, dynamic>.from(ssIdsActual[actualizado['subcategoria']] ?? {});
    actualizado['subsubcategoriaId'] = actualizado['subsubcategoria'] == null ? null : ssMapActual[actualizado['subsubcategoria']];

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
      actualizado['plantillaFechaFinRecurrencia'] = null;
      actualizado['fechaFinRecurrencia'] = null;
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
        raiz['plantillaFechaFinRecurrencia'] = null;
        raiz['fechaFinRecurrencia'] = null;
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
      fuente['plantillaFechaFinRecurrencia'] = actualizado['fechaFinRecurrencia'];
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
    if (!_esParteDeSerieRecurrente(movimiento)) return 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar movimiento recurrente'),
        content: const Text('¿Qué quieres borrar?'),
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
    final esSerie = _esParteDeSerieRecurrente(movimiento);
    if (!esSerie) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Eliminar movimiento'),
          content: const Text('¿Seguro que quieres eliminar este movimiento?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => movimientos.removeWhere((m) => m['id']?.toString() == movimiento['id']?.toString()));
      await guardarDatos();
      return;
    }

    final alcance = await preguntarAlcanceEliminacionRecurrente(movimiento);
    if (alcance == null || !mounted) return;

    final id = movimiento['id']?.toString() ?? '';
    final rootId = _idRaizSerieRecurrente(movimiento);
    final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');

    if (alcance == 3) {
      try {
        await _confirmarBorradoTodaSerie(movimiento, rootId, fecha);
      } on _CancelRecurrenceAction {
        return;
      }
      setState(() {
        movimientos.removeWhere((m) => m['id']?.toString() == rootId || m['recurrenceId']?.toString() == rootId);
      });
      await guardarDatos();
      return;
    }

    if (alcance == 1) {
      // Solo esta entrada: se elimina exclusivamente el mes seleccionado.
      // Si la entrada seleccionada ES la raíz de la serie, no podemos
      // eliminarla sin más porque entonces desaparecería la plantilla que
      // genera las futuras. Promovemos la siguiente entrada futura a nueva
      // raíz y mantenemos toda la serie enlazada a ella.
      final raiz = _raizSerie(movimiento);

      if (raiz != null && raiz['id']?.toString() == id) {
        final futuras = _entradasSerie(rootId)
            .where((m) => m['id']?.toString() != id)
            .where((m) {
          final f = convertirFecha(m['fecha']?.toString() ?? '');
          return f.year != 1900 && f.isAfter(fecha);
        })
            .toList()
          ..sort((a, b) => convertirFecha(a['fecha']?.toString() ?? '')
              .compareTo(convertirFecha(b['fecha']?.toString() ?? '')));

        if (futuras.isNotEmpty) {
          final nuevaRaiz = futuras.first;
          final nuevaRaizId = nuevaRaiz['id']?.toString();

          if (nuevaRaizId != null && nuevaRaizId.isNotEmpty) {
            // La nueva raíz conserva la plantilla original de la serie.
            final datosPlantilla = Map<String, dynamic>.from(raiz);
            final intervalo =
            ((raiz['intervaloMeses'] as num?)?.toInt() ?? 1).clamp(1, 120);
            _guardarPlantillaEnRaiz(nuevaRaiz, datosPlantilla, intervalo);
            nuevaRaiz['recurrenceStartDate'] = nuevaRaiz['fecha'];
            nuevaRaiz['recurrenciasOmitidas'] = <String>[];

            // Todas las demás entradas pasan a apuntar a la nueva raíz.
            for (final m in movimientos) {
              if (m['id']?.toString() == id) continue;
              final pertenece = m['recurrenceId']?.toString() == rootId ||
                  m['id']?.toString() == nuevaRaizId;
              if (pertenece && m['id']?.toString() != nuevaRaizId) {
                m['recurrenceId'] = nuevaRaizId;
              }
            }

            // La entrada seleccionada (la antigua raíz) desaparece.
            movimientos.removeWhere((m) => m['id']?.toString() == id);
          }
        } else {
          // Caso excepcional: no quedan futuras entradas. Eliminamos la raíz
          // y no dejamos una plantilla huérfana que pueda regenerar la serie.
          movimientos.removeWhere((m) => m['id']?.toString() == id);
        }
      } else {
        // Una repetición normal no es la plantilla: simplemente se elimina
        // esa fecha y se registra como omitida para que no vuelva a aparecer.
        if (raiz != null) {
          final omitidas =
          List<String>.from(raiz['recurrenciasOmitidas'] ?? const []);
          final f = fechaTexto(fecha);
          if (!omitidas.contains(f)) omitidas.add(f);
          raiz['recurrenciasOmitidas'] = omitidas;
        }
        movimientos.removeWhere((m) => m['id']?.toString() == id);
      }

      await guardarDatos();
      await generarRecurrentesPendientes();
      return;
    }

    // Esta y las siguientes: se corta la serie justo en el mes seleccionado.
    // Todo lo anterior permanece exactamente como estaba.
    final raiz = _raizSerie(movimiento);
    if (raiz != null) {
      _limpiarMetadatosRecurrencia(raiz);
    }
    setState(() {
      movimientos.removeWhere((m) {
        final pertenece = m['id']?.toString() == rootId || m['recurrenceId']?.toString() == rootId;
        if (!pertenece) return false;
        final f = convertirFecha(m['fecha']?.toString() ?? '');
        return !f.isBefore(fecha);
      });
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

  // Los históricos se muestran en Inicio y Calendario como movimientos virtuales
  // con fecha 1 de cada mes. Siguen almacenados en `historicos`, separados de
  // los movimientos normales, pero se pueden editar desde cualquier vista.
  List<Map<String, dynamic>> movimientosHistoricosDelMes(DateTime mes) {
    final resultado = <Map<String, dynamic>>[];
    for (final h in historicos) {
      final anio = (h['anio'] as num?)?.toInt();
      final mesHistorico = (h['mes'] as num?)?.toInt();
      if (anio != mes.year || mesHistorico != mes.month) continue;

      for (final clave in ['ingresos', 'gastos']) {
        final lista = h[clave];
        if (lista is! List) continue;
        for (var i = 0; i < lista.length; i++) {
          final itemRaw = lista[i];
          if (itemRaw is! Map) continue;
          final item = Map<String, dynamic>.from(itemRaw);
          item['tipo'] = clave == 'ingresos' ? 'Ingreso' : 'Gasto';
          item['cantidad'] = ((item['importe'] as num?) ?? (item['cantidad'] as num?) ?? 0).toDouble();
          item['fecha'] = fechaTexto(DateTime(mes.year, mes.month, 1));
          item['fechaCreacion'] = item['fecha'];
          item['esHistorico'] = true;
          item['historicoAnio'] = anio;
          item['historicoMes'] = mesHistorico;
          item['historicoTipo'] = clave;
          item['historicoIndice'] = i;
          item['id'] = 'historico_${anio}_${mesHistorico}_${clave}_$i';
          resultado.add(item);
        }
      }
    }
    resultado.sort(compararMovimientosPorFechaHoraDesc);
    return resultado;
  }

  List<Map<String, dynamic>> todosLosMovimientosConHistoricos() {
    final resultado = <Map<String, dynamic>>[...movimientos];
    for (final h in historicos) {
      final anio = (h['anio'] as num?)?.toInt();
      final mesHistorico = (h['mes'] as num?)?.toInt();
      if (anio == null || mesHistorico == null) continue;
      resultado.addAll(movimientosHistoricosDelMes(DateTime(anio, mesHistorico, 1)));
    }
    return resultado;
  }

  Future<void> editarMovimientoHistorico(Map<String, dynamic> original) async {
    final anio = (original['historicoAnio'] as num?)?.toInt();
    final mes = (original['historicoMes'] as num?)?.toInt();
    final indice = (original['historicoIndice'] as num?)?.toInt();
    final clave = original['historicoTipo']?.toString();
    if (anio == null || mes == null || indice == null || (clave != 'ingresos' && clave != 'gastos')) return;

    final historico = historicos.cast<Map<String, dynamic>?>().firstWhere(
          (h) => h?['anio']?.toString() == anio.toString() && h?['mes']?.toString() == mes.toString(),
      orElse: () => null,
    );
    if (historico == null) return;
    final lista = historico[clave];
    if (lista is! List || indice >= lista.length || lista[indice] is! Map) return;

    final originalItem = Map<String, dynamic>.from(lista[indice] as Map);
    final tipo = clave == 'ingresos' ? 'Ingreso' : 'Gasto';
    final cantidadController = TextEditingController(
      text: (((originalItem['importe'] as num?) ?? (originalItem['cantidad'] as num?) ?? 0).toDouble()).toStringAsFixed(2),
    );
    String? categoria = originalItem['categoria']?.toString();
    String? subcategoria = originalItem['subcategoria']?.toString();
    String? subsubcategoria = originalItem['subsubcategoria']?.toString();
    final notaController = TextEditingController(text: originalItem['nota']?.toString() ?? '');

    final categorias = tipo == 'Gasto' ? categoriasGastos : categoriasIngresos;
    if (categoria == null || !categorias.any((c) => c['nombre']?.toString() == categoria)) {
      categoria = categorias.isNotEmpty ? categorias.first['nombre']?.toString() : null;
    }

    String? primerSub(String? cat) {
      final c = categorias.cast<Map<String, dynamic>?>().firstWhere((x) => x?['nombre']?.toString() == cat, orElse: () => null);
      final subs = List<String>.from(c?['subcategorias'] ?? []);
      return subs.isNotEmpty ? subs.first : null;
    }
    String? primerSs(String? cat, String? sub) {
      final c = categorias.cast<Map<String, dynamic>?>().firstWhere((x) => x?['nombre']?.toString() == cat, orElse: () => null);
      final mapa = Map<String, dynamic>.from(c?['subsubcategorias'] ?? {});
      final lista = List<String>.from(mapa[sub] ?? []);
      return lista.isNotEmpty ? lista.first : null;
    }

    if (categoria != null) {
      final c = categorias.cast<Map<String, dynamic>?>().firstWhere((x) => x?['nombre']?.toString() == categoria, orElse: () => null);
      final subs = List<String>.from(c?['subcategorias'] ?? []);
      if (subcategoria == null || !subs.contains(subcategoria)) subcategoria = subs.isNotEmpty ? subs.first : null;
      final mapa = Map<String, dynamic>.from(c?['subsubcategorias'] ?? {});
      final ss = List<String>.from(mapa[subcategoria] ?? []);
      if (subsubcategoria == null || !ss.contains(subsubcategoria)) subsubcategoria = ss.isNotEmpty ? ss.first : null;
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final c = categorias.cast<Map<String, dynamic>?>().firstWhere((x) => x?['nombre']?.toString() == categoria, orElse: () => null);
            final subs = List<String>.from(c?['subcategorias'] ?? []);
            final mapaSs = Map<String, dynamic>.from(c?['subsubcategorias'] ?? {});
            final ss = List<String>.from(mapaSs[subcategoria] ?? []);
            return AlertDialog(
              title: Text('Editar histórico · ${nombreMes(DateTime(anio, mes, 1))} $anio'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: cantidadController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Importe', suffixText: '€', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoria,
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    items: categorias.map((c) => DropdownMenuItem<String>(value: c['nombre']?.toString(), child: Text(c['nombre']?.toString() ?? ''))).toList(),
                    onChanged: (v) => setDialogState(() {
                      categoria = v;
                      subcategoria = primerSub(v);
                      subsubcategoria = primerSs(v, subcategoria);
                    }),
                  ),
                  if (subs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: subs.contains(subcategoria) ? subcategoria : null,
                      decoration: const InputDecoration(labelText: 'Subcategoría', border: OutlineInputBorder()),
                      items: subs.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() {
                        subcategoria = v;
                        subsubcategoria = primerSs(categoria, v);
                      }),
                    ),
                  ],
                  if (ss.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ss.contains(subsubcategoria) ? subsubcategoria : null,
                      decoration: const InputDecoration(labelText: 'Tipo de gasto', border: OutlineInputBorder()),
                      items: ss.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setDialogState(() => subsubcategoria = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notaController,
                    decoration: const InputDecoration(labelText: 'Nota', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text('Fecha: 1 de ${nombreMes(DateTime(anio, mes, 1))} $anio', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );

    if (guardar == true) {
      final valor = double.tryParse(cantidadController.text.trim().replaceAll(',', '.')) ?? 0;
      final nuevo = Map<String, dynamic>.from(originalItem);
      nuevo['importe'] = valor;
      nuevo['cantidad'] = valor;
      nuevo['categoria'] = categoria;
      nuevo['subcategoria'] = subcategoria;
      if (subsubcategoria == null || subsubcategoria!.isEmpty) {
        nuevo.remove('subsubcategoria');
      } else {
        nuevo['subsubcategoria'] = subsubcategoria;
      }
      nuevo['nota'] = notaController.text.trim();

      // Actualizar IDs usando la estructura actual de categorías.
      final listaCategorias = tipo == 'Gasto' ? categoriasGastos : categoriasIngresos;
      final c = listaCategorias.cast<Map<String, dynamic>?>().firstWhere((x) => x?['nombre']?.toString() == categoria, orElse: () => null);
      if (c != null) {
        nuevo['categoriaId'] = c['id'];
        final subIds = Map<String, dynamic>.from(c['subcategoriaIds'] ?? {});
        if (subcategoria != null) nuevo['subcategoriaId'] = subIds[subcategoria];
        final ssIds = Map<String, dynamic>.from(c['subsubcategoriaIds'] ?? {});
        if (subcategoria != null && subsubcategoria != null) {
          nuevo['subsubcategoriaId'] = Map<String, dynamic>.from(ssIds[subcategoria] ?? {})[subsubcategoria];
        } else {
          nuevo.remove('subsubcategoriaId');
        }
      }
      lista[indice] = nuevo;
      await guardarDatos();
      if (mounted) setState(() {});
    }

    cantidadController.dispose();
    notaController.dispose();
  }

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

    resultado.addAll(movimientosHistoricosDelMes(mes));
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
    final normales = movimientos
        .where((m) {
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      final mismoAno = fecha.year == ano;
      final hastaHoy = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1)));
      return mismoAno && hastaHoy && m['tipo'] == 'Ingreso';
    })
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
    final historicosAno = historicos.where((h) => (h['anio'] as num?)?.toInt() == ano).fold(0.0, (total, h) =>
    total + ((h['ingresos'] as List?) ?? const []).fold(0.0, (s, item) => s + (((item as Map)['importe'] as num?) ?? 0).toDouble()));
    return normales + historicosAno;
  }

  double gastosAno(int ano) {
    final hoy = DateTime.now();
    final normales = movimientos
        .where((m) {
      final fecha = convertirFecha(m['fecha']?.toString() ?? '');
      final mismoAno = fecha.year == ano;
      final hastaHoy = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1)));
      return mismoAno && hastaHoy && m['tipo'] == 'Gasto';
    })
        .fold(0.0, (total, m) => total + ((m['cantidad'] as num?) ?? 0).toDouble());
    final historicosAno = historicos.where((h) => (h['anio'] as num?)?.toInt() == ano).fold(0.0, (total, h) =>
    total + ((h['gastos'] as List?) ?? const []).fold(0.0, (s, item) => s + (((item as Map)['importe'] as num?) ?? 0).toDouble()));
    return normales + historicosAno;
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
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
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

    // Un único recorrido de movimientos para construir Inicio. La versión
    // anterior recorría la lista varias veces (mes + ingresos + gastos +
    // balance anual), algo costoso con decenas de miles de movimientos.
    final movimientosMes = <Map<String, dynamic>>[];
    double ingresos = 0;
    double gastos = 0;
    double ajustes = 0;
    double ingresosAnoSeleccionado = 0;
    double gastosAnoSeleccionado = 0;
    double ajustesAnoSeleccionado = 0;

    for (final movimiento in movimientos) {
      final fecha = convertirFecha(movimiento['fecha']?.toString() ?? '');
      if (fecha.year == 1900) continue;

      final esMes = fecha.year == mesSeleccionado.year &&
          fecha.month == mesSeleccionado.month;
      final ocurrio = !fecha.isAfter(inicioHoy);
      final esAno = fecha.year == mesSeleccionado.year &&
          fecha.isBefore(finHoy);

      if (esMes) {
        movimientosMes.add(movimiento);
        if (ocurrio) {
          final cantidad = ((movimiento['cantidad'] as num?) ?? 0).toDouble();
          if (movimiento['tipo'] == 'Ingreso') ingresos += cantidad;
          if (movimiento['tipo'] == 'Gasto') gastos += cantidad;
          if (movimiento['tipo'] == 'Ajuste') ajustes += cantidad;
        }
      }

      if (esAno && ocurrio) {
        final cantidad = ((movimiento['cantidad'] as num?) ?? 0).toDouble();
        if (movimiento['tipo'] == 'Ingreso') ingresosAnoSeleccionado += cantidad;
        if (movimiento['tipo'] == 'Gasto') gastosAnoSeleccionado += cantidad;
        if (movimiento['tipo'] == 'Ajuste') ajustesAnoSeleccionado += cantidad;
      }
    }

    // Los históricos son virtuales y solo se añaden al mes/año que corresponde.
    final historicosMes = movimientosHistoricosDelMes(mesSeleccionado);
    movimientosMes.addAll(historicosMes);
    for (final historico in historicosMes) {
      final cantidad = ((historico['cantidad'] as num?) ?? 0).toDouble();
      if (historico['tipo'] == 'Ingreso') {
        ingresos += cantidad;
        ingresosAnoSeleccionado += cantidad;
      } else if (historico['tipo'] == 'Gasto') {
        gastos += cantidad;
        gastosAnoSeleccionado += cantidad;
      }
    }

    for (final h in historicos) {
      final anio = (h['anio'] as num?)?.toInt();
      if (anio != mesSeleccionado.year) continue;
      final listaIngresos = (h['ingresos'] as List?) ?? const [];
      final listaGastos = (h['gastos'] as List?) ?? const [];
      // Los elementos de historicosMes ya están incluidos arriba para el mes
      // seleccionado; aquí añadimos solamente los otros meses del mismo año.
      final mesHistorico = (h['mes'] as num?)?.toInt();
      if (mesHistorico == mesSeleccionado.month) continue;
      for (final item in listaIngresos) {
        if (item is Map) ingresosAnoSeleccionado +=
            ((item['importe'] as num?) ?? 0).toDouble();
      }
      for (final item in listaGastos) {
        if (item is Map) gastosAnoSeleccionado +=
            ((item['importe'] as num?) ?? 0).toDouble();
      }
    }

    final balanceMesCalculado = ingresos - gastos + ajustes;
    final balanceAnoCalculado =
        ingresosAnoSeleccionado - gastosAnoSeleccionado + ajustesAnoSeleccionado;

    final movimientosMesFiltrados = _filtroMovimientosInicio == null
        ? movimientosMes
        : movimientosMes
        .where((m) => m['tipo'] == _filtroMovimientosInicio)
        .toList();

    final listaBase = movimientosMesFiltrados.where((m) {
      final tipo = m['tipo'];
      if (tipo != 'Gasto' && tipo != 'Ingreso' && tipo != 'Ajuste') {
        return false;
      }
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isBefore(inicioMesSeleccionado) && f.isBefore(finMesSeleccionado);
    }).toList();

    final movimientosRecientes = listaBase.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      return !f.isAfter(inicioHoy);
    }).toList()
      ..sort(compararMovimientosPorFechaHoraDesc);

    final movimientosProximos = listaBase.where((m) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      if (!f.isAfter(inicioHoy)) return false;
      if (esMesActual && m['recurrente'] == true) return false;
      return true;
    }).toList()
      ..sort(compararMovimientosPorFechaHoraAsc);

    final listaBaseMovimientos = _mostrarProximosMovimientos
        ? movimientosProximos
        : movimientosRecientes;

    final movimientosMostrados = listaBaseMovimientos
        .take(_limiteMovimientosInicio)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'PastApp',
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: abrirBuscador,
          ),
        ],
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
                      onDoubleTap: kIsWeb ? nuevaCorreccion : null,
                      onLongPress: kIsWeb ? null : nuevaCorreccion,
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
                TextButton(
                  onPressed: () {
                    final ahora = DateTime.now();
                    setState(() {
                      mesSeleccionado = DateTime(ahora.year, ahora.month, 1);
                    });
                  },
                  child: const Text('Hoy'),
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
                    balanceMesCalculado,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: resumenIcono(
                    Icons.calendar_today,
                    'Balance año ${mesSeleccionado.year}',
                    balanceAnoCalculado,
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
              final partesCategoria = <String>[
                if ((movimiento['categoria']?.toString() ?? '').isNotEmpty)
                  movimiento['categoria'].toString(),
                if ((movimiento['subcategoria']?.toString() ?? '').isNotEmpty)
                  movimiento['subcategoria'].toString(),
                if ((movimiento['subsubcategoria']?.toString() ?? '').isNotEmpty)
                  movimiento['subsubcategoria'].toString(),
              ];

              final subtitulo = [
                movimiento['fecha']?.toString() ?? '',
                if (partesCategoria.isNotEmpty)
                  partesCategoria.join(' · '),
                if (movimiento['nota']?.toString().trim().isNotEmpty ?? false)
                  '📝 ${movimiento['nota'].toString().trim()}',
                if (movimiento['fotoPath']?.toString().trim().isNotEmpty ?? false)
                  '📷',
                if (pendiente) '⏳ cambio pendiente',
              ].where((e) => e.isNotEmpty).join(' · ');

              final textoImporte = pendiente
                  ? '${esGasto ? '-' : '+'}${cantidadOriginal.toStringAsFixed(2).replaceAll('.', ',')} $monedaMovimiento'
                  : '${esAjuste ? (cantidad >= 0 ? '+' : '') : (esGasto ? '-' : '+')}${formatearEuros(cantidad.abs())}';

              Timer? temporizadorMantener;

              return Card(
                child: GestureDetector(
                  onTap: () => mostrarDetalleMovimiento(movimiento),
                  onLongPressDown: kIsWeb
                      ? null
                      : (_) {
                    temporizadorMantener?.cancel();
                    temporizadorMantener = Timer(
                      const Duration(milliseconds: 650),
                          () async {
                        await HapticFeedback.lightImpact();
                        if (mounted) {
                          await Future.delayed(const Duration(milliseconds: 90));
                          if (mounted) {
                            await mostrarOpcionesMovimiento(movimiento);
                          }
                        }
                      },
                    );
                  },
                  onLongPressCancel: kIsWeb
                      ? null
                      : () => temporizadorMantener?.cancel(),
                  onLongPressEnd: kIsWeb
                      ? null
                      : (_) => temporizadorMantener?.cancel(),
                  onDoubleTap: kIsWeb
                      ? () => mostrarOpcionesMovimiento(movimiento)
                      : null,
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
            if (listaBaseMovimientos.length > movimientosMostrados.length)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _limiteMovimientosInicio += 12;
                    }),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Cargar más movimientos'),
                  ),
                ),
              ),
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
    if (movimiento['esHistorico'] == true) {
      await editarMovimientoHistorico(movimiento);
    } else if (movimiento['tipo'] == 'Ajuste') {
      await editarAjuste(movimiento);
    } else {
      await editarMovimiento(movimiento);
    }
  }

  Future<void> abrirBuscador() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorMovimientosPage(
          movimientos: movimientos,
          categoriasGastos: categoriasGastos,
          categoriasIngresos: categoriasIngresos,
          onMovimientoTap: mostrarDetalleMovimiento,
        ),
      ),
    );
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
          movimientos: todosLosMovimientosConHistoricos(),
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
        return SeguimientoInmueblesPage(
          inmuebles: seguimientoInmuebles,
          movimientos: movimientos,
          onChanged: (datos) async {
            setState(() => seguimientoInmuebles = datos);
            await guardarDatos();
          },
          onMovimientosChanged: () async {
            setState(() {});
            await guardarDatos();
          },
        );
      case 4:
        return DeudasPage(
          deudas: deudas,
          onChanged: (datos) async {
            setState(() => deudas = datos);
            await guardarDatos();
          },
        );
      case 5:
        return InversionesPage(
          inversiones: inversiones,
          onChanged: (datos) async {
            setState(() => inversiones = datos);
            await guardarDatos();
          },
        );
      case 6:
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
          googleUsuario: _firebase.usuario?.email,
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
                    child: Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
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
            _botonNavegacionWeb(indice: 3, icono: Icons.home_work_outlined, iconoSeleccionado: Icons.home_work, texto: 'Inmuebles'),
            _botonNavegacionWeb(indice: 4, icono: Icons.account_balance_outlined, iconoSeleccionado: Icons.account_balance, texto: 'Deudas'),
            _botonNavegacionWeb(indice: 5, icono: Icons.trending_up_outlined, iconoSeleccionado: Icons.trending_up, texto: 'Inversiones'),
            _botonNavegacionWeb(indice: 6, icono: Icons.settings_outlined, iconoSeleccionado: Icons.settings, texto: 'Ajustes'),
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
        index: paginaActual > 6 ? 0 : paginaActual,
        children: [
          pantallaInicio(),
          Calendario(
            movimientos: todosLosMovimientosConHistoricos(),
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
          SeguimientoInmueblesPage(
            inmuebles: seguimientoInmuebles,
            movimientos: movimientos,
            onChanged: (datos) async {
              setState(() => seguimientoInmuebles = datos);
              await guardarDatos();
            },
            onMovimientosChanged: () async {
              setState(() {});
              await guardarDatos();
            },
          ),
          DeudasPage(
            deudas: deudas,
            onChanged: (datos) async {
              setState(() => deudas = datos);
              await guardarDatos();
            },
          ),
          InversionesPage(
            inversiones: inversiones,
            onChanged: (datos) async {
              setState(() => inversiones = datos);
              await guardarDatos();
            },
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
            googleUsuario: _firebase.usuario?.email,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirNuevoMovimiento(tipoInicial: 'Gasto'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: paginaActual > 6 ? 0 : paginaActual,
        onDestinationSelected: (index) {
          setState(() => paginaActual = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Estadísticas'),
          NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work), label: 'Inmuebles'),
          NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: 'Deudas'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Inversiones'),
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
  String? subsubcategoria;

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
  DateTime? fechaFinRecurrencia;

  String? fotoPath;

  final cantidadController = TextEditingController();
  final monedaController = TextEditingController(text: 'EUR');
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
      subsubcategoria = existente['subsubcategoria']?.toString();

      moneda = existente['moneda']?.toString() ?? 'EUR';
      monedaController.text = moneda;
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
      final finExistente = convertirFecha(
        existente['fechaFinRecurrencia']?.toString() ??
            existente['plantillaFechaFinRecurrencia']?.toString() ??
            '',
      );
      fechaFinRecurrencia = finExistente.year == 1900 ? null : finExistente;

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

  void actualizarMonedaDesdeTexto(String texto) {
    final consulta = texto.trim().toUpperCase();
    if (consulta.isEmpty) return;

    final coincidencias = monedasDisponibles.where((m) {
      final codigo = m['codigo']!.toUpperCase();
      final nombre = m['nombre']!.toUpperCase();
      final pais = m['pais']!.toUpperCase();
      return codigo.startsWith(consulta) ||
          nombre.startsWith(consulta) ||
          pais.startsWith(consulta);
    }).toList();

    if (coincidencias.length == 1 && consulta.length >= 2) {
      final codigo = coincidencias.first['codigo']!;
      moneda = codigo;
      if (monedaController.text != codigo) {
        monedaController.value = TextEditingValue(
          text: codigo,
          selection: TextSelection.collapsed(offset: codigo.length),
        );
      }
      if (mounted) setState(() {});
    } else if (monedasDisponibles.any(
            (m) => m['codigo']!.toUpperCase() == consulta)) {
      moneda = consulta;
      if (mounted) setState(() {});
    }
  }

  void confirmarTextoMoneda() {
    final consulta = monedaController.text.trim().toUpperCase();
    if (consulta.isEmpty) {
      moneda = 'EUR';
      monedaController.text = 'EUR';
      return;
    }

    final exacta = monedasDisponibles.where(
          (m) => m['codigo']!.toUpperCase() == consulta,
    );
    if (exacta.isNotEmpty) {
      moneda = exacta.first['codigo']!;
      monedaController.text = moneda;
      return;
    }

    final coincidencias = monedasDisponibles.where((m) {
      final codigo = m['codigo']!.toUpperCase();
      final nombre = m['nombre']!.toUpperCase();
      final pais = m['pais']!.toUpperCase();
      return codigo.startsWith(consulta) ||
          nombre.startsWith(consulta) ||
          pais.startsWith(consulta);
    }).toList();

    if (coincidencias.length == 1) {
      moneda = coincidencias.first['codigo']!;
      monedaController.text = moneda;
    } else {
      monedaController.text = moneda;
    }
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

    moneda = seleccion;
    monedaController.text = seleccion;
    if (mounted) setState(() {});
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
    monedaController.dispose();
    intervaloController.dispose();
    notaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>
  get categorias {
    final lista = List<Map<String, dynamic>>.from(
      tipo == 'Ingreso'
          ? widget.categoriasIngresos
          : widget.categoriasGastos,
    );

    lista.sort(
          (a, b) => (a['nombre']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['nombre']?.toString() ?? '').toLowerCase()),
    );

    return lista;
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

  List<String> get subsubcategorias {
    final actual = categoriaActual;
    if (actual == null || subcategoria == null) return [];
    final mapa = Map<String, dynamic>.from(actual['subsubcategorias'] ?? {});
    final configuradas = List<String>.from(mapa[subcategoria] ?? const []);

    // Pisos tiene una estructura fija de tres niveles. Si una copia antigua
    // o una sincronización deja temporalmente vacío el mapa de un inmueble,
    // no ocultamos los tipos de gasto: los reconstruimos de forma segura.
    if (actual['nombre']?.toString() == 'Pisos' && configuradas.isEmpty &&
        subcategoria != 'Otros') {
      return const [
        'IBI',
        'Comunidad',
        'Electrodomésticos',
        'Seguro hogar',
        'Obras',
        'Mantenimiento',
        'Otros',
      ];
    }

    return configuradas;
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
      subsubcategoria = null;
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
      subsubcategoria = null;
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
    confirmarTextoMoneda();
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
    confirmarTextoMoneda();
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
      'categoriaId': categoriaActual?['id'],

      'subcategoria':
      subcategoria,
      'subcategoriaId': subcategoria == null ? null : Map<String, String>.from(categoriaActual?['subcategoriaIds'] ?? {})[subcategoria],
      'subsubcategoria': subsubcategoria,
      'subsubcategoriaId': subsubcategoria == null ? null : Map<String, String>.from((categoriaActual?['subsubcategoriaIds'] ?? {})[subcategoria] ?? {})[subsubcategoria],

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
      'plantillaSubsubcategoria': recurrente ? subsubcategoria : null,
      'plantillaEmoji': recurrente ? emoji : null,
      'plantillaNota': recurrente ? notaController.text.trim() : null,
      'plantillaFotoPath': recurrente ? fotoPath : null,
      'plantillaIntervaloMeses': recurrente ? ((int.tryParse(intervaloController.text.trim()) ?? intervaloMeses).clamp(1, 120)) : null,
      'fechaFinRecurrencia': recurrente && fechaFinRecurrencia != null
          ? fechaTexto(fechaFinRecurrencia!)
          : null,
      'plantillaFechaFinRecurrencia': recurrente && fechaFinRecurrencia != null
          ? fechaTexto(fechaFinRecurrencia!)
          : null,

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
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => seleccionarTipo('Gasto'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tipo == 'Gasto' ? Colors.red.withValues(alpha: 0.16) : Colors.transparent,
                          border: Border.all(
                            color: tipo == 'Gasto' ? Colors.red : Colors.grey.shade500,
                            width: tipo == 'Gasto' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Gasto', style: TextStyle(fontWeight: FontWeight.w600, color: tipo == 'Gasto' ? Colors.red : null)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => seleccionarTipo('Ingreso'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tipo == 'Ingreso' ? Colors.green.withValues(alpha: 0.16) : Colors.transparent,
                          border: Border.all(
                            color: tipo == 'Ingreso' ? Colors.green : Colors.grey.shade500,
                            width: tipo == 'Ingreso' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Ingreso', style: TextStyle(fontWeight: FontWeight.w600, color: tipo == 'Ingreso' ? Colors.green : null)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final ancho = constraints.maxWidth;
                  final columnas = ancho >= 900 ? 7 : (ancho >= 600 ? 6 : 4);
                  final anchoCelda = (ancho - ((columnas - 1) * 8)) / columnas;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categorias.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 82,
                    ),
                    itemBuilder: (context, index) {
                      final c = categorias[index];
                      final nombre = c['nombre']?.toString() ?? '';
                      final seleccionado = categoria == nombre;

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (seleccionado) {
                            setState(() {
                              categoria = null;
                              subcategoria = null;
                              subsubcategoria = null;
                              paso = 1;
                            });
                          } else {
                            seleccionarCategoria(c);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: anchoCelda.clamp(52.0, 78.0),
                              height: 54,
                              decoration: BoxDecoration(
                                color: seleccionado
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: seleccionado
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                  width: seleccionado ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c['emoji']?.toString() ?? '💰',
                                style: const TextStyle(fontSize: 27),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              if (categoria != null && subcategorias.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  categoria == 'Pisos' ? 'Inmueble' : 'Subcategoría',
                  style: const TextStyle(
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
                        onSelected: (_) {
                          setState(() {
                            if (subcategoria == s) {
                              subcategoria = null;
                              subsubcategoria = null;
                            } else {
                              subcategoria = s;
                              subsubcategoria = null;
                            }
                          });
                        },
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
              if (subcategoria != null && subsubcategorias.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  categoria == 'Pisos' ? 'Tipo de gasto' : 'Detalle',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subsubcategorias.map((s) => ChoiceChip(
                    label: Text(s),
                    selected: subsubcategoria == s,
                    onSelected: (_) {
                      setState(() {
                        subsubcategoria = subsubcategoria == s ? null : s;
                      });
                    },
                  )).toList(),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 105,
                    child: TextField(
                      controller: monedaController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      onChanged: actualizarMonedaDesdeTexto,
                      onSubmitted: (_) => confirmarTextoMoneda(),
                      decoration: InputDecoration(
                        labelText: 'Moneda',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Buscar moneda',
                          icon: const Icon(Icons.search, size: 20),
                          onPressed: buscarYAnadirMoneda,
                        ),
                      ),
                    ),
                  ),
                ],
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                    if (recurrente)
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Finalizar recurrencia'),
                        subtitle: Text(
                          fechaFinRecurrencia == null
                              ? 'Sin fecha de finalización'
                              : fechaTexto(fechaFinRecurrencia!),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fechaFinRecurrencia != null)
                              IconButton(
                                tooltip: 'Quitar fecha de finalización',
                                onPressed: () => setState(() => fechaFinRecurrencia = null),
                                icon: const Icon(Icons.clear),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () async {
                          final inicial = fechaFinRecurrencia ??
                              DateTime(fecha.year + 1, fecha.month, fecha.day);
                          final d = await showDatePicker(
                            context: context,
                            initialDate: inicial.isBefore(fecha) ? fecha : inicial,
                            firstDate: fecha,
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => fechaFinRecurrencia = d);
                        },
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
// BUSCADOR DE MOVIMIENTOS
// ============================================================

class BuscadorMovimientosPage extends StatefulWidget {
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> categoriasGastos;
  final List<Map<String, dynamic>> categoriasIngresos;
  final Future<void> Function(Map<String, dynamic>) onMovimientoTap;

  const BuscadorMovimientosPage({
    super.key,
    required this.movimientos,
    required this.categoriasGastos,
    required this.categoriasIngresos,
    required this.onMovimientoTap,
  });

  @override
  State<BuscadorMovimientosPage> createState() => _BuscadorMovimientosPageState();
}

class _BuscadorMovimientosPageState extends State<BuscadorMovimientosPage> {
  final TextEditingController palabraController = TextEditingController();
  final TextEditingController menorController = TextEditingController();
  final TextEditingController mayorController = TextEditingController();
  final TextEditingController entreDesdeController = TextEditingController();
  final TextEditingController entreHastaController = TextEditingController();

  String? tipo;
  String? categoria;
  String? subcategoria;

  List<String> get categorias {
    final todas = <String>{};
    for (final m in widget.movimientos) {
      final c = m['categoria']?.toString().trim() ?? '';
      if (c.isNotEmpty) todas.add(c);
    }
    return todas.toList()..sort();
  }

  List<String> get subcategorias {
    final todas = <String>{};
    for (final m in widget.movimientos) {
      if (categoria != null && categoria!.isNotEmpty && m['categoria']?.toString() != categoria) continue;
      final s = m['subcategoria']?.toString().trim() ?? '';
      if (s.isNotEmpty) todas.add(s);
    }
    return todas.toList()..sort();
  }

  double? numero(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  bool coincide(Map<String, dynamic> m) {
    if (tipo != null && m['tipo']?.toString() != tipo) return false;
    if (categoria != null && m['categoria']?.toString() != categoria) return false;
    if (subcategoria != null && m['subcategoria']?.toString() != subcategoria) return false;

    final q = palabraController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final texto = [
        m['tipo'],
        m['categoria'],
        m['subcategoria'],
        m['nota'],
        m['fecha'],
        m['moneda'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();
      if (!texto.contains(q)) return false;
    }

    final cantidad = ((m['cantidad'] as num?) ?? 0).toDouble().abs();
    final menor = numero(menorController);
    final mayor = numero(mayorController);
    final desde = numero(entreDesdeController);
    final hasta = numero(entreHastaController);

    if (menor != null && cantidad >= menor) return false;
    if (mayor != null && cantidad <= mayor) return false;
    if (desde != null && cantidad < desde) return false;
    if (hasta != null && cantidad > hasta) return false;

    return true;
  }

  List<Map<String, dynamic>> get resultados {
    final lista = widget.movimientos.where(coincide).toList();
    lista.sort(compararMovimientosPorFechaHoraDesc);
    return lista;
  }

  @override
  void dispose() {
    palabraController.dispose();
    menorController.dispose();
    mayorController.dispose();
    entreDesdeController.dispose();
    entreHastaController.dispose();
    super.dispose();
  }

  Widget campoImporte(String etiqueta, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixText: '€ ',
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaSub = subcategorias;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar movimientos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: palabraController,

                  decoration: const InputDecoration(
                    labelText: 'Palabra',
                    hintText: 'Categoría, nota, fecha, moneda…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                          DropdownMenuItem<String?>(value: 'Gasto', child: Text('Gasto')),
                          DropdownMenuItem<String?>(value: 'Ingreso', child: Text('Ingreso')),
                        ],
                        onChanged: (v) => setState(() => tipo = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: categoria,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                          ...categorias.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                        ],
                        onChanged: (v) => setState(() {
                          categoria = v;
                          subcategoria = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: subcategoria,
                  decoration: const InputDecoration(
                    labelText: 'Subcategoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                    ...listaSub.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => subcategoria = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    campoImporte('Menor que', menorController),
                    const SizedBox(width: 8),
                    campoImporte('Mayor que', mayorController),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    campoImporte('Entre', entreDesdeController),
                    const SizedBox(width: 8),
                    campoImporte('y', entreHastaController),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${resultados.length} resultado${resultados.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: resultados.isEmpty
                ? const Center(child: Text('No se han encontrado movimientos'))
                : ListView.builder(
              itemCount: resultados.length,
              itemBuilder: (_, i) {
                final m = resultados[i];
                final gasto = m['tipo'] == 'Gasto';
                final ajuste = m['tipo'] == 'Ajuste';
                final cantidad = ((m['cantidad'] as num?) ?? 0).toDouble();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF1F1F1),
                    child: Text(m['emoji'] ?? (gasto ? '💸' : '💰')),
                  ),
                  title: Text(m['categoria']?.toString() ?? m['tipo']?.toString() ?? ''),
                  subtitle: Text([
                    m['fecha']?.toString() ?? '',
                    if ((m['subcategoria']?.toString() ?? '').isNotEmpty) m['subcategoria'].toString(),
                    if ((m['nota']?.toString().trim() ?? '').isNotEmpty) '📝 ${m['nota']}',
                  ].join(' · ')),
                  trailing: Text(
                    '${ajuste ? (cantidad >= 0 ? '+' : '') : (gasto ? '-' : '+')}${formatearEuros(cantidad.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ajuste ? Colors.orange : (gasto ? Colors.red : Colors.green),
                    ),
                  ),
                  onTap: () => widget.onMovimientoTap(m),
                );
              },
            ),
          ),
        ],
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
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuscadorMovimientosPage(
                    movimientos: widget.movimientos,
                    categoriasGastos: const [],
                    categoriasIngresos: const [],
                    onMovimientoTap: widget.onMovimientoTap,
                  ),
                ),
              );
            },
          ),
        ],
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
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () {
                    final hoy = DateTime.now();
                    setState(() {
                      mes = DateTime(hoy.year, hoy.month, 1);
                    });
                  },
                  child: const Text('Hoy'),
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

                        Timer? temporizadorMantener;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 120), () {
                              if (mounted) {
                                widget.onMovimientoTap(m);
                              }
                            });
                          },
                          onLongPressDown: kIsWeb
                              ? null
                              : (_) {
                            temporizadorMantener?.cancel();
                            temporizadorMantener = Timer(
                              const Duration(milliseconds: 650),
                                  () async {
                                await HapticFeedback.lightImpact();
                                if (mounted) {
                                  await Future.delayed(const Duration(milliseconds: 90));
                                  if (mounted) {
                                    Navigator.pop(context);
                                    await Future.delayed(const Duration(milliseconds: 120));
                                    if (mounted) {
                                      await widget.onMovimientoLongPress(m);
                                    }
                                  }
                                }
                              },
                            );
                          },
                          onLongPressCancel: kIsWeb
                              ? null
                              : () => temporizadorMantener?.cancel(),
                          onLongPressEnd: kIsWeb
                              ? null
                              : (_) => temporizadorMantener?.cancel(),
                          onDoubleTap: kIsWeb
                              ? () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 120), () {
                              if (mounted) {
                                widget.onMovimientoLongPress(m);
                              }
                            });
                          }
                              : null,
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
  int anoSeleccionado = DateTime.now().year;

  List<int> get anosDisponibles {
    final anos = <int>{DateTime.now().year};
    for (final h in widget.historicos) {
      final a = (h['anio'] as num?)?.toInt();
      if (a != null) anos.add(a);
    }
    for (final m in widget.movimientos) {
      final f = convertirFecha(m['fecha']?.toString() ?? '');
      if (f.year > 1900) anos.add(f.year);
    }
    final lista = anos.toList()..sort();
    return lista;
  }

  List<Map<String, dynamic>> get movimientosFiltrados {
    final ahora = DateTime.now();
    late DateTime inicio;
    late DateTime fin;

    if (periodo == 'Semana') {
      inicio = DateTime(ahora.year, ahora.month, ahora.day - (ahora.weekday - 1));
      fin = inicio.add(const Duration(days: 7));
    } else if (periodo == 'Año') {
      inicio = DateTime(anoSeleccionado, 1, 1);
      fin = DateTime(anoSeleccionado + 1, 1, 1);
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

  List<Map<String, dynamic>> get historicosAno =>
      widget.historicos.where((h) => (h['anio'] as num?)?.toInt() == anoSeleccionado).toList();

  double cantidad(Map<String, dynamic> m) =>
      ((m['cantidad'] as num?) ?? 0).toDouble();

  double get historicoGastosPeriodo {
    if (periodo != 'Año') return 0;
    return historicosAno.fold(0.0, (t, h) =>
    t + ((h['totalGastos'] as num?) ?? 0).toDouble());
  }

  double get historicoIngresosPeriodo {
    if (periodo != 'Año') return 0;
    return historicosAno.fold(0.0, (t, h) =>
    t + ((h['totalIngresos'] as num?) ?? 0).toDouble());
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
      for (final h in historicosAno) {
        for (final item in List<Map<String, dynamic>>.from(
          (h['gastos'] ?? []).map((x) => Map<String, dynamic>.from(x)),
        )) {
          final categoria = item['categoria']?.toString() ?? 'Miscelánea';
          mapa[categoria] = (mapa[categoria] ?? 0) +
              ((item['importe'] as num?) ?? 0).toDouble();
        }
        for (final item in List<Map<String, dynamic>>.from(
          (h['inversiones'] ?? []).map((x) => Map<String, dynamic>.from(x)),
        )) {
          final categoria = item['categoria']?.toString() ?? 'Compra inmuebles';
          mapa[categoria] = (mapa[categoria] ?? 0) +
              ((item['importe'] as num?) ?? 0).toDouble();
        }
        final historico = ((h['gastosHistoricos'] as num?) ?? 0).toDouble();
        if (historico != 0) {
          mapa['Gastos históricos'] = (mapa['Gastos históricos'] ?? 0) + historico;
        }
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
      for (final h in historicosAno) {
        for (final item in List<Map<String, dynamic>>.from(
          (h['ingresos'] ?? []).map((x) => Map<String, dynamic>.from(x)),
        )) {
          final categoria = item['categoria']?.toString() ?? 'Miscelánea';
          mapa[categoria] = (mapa[categoria] ?? 0) +
              ((item['importe'] as num?) ?? 0).toDouble();
        }
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
    if (periodo == 'Año') {
      for (final h in historicosAno) {
        final listas = <List<dynamic>>[
          List<dynamic>.from(h['gastos'] ?? []),
          List<dynamic>.from(h['inversiones'] ?? []),
        ];
        for (final lista in listas) {
          for (final raw in lista) {
            final item = Map<String, dynamic>.from(raw);
            if (item['categoria']?.toString() != categoria) continue;
            final sub = item['subcategoria']?.toString().trim();
            final nombre = sub == null || sub.isEmpty ? 'Otros' : sub;
            mapa[nombre] = (mapa[nombre] ?? 0) +
                ((item['importe'] as num?) ?? 0).toDouble();
          }
        }
        if (categoria == 'Gastos históricos') {
          final importe = ((h['gastosHistoricos'] as num?) ?? 0).toDouble();
          if (importe != 0) mapa['Gastos no desglosados'] = (mapa['Gastos no desglosados'] ?? 0) + importe;
        }
      }
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
            if (periodo == 'Año') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: anosDisponibles.contains(anoSeleccionado)
                    ? anoSeleccionado
                    : anosDisponibles.last,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  border: OutlineInputBorder(),
                ),
                items: anosDisponibles
                    .map((ano) => DropdownMenuItem<int>(
                  value: ano,
                  child: Text(ano.toString()),
                ))
                    .toList(),
                onChanged: (ano) {
                  if (ano == null) return;
                  setState(() {
                    anoSeleccionado = ano;
                    categoriasAbiertas.clear();
                  });
                },
              ),
            ],
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
                      if (abierta && entrada.key == 'Pisos' && tiposPisosPorInmueble().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                          child: Column(
                            children: tiposPisosPorInmueble().entries.map((inmueble) {
                              final totalInmueble = inmueble.value.values.fold<double>(0, (a, b) => a + b);
                              final tipos = inmueble.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(inmueble.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Text('${formatearEuros(totalInmueble)} · ${(_porcentajeSeguro(totalInmueble, entrada.value) * 100).toStringAsFixed(1)}%'),
                                      ],
                                    ),
                                    ...tipos.map((t) => Padding(
                                      padding: const EdgeInsets.only(left: 18, top: 5),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(t.key)),
                                          Text('${formatearEuros(t.value)} · ${(_porcentajeSeguro(t.value, totalInmueble) * 100).toStringAsFixed(1)}%'),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else if (abierta && subcategorias.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                          child: Column(
                            children: subcategorias.map((sub) {
                              final porcentajeSub = totalPeriodo > 0 ? sub.value / totalPeriodo : 0.0;
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

  double _porcentajeSeguro(double valor, double total) {
    if (total <= 0) return 0.0;
    return valor / total;
  }

  Map<String, Map<String, double>> tiposPisosPorInmueble() {
    final resultado = <String, Map<String, double>>{};
    void sumar(String inmueble, String tipoGasto, double importe) {
      final i = inmueble.trim().isEmpty ? 'Otros' : inmueble.trim();
      final t = tipoGasto.trim().isEmpty ? 'Otros' : tipoGasto.trim();
      final mapa = resultado.putIfAbsent(i, () => <String, double>{});
      mapa[t] = (mapa[t] ?? 0) + importe;
    }
    for (final m in movimientosFiltrados) {
      if (m['tipo'] != 'Gasto' || m['categoria']?.toString() != 'Pisos') continue;
      sumar(m['subcategoria']?.toString() ?? 'Otros', m['subsubcategoria']?.toString() ?? 'Otros', cantidad(m));
    }
    if (periodo == 'Año') {
      for (final h in historicosAno) {
        for (final raw in List<dynamic>.from(h['gastos'] ?? [])) {
          final item = Map<String, dynamic>.from(raw);
          if (item['categoria']?.toString() != 'Pisos') continue;
          sumar(item['subcategoria']?.toString() ?? 'Otros', item['subsubcategoria']?.toString() ?? 'Otros', ((item['importe'] as num?) ?? 0).toDouble());
        }
      }
    }
    return resultado;
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
            if (abierta && entrada.key == 'Pisos' && tiposPisosPorInmueble().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                child: Column(
                  children: tiposPisosPorInmueble().entries.map((inmueble) {
                    final totalInmueble = inmueble.value.values.fold<double>(0, (a, b) => a + b);
                    final tipos = inmueble.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(inmueble.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text('${formatearEuros(totalInmueble)} · ${(_porcentajeSeguro(totalInmueble, entrada.value) * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                          ...tipos.map((t) => Padding(
                            padding: const EdgeInsets.only(left: 18, top: 5),
                            child: Row(
                              children: [
                                Expanded(child: Text(t.key)),
                                Text('${formatearEuros(t.value)} · ${(_porcentajeSeguro(t.value, totalInmueble) * 100).toStringAsFixed(1)}%'),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            else if (abierta && subcategorias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
                child: Column(
                  children: subcategorias.map((sub) {
                    final porcentajeSub = total > 0 ? sub.value / total : 0.0;
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

    if (periodo == 'Año') {
      for (final h in historicosAno) {
        final lista = tipo == 'Ingreso'
            ? List<dynamic>.from(h['ingresos'] ?? [])
            : <dynamic>[
          ...List<dynamic>.from(h['gastos'] ?? []),
          ...List<dynamic>.from(h['inversiones'] ?? []),
        ];
        for (final raw in lista) {
          final item = Map<String, dynamic>.from(raw);
          if (item['categoria']?.toString() != categoria) continue;
          final sub = item['subcategoria']?.toString().trim();
          final nombre = sub == null || sub.isEmpty ? 'Otros' : sub;
          mapa[nombre] = (mapa[nombre] ?? 0) +
              ((item['importe'] as num?) ?? 0).toDouble();
        }
        if (tipo == 'Gasto' && categoria == 'Gastos históricos') {
          final importe = ((h['gastosHistoricos'] as num?) ?? 0).toDouble();
          if (importe != 0) {
            mapa['Gastos no desglosados'] =
                (mapa['Gastos no desglosados'] ?? 0) + importe;
          }
        }
      }
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

                  final antiguo = categoria['nombre']?.toString() ?? '';
                  final nuevo = nombreController.text.trim();
                  final tipo = widget.categoriasIngresos.contains(categoria) ? 'Ingreso' : 'Gasto';
                  actualizarNombreCategoriaEnDatos(
                    movimientos: widget.movimientos,
                    historicos: widget.historicos,
                    tipo: tipo,
                    antiguo: antiguo,
                    nuevo: nuevo,
                    categoriaId: categoria['id']?.toString(),
                  );
                  categoria['nombre'] = nuevo;
                  categoria['emoji'] = emojiController.text.trim();

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
          movimientos: widget.movimientos,
          historicos: widget.historicos,
          tipo: widget.categoriasIngresos.contains(categoria) ? 'Ingreso' : 'Gasto',
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
                    historicos: widget.historicos,
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
                    historicos: widget.historicos,
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

void actualizarNombreCategoriaEnDatos({
  required List<Map<String, dynamic>> movimientos,
  required List<Map<String, dynamic>> historicos,
  required String tipo,
  required String antiguo,
  required String nuevo,
  String? categoriaId,
}) {
  for (final m in movimientos) {
    if (m['tipo'] == tipo &&
        ((categoriaId != null && m['categoriaId']?.toString() == categoriaId) ||
            m['categoria']?.toString() == antiguo)) {
      m['categoria'] = nuevo;
      if (m['plantillaCategoria']?.toString() == antiguo) {
        m['plantillaCategoria'] = nuevo;
      }
    }
  }
  for (final h in historicos) {
    final clave = tipo == 'Ingreso' ? 'ingresos' : 'gastos';
    final lista = h[clave];
    if (lista is List) {
      for (final item in lista) {
        if (item is Map &&
            ((categoriaId != null && item['categoriaId']?.toString() == categoriaId) ||
                item['categoria']?.toString() == antiguo)) {
          item['categoria'] = nuevo;
        }
      }
    }
  }
}

void actualizarNombreSubcategoriaEnDatos({
  required List<Map<String, dynamic>> movimientos,
  required List<Map<String, dynamic>> historicos,
  required String tipo,
  required String categoria,
  required String antiguo,
  required String nuevo,
  String? subcategoriaId,
}) {
  for (final m in movimientos) {
    if (m['tipo'] == tipo &&
        m['categoria']?.toString() == categoria &&
        ((subcategoriaId != null && m['subcategoriaId']?.toString() == subcategoriaId) ||
            m['subcategoria']?.toString() == antiguo)) {
      m['subcategoria'] = nuevo;
      if (m['plantillaSubcategoria']?.toString() == antiguo) {
        m['plantillaSubcategoria'] = nuevo;
      }
    }
  }
  for (final h in historicos) {
    final clave = tipo == 'Ingreso' ? 'ingresos' : 'gastos';
    final lista = h[clave];
    if (lista is List) {
      for (final item in lista) {
        if (item is Map &&
            item['categoria']?.toString() == categoria &&
            ((subcategoriaId != null && item['subcategoriaId']?.toString() == subcategoriaId) ||
                item['subcategoria']?.toString() == antiguo)) {
          item['subcategoria'] = nuevo;
        }
      }
    }
  }
}

void actualizarNombreSubsubcategoriaEnDatos({
  required List<Map<String, dynamic>> movimientos,
  required List<Map<String, dynamic>> historicos,
  required String tipo,
  required String categoria,
  required String subcategoria,
  required String antiguo,
  required String nuevo,
  String? subsubcategoriaId,
}) {
  for (final m in movimientos) {
    if (m['tipo'] == tipo &&
        m['categoria']?.toString() == categoria &&
        m['subcategoria']?.toString() == subcategoria &&
        ((subsubcategoriaId != null && m['subsubcategoriaId']?.toString() == subsubcategoriaId) ||
            m['subsubcategoria']?.toString() == antiguo)) {
      m['subsubcategoria'] = nuevo;
      if (m['plantillaSubsubcategoria']?.toString() == antiguo) {
        m['plantillaSubsubcategoria'] = nuevo;
      }
    }
  }
  for (final h in historicos) {
    final clave = tipo == 'Ingreso' ? 'ingresos' : 'gastos';
    final lista = h[clave];
    if (lista is List) {
      for (final item in lista) {
        if (item is Map &&
            item['categoria']?.toString() == categoria &&
            item['subcategoria']?.toString() == subcategoria &&
            ((subsubcategoriaId != null && item['subsubcategoriaId']?.toString() == subsubcategoriaId) ||
                item['subsubcategoria']?.toString() == antiguo)) {
          item['subsubcategoria'] = nuevo;
        }
      }
    }
  }
}

class GestionCategoriasPage extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> lista;
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> historicos;
  final Future<void> Function() onChanged;

  const GestionCategoriasPage({
    super.key,
    required this.titulo,
    required this.lista,
    required this.movimientos,
    required this.historicos,
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
      final antiguo = categoria['nombre']?.toString() ?? '';
      final nuevo = nombreController.text.trim();
      final tipo = widget.titulo.toLowerCase().contains('ingreso') ? 'Ingreso' : 'Gasto';
      actualizarNombreCategoriaEnDatos(
        movimientos: widget.movimientos,
        historicos: widget.historicos,
        tipo: tipo,
        antiguo: antiguo,
        nuevo: nuevo,
        categoriaId: categoria['id']?.toString(),
      );
      categoria['nombre'] = nuevo;
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
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
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
    activas.sort(
          (a, b) => (a['nombre']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['nombre']?.toString() ?? '').toLowerCase()),
    );

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
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => GestionSubcategoriasPage(categoria: categoria, movimientos: widget.movimientos, historicos: widget.historicos, tipo: widget.titulo.toLowerCase().contains('ingreso') ? 'Ingreso' : 'Gasto', onChanged: widget.onChanged)));
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
  final List<Map<String, dynamic>> movimientos;
  final List<Map<String, dynamic>> historicos;
  final String tipo;
  final Future<void> Function() onChanged;

  const GestionSubcategoriasPage({
    super.key,
    required this.categoria,
    required this.movimientos,
    required this.historicos,
    required this.tipo,
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
      final ids = Map<String, String>.from(widget.categoria['subcategoriaIds'] ?? {});
      ids.putIfAbsent(texto, () => '${widget.categoria['id']}_sub_${DateTime.now().microsecondsSinceEpoch}');
      widget.categoria['subcategoriaIds'] = ids;
    });
    await widget.onChanged();
  }

  Future<void> editar(int index) async {
    final antiguo = subcategorias[index];
    final controller = TextEditingController(text: antiguo);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar subcategoría'),
        content: TextField(
          controller: controller,

          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isNotEmpty) Navigator.pop(context, valor);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nuevo == null || nuevo.trim().isEmpty || nuevo.trim() == antiguo) return;
    final texto = nuevo.trim();
    if (subcategorias.contains(texto)) return;
    actualizarNombreSubcategoriaEnDatos(
      movimientos: widget.movimientos,
      historicos: widget.historicos,
      tipo: widget.tipo,
      categoria: widget.categoria['nombre']?.toString() ?? '',
      antiguo: antiguo,
      nuevo: texto,
      subcategoriaId: Map<String, String>.from(widget.categoria['subcategoriaIds'] ?? {})[antiguo],
    );
    setState(() {
      final ids = Map<String, String>.from(widget.categoria['subcategoriaIds'] ?? {});
      final id = ids.remove(antiguo) ?? '${widget.categoria['id']}_sub_${DateTime.now().microsecondsSinceEpoch}';
      ids[texto] = id;
      widget.categoria['subcategoriaIds'] = ids;
      final ss = Map<String, dynamic>.from(widget.categoria['subsubcategorias'] ?? {});
      if (ss.containsKey(antiguo)) { ss[texto] = ss.remove(antiguo); }
      widget.categoria['subsubcategorias'] = ss;
      final ssIds = Map<String, dynamic>.from(widget.categoria['subsubcategoriaIds'] ?? {});
      if (ssIds.containsKey(antiguo)) { ssIds[texto] = ssIds.remove(antiguo); }
      widget.categoria['subsubcategoriaIds'] = ssIds;
      subcategorias[index] = texto;
      widget.categoria['subcategorias'] = subcategorias;
    });
    await widget.onChanged();
  }

  Future<void> editarTipo(String inmueble, String tipoGasto) async {
    final mapaIds = Map<String, dynamic>.from(widget.categoria['subsubcategoriaIds'] ?? {});
    final idsInmueble = Map<String, String>.from(mapaIds[inmueble] ?? {});
    final oldId = idsInmueble[tipoGasto];
    final controller = TextEditingController(text: tipoGasto);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar tipo de gasto'),
        content: TextField(controller: controller,  decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () { final v = controller.text.trim(); if (v.isNotEmpty) Navigator.pop(context, v); }, child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (nuevo == null || nuevo.isEmpty || nuevo == tipoGasto) return;
    final nombres = List<String>.from(widget.categoria['subsubcategorias']?[inmueble] ?? const []);
    if (nombres.contains(nuevo)) return;
    actualizarNombreSubsubcategoriaEnDatos(
      movimientos: widget.movimientos,
      historicos: widget.historicos,
      tipo: widget.tipo,
      categoria: widget.categoria['nombre']?.toString() ?? '',
      subcategoria: inmueble,
      antiguo: tipoGasto,
      nuevo: nuevo,
      subsubcategoriaId: oldId?.toString(),
    );
    final nuevoNombres = List<String>.from(nombres)..[nombres.indexOf(tipoGasto)] = nuevo;
    final nuevosMapas = Map<String, dynamic>.from(widget.categoria['subsubcategorias'] ?? {});
    nuevosMapas[inmueble] = nuevoNombres;
    widget.categoria['subsubcategorias'] = nuevosMapas;
    idsInmueble[nuevo] = idsInmueble.remove(tipoGasto) ?? '${widget.categoria['id']}_ss_${DateTime.now().microsecondsSinceEpoch}';
    final nuevosIds = Map<String, dynamic>.from(widget.categoria['subsubcategoriaIds'] ?? {});
    nuevosIds[inmueble] = idsInmueble;
    widget.categoria['subsubcategoriaIds'] = nuevosIds;
    await widget.onChanged();
    if (mounted) setState(() {});
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
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final inmueble = subcategorias[index];
          final esPisos = widget.categoria['nombre']?.toString() == 'Pisos';
          final tipos = esPisos ? List<String>.from((widget.categoria['subsubcategorias']?[inmueble] ?? const [])) : const <String>[];
          return Card(
            child: ExpansionTile(
              title: Text(inmueble, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editar(index)),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => eliminar(index)),
                ],
              ),
              children: esPisos
                  ? tipos.map((t) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 32, right: 12),
                title: Text(t),
                trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editarTipo(inmueble, t)),
              )).toList()
                  : const [],
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
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Nueva categoría'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nombre,  decoration: const InputDecoration(labelText: 'Nombre')), TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Añadir'))]));
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


// ============================================================
// SEGUIMIENTO DE INMUEBLES
// ============================================================

class SeguimientoInmueblesPage extends StatefulWidget {
  final List<Map<String, dynamic>> inmuebles;
  final List<Map<String, dynamic>> movimientos;
  final Future<void> Function(List<Map<String, dynamic>>) onChanged;
  final Future<void> Function() onMovimientosChanged;

  const SeguimientoInmueblesPage({
    super.key,
    required this.inmuebles,
    required this.movimientos,
    required this.onChanged,
    required this.onMovimientosChanged,
  });

  @override
  State<SeguimientoInmueblesPage> createState() => _SeguimientoInmueblesPageState();
}

class _SeguimientoInmueblesPageState extends State<SeguimientoInmueblesPage> {
  late List<Map<String, dynamic>> datos;
  DateTime mes = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const propiedades = ['Bordador', 'Afán', 'Fco Carrera', 'Otros'];

  @override
  void initState() {
    super.initState();
    datos = widget.inmuebles.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _mesKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _euros(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  Future<void> _guardar() async {
    await widget.onChanged(
      datos.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _cobros(Map<String, dynamic> inquilino) {
    final raw = inquilino['cobros'];
    if (raw is! List) return [];
    return raw.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> _cobroDelMes(Map<String, dynamic> inquilino) {
    final lista = _cobros(inquilino);
    final key = _mesKey(mes);
    for (final c in lista) {
      if (c['mes']?.toString() == key) return c;
    }
    return {
      'id': 'cobro_${inquilino['id']}_$key',
      'mes': key,
      'recibido': false,
      'fechaRecibido': null,
      'movimientoId': null,
      'alquiler': ((inquilino['alquiler'] as num?) ?? 0).toDouble(),
      'gastos': ((inquilino['gastos'] as num?) ?? 0).toDouble(),
    };
  }

  Future<void> _anadirInquilino() async {
    String inmueble = propiedades.first;
    final nombre = TextEditingController();
    final alquiler = TextEditingController();
    final gastos = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Nuevo inquilino'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: inmueble,
                  decoration: const InputDecoration(labelText: 'Inmueble'),
                  items: propiedades.map((p) =>
                      DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => inmueble = v);
                  },
                ),
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Inquilino'),
                ),
                TextField(
                  controller: alquiler,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Alquiler mensual (€)'),
                ),
                TextField(
                  controller: gastos,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Gastos mensuales (€)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final a = double.tryParse(alquiler.text.trim().replaceAll(',', '.')) ?? -1;
                final g = double.tryParse(gastos.text.trim().replaceAll(',', '.')) ?? -1;
                if (nombre.text.trim().isEmpty || a < 0 || g < 0) return;
                datos.add({
                  'id': 'inquilino_${DateTime.now().microsecondsSinceEpoch}',
                  'inmueble': inmueble,
                  'inquilino': nombre.text.trim(),
                  'alquiler': a,
                  'gastos': g,
                  'cobros': <Map<String, dynamic>>[],
                });
                Navigator.pop(c, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _guardar();
  }

  Future<void> _marcarRecibido(Map<String, dynamic> inquilino) async {
    final key = _mesKey(mes);
    final alquiler = ((inquilino['alquiler'] as num?) ?? 0).toDouble();
    final gastos = ((inquilino['gastos'] as num?) ?? 0).toDouble();
    final total = alquiler + gastos;
    if (total <= 0) return;

    final cobros = _cobros(inquilino);
    Map<String, dynamic>? cobro;
    for (final c in cobros) {
      if (c['mes']?.toString() == key) {
        cobro = c;
        break;
      }
    }
    cobro ??= {
      'id': 'cobro_${inquilino['id']}_$key',
      'mes': key,
      'recibido': false,
      'fechaRecibido': null,
      'movimientoId': null,
      'alquiler': alquiler,
      'gastos': gastos,
    };

    if (cobro['recibido'] == true) return;

    final ahora = DateTime.now();
    final movimientoId = 'alquiler_${inquilino['id']}_$key';

    // Al marcar recibido se crea un ingreso real con la fecha y hora del cobro.
    // Esto permite que el seguimiento represente "previsto" y Movimientos
    // represente "realmente cobrado".
    if (!widget.movimientos.any((m) => m['id']?.toString() == movimientoId)) {
      widget.movimientos.add({
        'id': movimientoId,
        'cantidad': total,
        'cantidadOriginal': total,
        'moneda': 'EUR',
        'tipoCambio': 1,
        'tipoCambioPendiente': false,
        'tipo': 'Ingreso',
        'categoria': 'Alquileres',
        'subcategoria': inquilino['inmueble']?.toString(),
        'subsubcategoria': null,
        'emoji': '🏘️',
        'fecha': fechaTexto(ahora),
        'fechaCreacion': fechaTexto(ahora),
        'hora': '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}',
        'nota': 'Alquiler $key · ${inquilino['inmueble']} · ${inquilino['inquilino']}',
        'fotoPath': null,
        'recurrente': false,
        'intervaloMeses': 1,
        'recurrenceId': null,
      });
    }

    cobro['recibido'] = true;
    cobro['fechaRecibido'] = ahora.toUtc().toIso8601String();
    cobro['movimientoId'] = movimientoId;
    cobro['alquiler'] = alquiler;
    cobro['gastos'] = gastos;

    if (!cobros.any((c) => c['id']?.toString() == cobro!['id']?.toString())) {
      cobros.add(cobro);
    }
    inquilino['cobros'] = cobros;

    await _guardar();
    await widget.onMovimientosChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingreso de ${_euros(total)} registrado.')),
      );
    }
  }

  Future<void> _editarInquilino(Map<String, dynamic> item) async {
    String inmueble = item['inmueble']?.toString() ?? propiedades.first;
    final nombre = TextEditingController(text: item['inquilino']?.toString() ?? '');
    final alquiler = TextEditingController(
      text: ((item['alquiler'] as num?) ?? 0).toString(),
    );
    final gastos = TextEditingController(
      text: ((item['gastos'] as num?) ?? 0).toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Editar inquilino'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: propiedades.contains(inmueble) ? inmueble : propiedades.first,
                  decoration: const InputDecoration(labelText: 'Inmueble'),
                  items: propiedades.map((p) =>
                      DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => inmueble = v);
                  },
                ),
                TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Inquilino')),
                TextField(controller: alquiler, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Alquiler mensual (€)')),
                TextField(controller: gastos, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gastos mensuales (€)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final a = double.tryParse(alquiler.text.replaceAll(',', '.')) ?? -1;
                final g = double.tryParse(gastos.text.replaceAll(',', '.')) ?? -1;
                if (nombre.text.trim().isEmpty || a < 0 || g < 0) return;
                item['inmueble'] = inmueble;
                item['inquilino'] = nombre.text.trim();
                item['alquiler'] = a;
                item['gastos'] = g;
                Navigator.pop(c, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _guardar();
  }

  Future<void> _borrarInquilino(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar seguimiento'),
        content: Text('¿Eliminar el seguimiento de ${item['inquilino'] ?? ''}? Los ingresos ya registrados no se borrarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      datos.removeWhere((e) => e['id']?.toString() == item['id']?.toString());
      await _guardar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _mesKey(mes);
    final activos = datos;
    double pendiente = 0;
    for (final i in activos) {
      final c = _cobroDelMes(i);
      if (c['recibido'] != true) {
        pendiente += ((i['alquiler'] as num?) ?? 0).toDouble();
        pendiente += ((i['gastos'] as num?) ?? 0).toDouble();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inmuebles'),
        actions: [
          IconButton(
            onPressed: _anadirInquilino,
            icon: const Icon(Icons.add_home_work_outlined),
            tooltip: 'Añadir inquilino',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${mes.month.toString().padLeft(2, '0')}/${mes.year}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: const Text('Pendiente de recibir'),
              trailing: Text(_euros(pendiente), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          if (activos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No hay inquilinos configurados. Pulsa + para añadir uno.'),
              ),
            ),
          ...activos.map((i) {
            final c = _cobroDelMes(i);
            final a = ((i['alquiler'] as num?) ?? 0).toDouble();
            final g = ((i['gastos'] as num?) ?? 0).toDouble();
            final recibido = c['recibido'] == true;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(recibido ? Icons.check : Icons.home_work_outlined),
                ),
                title: Text('${i['inquilino']} · ${i['inmueble']}'),
                subtitle: Text(
                  'Alquiler ${_euros(a)} + gastos ${_euros(g)} = ${_euros(a + g)}\n'
                      '${recibido ? 'Recibido $key' : 'Pendiente $key'}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: recibido ? 'Ya recibido' : 'Marcar recibido',
                      onPressed: recibido ? null : () => _marcarRecibido(i),
                      icon: Icon(recibido ? Icons.check_circle : Icons.payments_outlined),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'editar') _editarInquilino(i);
                        if (v == 'borrar') _borrarInquilino(i);
                      },
                      itemBuilder: (c) => const [
                        PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(value: 'borrar', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// MÓDULO: DEUDAS
// ============================================================

class DeudasPage extends StatefulWidget {
  final List<Map<String, dynamic>> deudas;
  final Future<void> Function(List<Map<String, dynamic>>) onChanged;

  const DeudasPage({super.key, required this.deudas, required this.onChanged});

  @override
  State<DeudasPage> createState() => _DeudasPageState();
}

class _DeudasPageState extends State<DeudasPage> {
  late List<Map<String, dynamic>> datos;

  @override
  void initState() {
    super.initState();
    datos = widget.deudas.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _guardar() => widget.onChanged(datos);

  Future<void> _anadir() async {
    String tipo = 'Me deben';
    final persona = TextEditingController();
    final concepto = TextEditingController();
    final importe = TextEditingController();
    final fecha = TextEditingController(text: fechaTexto(DateTime.now()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Nueva deuda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'Me deben', child: Text('Me deben')),
                    DropdownMenuItem(value: 'Debo', child: Text('Debo')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => tipo = v); },
                ),
                TextField(controller: persona, decoration: const InputDecoration(labelText: 'Persona / entidad')),
                TextField(controller: concepto, decoration: const InputDecoration(labelText: 'Concepto')),
                TextField(controller: importe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importe (€)')),
                TextField(controller: fecha, decoration: const InputDecoration(labelText: 'Fecha')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(importe.text.replaceAll(',', '.')) ?? -1;
                if (persona.text.trim().isEmpty || concepto.text.trim().isEmpty || n < 0) return;
                datos.add({
                  'id': 'deuda_${DateTime.now().microsecondsSinceEpoch}',
                  'tipo': tipo,
                  'persona': persona.text.trim(),
                  'concepto': concepto.text.trim(),
                  'importe': n,
                  'pagado': 0.0,
                  'fecha': fecha.text.trim(),
                });
                Navigator.pop(c, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _guardar();
  }

  Future<void> _pagoParcial(Map<String, dynamic> d) async {
    final restante = (((d['importe'] as num?) ?? 0).toDouble() -
        ((d['pagado'] as num?) ?? 0).toDouble()).clamp(0, double.infinity).toDouble();
    final controller = TextEditingController(text: restante.toStringAsFixed(2));
    final n = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Registrar pago'),
        content: TextField(
          controller: controller,
          autofocus: false,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Importe del pago (€)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    final importe = ((d['importe'] as num?) ?? 0).toDouble();
    final pagado = ((d['pagado'] as num?) ?? 0).toDouble();
    d['pagado'] = (pagado + n).clamp(0, importe).toDouble();
    d['fechaUltimoPago'] = DateTime.now().toUtc().toIso8601String();
    await _guardar();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final meDeben = datos.where((d) => d['tipo'] == 'Me deben').toList();
    final debo = datos.where((d) => d['tipo'] == 'Debo').toList();

    double pendiente(List<Map<String, dynamic>> lista) =>
        lista.fold(0, (sum, d) => sum + (((d['importe'] as num?) ?? 0).toDouble() -
            ((d['pagado'] as num?) ?? 0).toDouble()).clamp(0, double.infinity).toDouble());

    Widget grupo(String titulo, List<Map<String, dynamic>> lista) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$titulo · ${_formatEuroDeudas(pendiente(lista))}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              if (lista.isEmpty) const Text('Sin deudas.'),
              ...lista.map((d) {
                final total = ((d['importe'] as num?) ?? 0).toDouble();
                final pagado = ((d['pagado'] as num?) ?? 0).toDouble();
                final restante = (total - pagado).clamp(0, double.infinity).toDouble();
                return ListTile(
                  title: Text('${d['persona']} · ${d['concepto']}'),
                  subtitle: Text(
                    'Total ${_formatEuroDeudas(total)} · Pagado ${_formatEuroDeudas(pagado)} · Pendiente ${_formatEuroDeudas(restante)}',
                  ),
                  trailing: restante > 0
                      ? IconButton(
                    tooltip: 'Registrar pago',
                    icon: const Icon(Icons.payments_outlined),
                    onPressed: () => _pagoParcial(d),
                  )
                      : const Icon(Icons.check_circle),
                );
              }),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deudas'),
        actions: [IconButton(onPressed: _anadir, icon: const Icon(Icons.add))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          grupo('Me deben', meDeben),
          grupo('Debo', debo),
        ],
      ),
    );
  }
}

String _formatEuroDeudas(double v) =>
    '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

// ============================================================
// MÓDULO: INVERSIONES
// ============================================================

class InversionesPage extends StatefulWidget {
  final List<Map<String, dynamic>> inversiones;
  final Future<void> Function(List<Map<String, dynamic>>) onChanged;

  const InversionesPage({super.key, required this.inversiones, required this.onChanged});

  @override
  State<InversionesPage> createState() => _InversionesPageState();
}

class _InversionesPageState extends State<InversionesPage> {
  late List<Map<String, dynamic>> datos;

  @override
  void initState() {
    super.initState();
    datos = widget.inversiones.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _guardar() => widget.onChanged(datos);

  Future<void> _anadir() async {
    String tipo = 'ETF';
    final activo = TextEditingController();
    final plataforma = TextEditingController();
    final importe = TextEditingController();
    final fecha = TextEditingController(text: fechaTexto(DateTime.now()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Nueva inversión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'ETF', child: Text('ETF')),
                    DropdownMenuItem(value: 'Acciones', child: Text('Acciones')),
                    DropdownMenuItem(value: 'Bitcoin', child: Text('Bitcoin')),
                    DropdownMenuItem(value: 'Oro', child: Text('Oro')),
                    DropdownMenuItem(value: 'Fondos', child: Text('Fondos')),
                    DropdownMenuItem(value: 'Otros', child: Text('Otros')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => tipo = v); },
                ),
                TextField(controller: activo, decoration: const InputDecoration(labelText: 'Producto / activo')),
                TextField(controller: plataforma, decoration: const InputDecoration(labelText: 'Dónde / broker')),
                TextField(controller: importe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importe invertido (€)')),
                TextField(controller: fecha, decoration: const InputDecoration(labelText: 'Fecha')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(importe.text.replaceAll(',', '.')) ?? -1;
                if (activo.text.trim().isEmpty || n < 0) return;
                datos.add({
                  'id': 'inversion_${DateTime.now().microsecondsSinceEpoch}',
                  'tipo': tipo,
                  'activo': activo.text.trim(),
                  'plataforma': plataforma.text.trim(),
                  'importe': n,
                  'fecha': fecha.text.trim(),
                });
                Navigator.pop(c, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    final total = datos.fold<double>(
      0,
          (sum, d) => sum + (((d['importe'] as num?) ?? 0).toDouble()),
    );
    final porActivo = <String, double>{};
    for (final d in datos) {
      final activo = d['activo']?.toString() ?? 'Otros';
      porActivo[activo] = (porActivo[activo] ?? 0) +
          (((d['importe'] as num?) ?? 0).toDouble());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inversiones'),
        actions: [IconButton(onPressed: _anadir, icon: const Icon(Icons.add))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Total invertido'),
              trailing: Text(
                '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Por activo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...porActivo.entries.map((e) => ListTile(
            title: Text(e.key),
            trailing: Text('${e.value.toStringAsFixed(2).replaceAll('.', ',')} €'),
          )),
          const Divider(),
          const Text('Operaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...datos.map((d) => Card(
            child: ListTile(
              title: Text('${d['activo']} · ${d['tipo']}'),
              subtitle: Text('${d['fecha']} · ${d['plataforma'] ?? ''}'),
              trailing: Text('${(((d['importe'] as num?) ?? 0).toDouble()).toStringAsFixed(2).replaceAll('.', ',')} €'),
            ),
          )),
        ],
      ),
    );
  }
}
