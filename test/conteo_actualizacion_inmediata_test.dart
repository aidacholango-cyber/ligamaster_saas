import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_planilla_resultado.dart';

void main() {
  testWidgets(
    'la corrección actualiza el detalle y el botón sin cerrar el detalle ni salir del acta',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      var totalEditado = 3;
      await Supabase.initialize(
        url: 'https://ejemplo.supabase.co',
        publishableKey: 'prueba-local',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          Object datos = {};
          if (request.url.path.endsWith('lm_leer_acta')) {
            datos = {
              'version': 1,
              'campeonato': {
                'nombre': 'COPA',
                'categoria': 'Senior',
                'estado': 'activo',
              },
              'fase': {'nombre': 'Primera fase', 'estado': 'pendiente'},
              'partido': {
                'equipo_local_id': 1,
                'equipo_visitante_id': 2,
                'estado': 'programado',
                'jornada': 2,
                'numero_partido': 2,
              },
              'equipos': [
                {'id': 1, 'nombre': 'BARCELONA'},
                {'id': 2, 'nombre': 'RIVAL'},
              ],
              'resultado': {
                'estado': 'confirmado',
                'goles_local': 3,
                'goles_visitante': 2,
              },
              'jugadores': [
                for (var id = 1; id <= 2; id++)
                  {
                    'inscripcion_id': 'ins-$id',
                    'equipo_id': id,
                    'nombres': 'JUGADOR $id',
                    'apellidos': 'PRUEBA',
                    'estado_inscripcion': 'inscrito',
                    'estado_equipo': 'inscrito',
                    'camiseta': id,
                  },
              ],
              'planillas': [
                for (var id = 1; id <= 2; id++)
                  {
                    'inscripcion_jugador_id': 'ins-$id',
                    'participo': true,
                    'goles': id == 1 ? 3 : 2,
                    'autogoles': 0,
                    'amarillas': 0,
                    'roja_directa': false,
                  },
              ],
            };
          } else if (request.url.path.endsWith('lm_corregir_conteo_jugador')) {
            totalEditado = (jsonDecode(request.body)['p_total'] as num).toInt();
          } else if (request.url.path.endsWith(
            'lm_conteo_partidos_jugadores',
          )) {
            datos = {
              'ins-1': {
                'total': totalEditado,
                'automatico': 1,
                'ajuste': totalEditado - 1,
                'partidos': [],
              },
            };
          } else if (request.url.path.endsWith('lm_tesoreria_leer')) {
            datos = {'equipo': 'Equipo', 'puede_editar': false};
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
        const MaterialApp(home: PantallaPlanillaResultado(partidoId: 'prueba')),
      );
      await cargar();
      await tester.tap(find.text('BARCELONA'));
      await cargar();
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Partidos jugados: 3'));
      await cargar();
      await tester.tap(find.text('Editar conteo'));
      await cargar();
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Corrección de participaciones',
      );
      await tester.tap(find.text('Guardar corrección'));
      await cargar();
      await cargar();
      await cargar();
      await cargar();
      expect(
        find.text('Total en este campeonato: 1'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'),
      );
      expect(find.text('Partidos jugados: 1'), findsOneWidget);
      expect(find.text('Editar conteo'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await cargar();
      await tester.tap(find.text('RIVAL'));
      await cargar();
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Actualizar'));
      await cargar();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
