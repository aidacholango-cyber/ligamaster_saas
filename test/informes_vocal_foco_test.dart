import 'fixtures/hoja_vocal_completa.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_vocal.dart';

void main() {
  testWidgets(
    'los informes conservan el foco durante varios ciclos de autoguardado',
    (tester) async {
      // La fuente Ahem de flutter_test desborda encabezados compactos de las
      // tablas ajenas a esta prueba. Solo se filtra ese aviso de renderizado.
      final manejadorAnterior = FlutterError.onError;
      FlutterError.onError = (detalle) {
        if (detalle.library == 'rendering library' &&
            detalle.exceptionAsString().startsWith(
              'A RenderFlex overflowed by',
            ))
          return;
        manejadorAnterior?.call(detalle);
      };
      addTearDown(() => FlutterError.onError = manejadorAnterior);
      SharedPreferences.setMockInitialValues({});
      final guardados = <Map<String, dynamic>>[];
      await Supabase.initialize(
        url: 'https://ejemplo.supabase.co',
        publishableKey: 'prueba-local',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          Object respuesta = {};
          if (request.url.path.endsWith('lm_vocal_leer_planilla_controles')) {
            respuesta = hojaVocalCompleta(partidoId: 'partido-prueba');
          } else if (request.url.path.endsWith(
            'lm_vocal_guardar_con_calificacion',
          )) {
            guardados.add(Map<String, dynamic>.from(jsonDecode(request.body)));
            respuesta = guardados.length;
          } else if (request.url.path.endsWith('lm_vocal_regla_datos')) {
            respuesta = {
              'categoria': 'Fútbol Senior',
              'calificacion_arbitro': 'bueno',
              'nacimientos': {},
            };
          } else if (request.url.path.endsWith('lm_tesoreria_leer')) {
            respuesta = {
              'equipo': 'EQUIPO',
              'puede_editar': false,
              'publicado': null,
            };
          }
          return http.Response(
            jsonEncode(respuesta),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      await tester.pumpWidget(
        const MaterialApp(home: PlanillaVocal(partidoId: 'partido-prueba')),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(
        find.byType(TextField),
        findsWidgets,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'),
      );
      Finder campo(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      for (final etiqueta in ['Informe vocal', 'Informe arbitral']) {
        final buscador = campo(etiqueta);
        await tester.ensureVisible(buscador);
        await tester.enterText(buscador, 'PRIMERA PARTE');
        await tester.pump(const Duration(seconds: 6));
        expect(tester.widget<TextField>(buscador).focusNode!.hasFocus, isTrue);
        expect(guardados, isEmpty);
        tester.testTextInput.enterText('PRIMERA PARTE Y CONTINUACIÓN');
        await tester.pump(const Duration(seconds: 6));
        expect(
          tester.widget<TextField>(buscador).controller!.text,
          'PRIMERA PARTE Y CONTINUACIÓN',
        );
        expect(tester.widget<TextField>(buscador).focusNode!.hasFocus, isTrue);
        expect(guardados, isEmpty);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(guardados, hasLength(1));
      expect(
        guardados.single['p_informe_vocal'],
        'PRIMERA PARTE Y CONTINUACIÓN',
      );
      expect(
        guardados.single['p_informe_arbitral'],
        'PRIMERA PARTE Y CONTINUACIÓN',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
