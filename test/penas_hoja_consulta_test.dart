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
  testWidgets('penas consulta la hoja sin permisos de edición ni llamadas de tesorería', (tester) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anterior = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library == 'rendering library' && d.exceptionAsString().contains('A RenderFlex overflowed')) return;
      anterior?.call(d);
    };
    addTearDown(() => FlutterError.onError = anterior);
    SharedPreferences.setMockInitialValues({});
    var lecturas = 0;
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('lm_penas_hoja_leer'));
        lecturas++;
        final hoja = hojaVocalCompleta();
        hoja['editable'] = false;
        hoja['categoria'] = 'Fútbol Senior';
        hoja['calificacion_arbitro'] = 'bueno';
        hoja['turno_vocalia'] = {'equipo': 'EQUIPO DE TURNO'};
        return http.Response(jsonEncode(hoja), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await tester.pumpWidget(const MaterialApp(home: PlanillaVocal(partidoId: 'partido', soloLectura: true, consultaSanciones: true)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 1));
    expect(lecturas, 1);
    for (final campo in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(campo.enabled, isFalse);
    }
    await tester.pump(const Duration(seconds: 5));
    expect(lecturas, 1);
    expect(tester.takeException(), isNull);
  });
}
