import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_tecnica.dart';

void main() {
  testWidgets(
    'exige turno de vocalía y guarda programación con el equipo elegido',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      var guardados = 0;
      await Supabase.initialize(
        url: 'https://ejemplo.supabase.co',
        publishableKey: 'prueba-local',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('lm_tecnica_guardar_partido'));
          final datos = jsonDecode(request.body);
          expect(datos['p_partido'], 'partido');
          expect(datos['p_local'], 1);
          expect(datos['p_visitante'], 2);
          expect(datos['p_vocal'], 3);
          expect(datos['p_cancha'], 'CANCHA 2');
          expect(DateTime.parse(datos['p_fecha']).isUtc, isTrue);
          expect(datos.containsKey('p_estado'), isFalse);
          guardados++;
          return http.Response(
            jsonEncode('partido'),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await showDialog<bool>(
                    context: context,
                    builder: (_) => ProgramacionTecnicaDialog(
                      fase: const {'id': 'fase', 'tipo': 'todos_contra_todos'},
                      grupos: const [],
                      equipos: const [
                        {'equipo_id': 1, 'nombre': 'LOCAL'},
                        {'equipo_id': 2, 'nombre': 'VISITA'},
                        {'equipo_id': 3, 'nombre': 'TURNO'},
                      ],
                      partido: const {
                        'id': 'partido',
                        'equipo_local_id': 1,
                        'equipo_visitante_id': 2,
                        'jornada': 2,
                        'fecha_hora': '2026-10-29T22:00:00Z',
                        'cancha': 'CANCHA 2',
                      },
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      // No permite alterar los cruces existentes.
      final campos = tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .toList();
      expect(campos[0].onChanged, isNull);
      expect(campos[1].onChanged, isNull);
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(guardados, 0);
      expect(
        find.textContaining('Completa equipos diferentes'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TURNO').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(guardados, 1);
      expect(resultado, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
