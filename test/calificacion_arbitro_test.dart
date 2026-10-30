import 'fixtures/hoja_vocal_completa.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_vocal.dart';
import 'package:liga_el_rosario/widgets/calificacion_arbitro.dart';

void main() {
  testWidgets('una sola valoración se conserva al guardar y volver a entrar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anteriorError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'rendering library' &&
          details.exceptionAsString().contains('A RenderFlex overflowed'))
        return;
      anteriorError?.call(details);
    };
    addTearDown(() => FlutterError.onError = anteriorError);
    SharedPreferences.setMockInitialValues({});
    String? guardada = 'bueno';
    var version = 1;
    await Supabase.initialize(
      url: 'https://ejemplo.supabase.co',
      publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        Object datos = {};
        if (request.url.path.endsWith('lm_vocal_leer_planilla_controles')) {
          datos = hojaVocalCompleta(version: version);
        } else if (request.url.path.endsWith('lm_turno_vocalia')) {
          datos = {'equipo': 'EQUIPO DE TURNO'};
        } else if (request.url.path.endsWith('lm_vocal_regla_datos')) {
          datos = {
            'categoria': 'Fútbol Senior',
            'nacimientos': {},
            'calificacion_arbitro': guardada,
          };
        } else if (request.url.path.endsWith(
          'lm_vocal_guardar_con_calificacion',
        )) {
          final p = jsonDecode(request.body);
          expect(p['p_vocal'], 'VOCAL EQUIPO DE TURNO');
          expect(p['p_calificacion'], 'excelente');
          expect(p.containsKey('p_equipo_id'), isFalse);
          guardada = p['p_calificacion'];
          datos = ++version;
        } else if (request.url.path.endsWith('lm_tesoreria_leer')) {
          datos = {
            'equipo': 'EQUIPO',
            'puede_editar': false,
            'publicado': null,
          };
        }
        return http.Response(
          jsonEncode(datos),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> abrir() async {
      await tester.pumpWidget(
        const MaterialApp(home: PlanillaVocal(partidoId: 'partido')),
      );
      await cargar();
      await cargar();
    }

    await abrir();
    expect(find.byType(CalificacionArbitro), findsOneWidget);
    expect(find.textContaining('11 titulares:'), findsNothing);
    await tester.ensureVisible(find.text('Calificación del árbitro'));
    await tester.tap(find.text('Calificación del árbitro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bueno').last);
    await tester.pump();
    await tester.tap(find.text('Excelente'));
    await tester.pump();
    final grupo = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(grupo.groupValue, 'excelente');
    await tester.pump(const Duration(seconds: 4));
    await cargar();
    expect(guardada, 'excelente');
    await tester.pumpWidget(const SizedBox.shrink());
    await abrir();
    expect(
      tester
          .widget<CalificacionArbitro>(find.byType(CalificacionArbitro))
          .valor,
      'excelente',
    );
    expect(find.byType(CalificacionArbitro), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
