import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_revision_sanciones.dart';

void main() {
  testWidgets('conserva el cálculo automático, exige motivo y envía correcciones sin montos', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var guardados = 0;
    var revision = 0;
    var manual = false;
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object datos;
        if (request.url.path.endsWith('lm_penas_revision_guardar')) {
          final p = jsonDecode(request.body);
          expect(p['p_revision'], revision);
          expect(p['p_origen'], 'origen-original');
          expect(p['p_enviar'], isTrue);
          expect(p['p_observaciones'], 'Revisado con la hoja');
          expect(p['p_correcciones'], [{'id': 'j1', 'ta': 2, 'tr': false, 'suspension_manual': 3}]);
          expect(request.body.contains('centavos'), isFalse);
          expect(request.body.contains('moneda'), isFalse);
          manual = true; guardados++; datos = ++revision;
        } else {
          expect(request.url.path, endsWith('lm_penas_revision_leer'));
          datos = {'revision': revision, 'origen': 'origen-original', 'observaciones': '', 'jugadores': [
            {'id': 'j1', 'equipo_id': 1, 'equipo': 'EQUIPO', 'nombre': 'JUGADOR', 'camiseta': 7,
              'participo': true, 'ta_original': 1, 'tr_original': false, 'ta': manual ? 2 : 1, 'tr': false, 'manual': manual, 'suspension_manual': null},
          ]};
        }
        return http.Response(jsonEncode(datos), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump(); await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const MaterialApp(home: PantallaRevisionSanciones(partidoId: 'p1')));
    await cargar();
    expect(find.text('Suspensión automática'), findsNothing);
    await tester.tap(find.text('Enviar a Tesorería')); await tester.pump();
    expect(find.text('Escribe el motivo o las observaciones de la revisión.'), findsOneWidget);
    expect(guardados, 0);
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    expect(find.text('Suspensión automática'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>)); await tester.pumpAndSettle();
    await tester.tap(find.text('2').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Suspensión automática')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3'); await tester.pump();
    await tester.tap(find.text('Aplicar')); await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300)); await tester.pumpAndSettle();
    expect(find.text('Suspensión: 3 partidos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Revisado con la hoja');
    await tester.tap(find.text('Enviar a Tesorería')); await cargar(); await cargar();
    expect(guardados, 1);
    expect(find.text('Revisión enviada a Tesorería, sin importes.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
