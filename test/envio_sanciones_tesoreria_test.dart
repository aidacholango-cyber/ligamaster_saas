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
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('lm_penas_envio_tesoreria'));
        final equipo = jsonDecode(request.body)['p_equipo_id'] as int;
        equipos.add(equipo);
        return http.Response(jsonEncode({'revision': 2, 'observaciones': 'Revisado', 'desactualizada': equipo == 2,
          'hay_revision_posterior': equipo == 2, 'jugadores': [{'nombre': 'JUGADOR EQUIPO $equipo', 'camiseta': equipo, 'ta': equipo, 'tr': false}]}),
          200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar(String equipo) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RevisionSancionesTesoreria(partidoId: 'p1', equipoId: equipo))));
      await tester.pump(); await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); await tester.pumpAndSettle();
    }
    await cargar('1');
    expect(find.textContaining('JUGADOR EQUIPO 1'), findsOneWidget);
    expect(find.textContaining('La hoja cambió'), findsNothing);
    await cargar('2');
    expect(find.textContaining('JUGADOR EQUIPO 1'), findsNothing);
    expect(find.textContaining('JUGADOR EQUIPO 2'), findsOneWidget);
    expect(find.textContaining('La hoja cambió'), findsOneWidget);
    expect(find.textContaining('revisión posterior'), findsOneWidget);
    expect(equipos, [1,2]);
    expect(tester.takeException(), isNull);
  });
}
