import 'package:flutter_test/flutter_test.dart';
import 'package:mis_finanzas_app/main.dart';

void main() {
  testWidgets('La aplicación se inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MisFinanzasApp());
    await tester.pumpAndSettle();
  });
}
