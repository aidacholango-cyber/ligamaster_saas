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
    'rechaza al adulto como titular once y acepta automáticamente al juvenil, sin selector de tiempo',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final anteriorError = FlutterError.onError;
      FlutterError.onError = (details) {
        // Ahem ocupa más ancho que la fuente real en encabezados de tabla de 12px.
        if (details.library == 'rendering library' &&
            details.exceptionAsString().contains('A RenderFlex overflowed'))
          return;
        anteriorError?.call(details);
      };
      addTearDown(() => FlutterError.onError = anteriorError);
      SharedPreferences.setMockInitialValues({});
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
            datos = {
              'editable': true,
              'partido': {
                'id': 'partido',
                'local': 'LOCAL',
                'visitante': 'VISITANTE',
                'equipo_local_id': 1,
                'equipo_visitante_id': 2,
                'fecha_hora': '2026-10-29T15:00:00Z',
                'cancha': 'CANCHA 1',
              },
              'jugadores': [
                for (var i = 1; i <= 12; i++)
                  {
                    'id': '$i',
                    'equipo_id': 1,
                    'nombres': i == 12 ? 'JUVENIL' : 'ADULTO',
                    'apellidos': '$i',
                    'camiseta': i,
                    'habilitado': true,
                  },
              ],
              'borrador': {
                'version': 1,
                'vocal': 'VOCAL',
                'arbitro': 'ARBITRO',
                'jugadores': [
                  for (var i = 1; i <= 10; i++)
                    {
                      'id': '$i',
                      'tipo': 'titular',
                      'goles': 0,
                      'ta': 0,
                      'tr': false,
                    },
                ],
              },
            };
          } else if (request.url.path.endsWith('lm_vocal_regla_datos')) {
            datos = {
              'categoria': 'Fútbol Senior',
              'nacimientos': {
                for (var i = 1; i <= 12; i++)
                  '$i': i == 12 ? '01/01/2010' : '01/01/1990',
              },
            };
          } else if (request.url.path.endsWith('lm_tesoreria_leer')) {
            datos = {
              'equipo': 'EQUIPO',
              'puede_editar': false,
              'publicado': null,
            };
          } else if (request.url.path.endsWith(
            'lm_vocal_guardar_planilla_firmas',
          )) {
            datos = 2;
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

      await tester.pumpWidget(
        const MaterialApp(home: PlanillaVocal(partidoId: 'partido')),
      );
      await cargar();
      await cargar();
      expect(find.text('Iniciar segundo tiempo'), findsNothing);
      final ingreso = find
          .byTooltip('Ingresar jugador por número de camiseta')
          .first;
      await tester.ensureVisible(ingreso);
      await tester.tap(ingreso);
      await tester.pumpAndSettle();
      final numero = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Número',
      );
      await tester.enterText(numero, '11');
      await tester.pump();
      expect(
        find.textContaining(
          'para jugar con 11 titulares debe haber al menos un menor',
        ),
        findsOneWidget,
      );
      FilledButton boton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar y siguiente'),
      );
      expect(boton().onPressed, isNull);
      await tester.enterText(numero, '12');
      await tester.pump();
      expect(boton().onPressed, isNotNull);
      await tester.tap(find.text('Guardar y siguiente'));
      await cargar();
      expect(find.text('Número de camiseta'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
