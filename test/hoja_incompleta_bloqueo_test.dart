import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_vocal.dart';
import 'fixtures/hoja_vocal_completa.dart';

void main() {
  testWidgets('Guardar y Terminar se habilitan solo al completar el último control obligatorio', (tester) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anteriorError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'rendering library' && details.exceptionAsString().contains('A RenderFlex overflowed')) return;
      anteriorError?.call(details);
    };
    addTearDown(() => FlutterError.onError = anteriorError);
    SharedPreferences.setMockInitialValues({});
    var guardados = 0;
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object datos = {};
        if (request.url.path.endsWith('lm_vocal_leer_planilla_controles')) {
          final hoja = hojaVocalCompleta();
          (hoja['borrador']['controles_equipo']['1'] as Map)['balon'] = false;
          datos = hoja;
        } else if (request.url.path.endsWith('lm_vocal_regla_datos')) {
          datos = {'categoria': 'Fútbol Senior', 'calificacion_arbitro': 'bueno', 'nacimientos': {}};
        } else if (request.url.path.endsWith('lm_vocal_guardar_con_calificacion')) {
          final p = jsonDecode(request.body);
          expect(p['p_controles']['1']['balon'], true);
          expect(p['p_calificacion'], 'bueno');
          datos = ++guardados + 1;
        } else if (request.url.path.endsWith('lm_tesoreria_leer')) {
          datos = {'equipo': 'EQUIPO', 'publicado': null, 'puede_editar': false};
        }
        return http.Response(jsonEncode(datos), 200, request: request,
          headers: {'content-type': 'application/json'});
      }));
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 350));
    }
    await tester.pumpWidget(const MaterialApp(home: PlanillaVocal(partidoId: 'partido')));
    await cargar(); await cargar();
    ElevatedButton boton(String texto) => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, texto));
    expect(boton('Guardar planilla').onPressed, isNull);
    expect(boton('Terminar partido y publicar').onPressed, isNull);
    await tester.pump(const Duration(seconds: 4));
    await cargar();
    expect(guardados, 0);
    await tester.ensureVisible(find.text('Balón').first);
    await tester.tap(find.text('Balón').first);
    await tester.pump();
    expect(boton('Guardar planilla').onPressed, isNotNull);
    expect(boton('Terminar partido y publicar').onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 4));
    await cargar();
    expect(guardados, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
