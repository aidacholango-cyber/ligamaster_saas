import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_calificaciones.dart';

void main() {
  testWidgets('la comisión abre la ficha con consultas exclusivas del campeonato',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var leyoJugadores = false;
    await Supabase.initialize(
      url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object datos = [];
        if (request.url.path.endsWith('/lm_comision_equipos')) {
          datos = [{'equipo_id': 12, 'equipo': 'EQUIPO PRUEBA',
            'campeonato_id': 'copa-prueba', 'campeonato': 'COPA',
            'liga': 'LIGA', 'categoria': 'Senior'},
            {'equipo_id': 12, 'equipo': 'EQUIPO PRUEBA',
            'campeonato_id': 'copa-femenino', 'campeonato': 'COPA',
            'liga': 'LIGA', 'categoria': 'Femenino'}];
        } else if (request.url.path.endsWith('/lm_comision_jugadores')) {
          final parametros = jsonDecode(request.body);
          expect(parametros['p_equipo_id'], 12);
          expect(parametros['p_campeonato_id'],
            isIn(['copa-prueba', 'copa-femenino']));
          final femenino = parametros['p_campeonato_id'] == 'copa-femenino';
          datos = [{'id': femenino ? 'jugadora' : 'jugador',
            'nombres': femenino ? 'JUGADORA FEMENINO' : 'JUGADOR SENIOR',
            'apellidos': '', 'categoria': femenino ? 'Femenino' : 'Senior',
            'estado': 'Inscrito', 'equipo_id': 12}];
          leyoJugadores = true;
        } else {
          fail('Consulta fuera del módulo de comisión: ${request.url.path}');
        }
        return http.Response(jsonEncode(datos), 200, request: request,
          headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 350));
    }
    await tester.pumpWidget(const MaterialApp(home: PantallaCalificaciones()));
    await cargar();
    expect(find.text('EQUIPO PRUEBA'), findsOneWidget);
    expect(find.text('Nuevo Equipo'), findsNothing);
    expect(find.text('Campeonatos'), findsNothing);
    await tester.tap(find.text('EQUIPO PRUEBA'));
    await cargar();
    expect(find.text('Femenino'), findsOneWidget);
    await tester.tap(find.text('Senior'));
    await cargar();
    await cargar();
    expect(leyoJugadores, isTrue);
    expect(find.text('JUGADOR SENIOR'), findsOneWidget);
    expect(find.text('JUGADORA FEMENINO'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Femenino').last);
    await tester.pumpAndSettle();
    expect(find.text('JUGADORA FEMENINO'), findsOneWidget);
    expect(find.text('JUGADOR SENIOR'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
