import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/widgets/revision_sanciones_tesoreria.dart';

void main() {
  testWidgets('el envío consulta cada equipo por separado y advierte cambios posteriores', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final equipos = <int>[];
    var ediciones = 0;
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('lm_penas_envio_tesoreria'));
        final equipo = jsonDecode(request.body)['p_equipo_id'] as int;
        equipos.add(equipo);
        return http.Response(jsonEncode({'revision': 2 + ediciones, 'observaciones': jsonEncode({
          'formato': 'penas_equipos_v1', 'general': '',
          'equipos': {'1': 'NOTA LOCAL', '2': 'NOTA VISITANTE'},
        }), 'desactualizada': equipo == 2,
          'hay_revision_posterior': equipo == 2, 'jugadores': [{'nombre': 'JUGADOR EQUIPO $equipo', 'camiseta': equipo, 'ta': equipo, 'tr': false}]}),
          200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar(String equipo) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RevisionSancionesTesoreria(
        partidoId: 'p1', equipoId: equipo,
        alEditar: equipo == '1' ? () async { ediciones++; } : null,
      ))));
      await tester.pump(); await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); await tester.pumpAndSettle();
    }
    await cargar('1');
    expect(find.textContaining('JUGADOR EQUIPO 1'), findsOneWidget);
    expect(find.text('NOTA LOCAL'), findsOneWidget);
    expect(find.text('NOTA VISITANTE'), findsNothing);
    expect(find.textContaining('La hoja cambió'), findsNothing);
    await tester.tap(find.text('Editar sanciones y observaciones'));
    await tester.pump(); await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); await tester.pumpAndSettle();
    expect(ediciones, 1);
    expect(find.text('Penas y sanciones · Revisión 3'), findsOneWidget);
    await cargar('2');
    expect(find.textContaining('JUGADOR EQUIPO 1'), findsNothing);
    expect(find.textContaining('JUGADOR EQUIPO 2'), findsOneWidget);
    expect(find.text('NOTA LOCAL'), findsNothing);
    expect(find.text('NOTA VISITANTE'), findsOneWidget);
    expect(find.textContaining('La hoja cambió'), findsOneWidget);
    expect(find.textContaining('revisión posterior'), findsOneWidget);
    expect(find.text('Editar sanciones y observaciones'), findsNothing);
    expect(equipos, [1,1,2]);
    expect(tester.takeException(), isNull);
  });
}
