import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_posiciones.dart';
import 'package:liga_el_rosario/screens/pantalla_goleadores.dart';
import 'package:liga_el_rosario/screens/pantalla_sanciones.dart';

void main() {
  testWidgets('las tres estadísticas muestran cambios sin salir de la pantalla',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var actualizado = false;
    var consultas = 0;
    await Supabase.initialize(
      url: 'https://ejemplo.supabase.co',
      publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        consultas++;
        if (request.url.path.endsWith('lm_tabla_posiciones')) {
          expect(request.url.queryParameters['campeonato_id'], 'eq.copa-prueba');
        } else {
          expect(jsonDecode(request.body)['p_campeonato_id'], 'copa-prueba');
        }
        final filas = actualizado ? [
          {'fase_id': 'fase', 'fase': 'Regular', 'equipo_id': 'equipo',
            'equipo': 'EQUIPO ACTUALIZADO', 'nombres': 'JUGADOR ACTUALIZADO',
            'apellidos': '', 'goles': 4, 'puntos': 3,
            'amarillas_total': 2, 'amarillas_ciclo_actual': 2}
        ] : [];
        return http.Response(jsonEncode(filas), 200, request: request,
          headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 350));
    }
    const copa = <String, dynamic>{'id': 'copa-prueba', 'nombre': 'Copa',
      'categoria': 'Senior'};
    for (final pantalla in <Widget>[
      const PantallaPosiciones(campeonato: copa),
      const PantallaGoleadores(campeonato: copa),
      const PantallaSanciones(campeonato: copa),
    ]) {
      actualizado = false;
      await tester.pumpWidget(MaterialApp(home: pantalla));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await cargar();
      expect(find.text('EQUIPO ACTUALIZADO'), findsNothing);
      final anteriores = consultas;
      actualizado = true;
      await tester.pump(const Duration(seconds: 5));
      await cargar();
      expect(consultas, greaterThan(anteriores));
      expect(find.text('EQUIPO ACTUALIZADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
