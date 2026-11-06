import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/widgets/conteo_revision_sanciones.dart';

void main() {
  testWidgets(
    'el administrador corrige y ve el total inmediato; comisión solo consulta',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var total = 1;
      await Supabase.initialize(
        url: 'https://ejemplo.supabase.co',
        publishableKey: 'prueba',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((r) async {
          expect(r.url.path, endsWith('lm_corregir_conteo_jugador'));
          final p = jsonDecode(r.body);
          expect(p['p_inscripcion_id'], 'j1');
          expect(p['p_ajuste_anterior'], 0);
          expect(p['p_motivo'], 'Corrección del administrador');
          total = p['p_total'];
          return http.Response(
            'null',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      Map<String, dynamic> datos(bool editar) => {
        'puede_editar': editar,
        'conteos': {
          'j1': {
            'total': total,
            'automatico': 1,
            'ajuste': total - 1,
            'partidos': [],
          },
        },
        'disciplina': {
          'j1': {
            'amarillas_total': 6,
            'amarillas_ciclo_actual': 1,
            'rojas_directas': 2,
            'expulsiones_doble_amarilla': 1,
          },
        },
      };
      var futuro = Future.value(datos(true));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, cambiar) => ConteoRevisionSanciones(
                datos: futuro,
                jugador: const {'id': 'j1', 'nombre': 'JUGADOR'},
                recargar: () async {
                  final nuevo = datos(true);
                  cambiar(() {
                    futuro = Future.value(nuevo);
                  });
                  return nuevo;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('T.A. acumuladas: 6'), findsOneWidget);
      expect(find.text('T.R. directas: 2'), findsOneWidget);
      expect(find.text('Doble amarilla: 1'), findsOneWidget);
      expect(find.text('Ciclo T.A.: 1/5'), findsOneWidget);
      await tester.tap(find.text('Partidos jugados: 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar conteo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '3');
      await tester.enterText(
        find.byType(TextFormField).last,
        'Corrección del administrador',
      );
      await tester.tap(find.text('Guardar corrección'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(
        find.text('Total en este campeonato: 3'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'),
      );
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Partidos jugados: 3'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConteoRevisionSanciones(
              datos: Future.value(datos(false)),
              jugador: const {'id': 'j1', 'nombre': 'JUGADOR'},
              recargar: () async => datos(false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partidos jugados: 3'));
      await tester.pumpAndSettle();
      expect(find.text('Editar conteo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
