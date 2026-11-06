import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_admin_liga.dart';
import 'package:liga_el_rosario/screens/pantalla_login.dart';

void main() {
  testWidgets('la flecha del administrador cierra la sesión y abre el inicio', (tester) async {
    // Ahem desborda textos de paneles existentes; esta prueba verifica sesión y navegación.
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalle) {
      if (detalle.library == 'rendering library' && detalle.exceptionAsString().contains('A RenderFlex overflowed')) return;
      anterior?.call(detalle);
    };
    addTearDown(() => FlutterError.onError = anterior);
    tester.view.physicalSize = const Size(1500, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var salidas = 0;
    const uid = '11111111-1111-4111-8111-111111111111';
    final expira = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': expira}))).replaceAll('=', '');
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object datos = [];
        if (request.url.path.endsWith('/token')) {
          datos = {'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.firma', 'refresh_token': 'prueba', 'token_type': 'bearer', 'expires_in': 3600,
            'user': {'id': uid, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'admin@example.com', 'created_at': '2026-01-01T00:00:00Z', 'app_metadata': {}, 'user_metadata': {}}};
        } else if (request.url.path.endsWith('/logout')) {
          salidas++;
          expect(request.url.queryParameters['scope'], 'local');
          return http.Response('', 204, request: request);
        } else if (request.url.path.endsWith('/perfiles')) {
          datos = {'rol': 'admin', 'nombre': 'ADMIN PRUEBA'};
        } else if (request.url.path.endsWith('/ligas')) {
          datos = {'id': 'liga', 'nombre': 'LIGA PRUEBA', 'admin_id': uid};
        }
        return http.Response(jsonEncode(datos), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await tester.runAsync(() => Supabase.instance.client.auth.signInWithPassword(email: 'admin@example.com', password: 'prueba'));
    expect(Supabase.instance.client.auth.currentUser, isNotNull);
    await tester.pumpWidget(const MaterialApp(home: PantallaAdminLiga()));
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await cargar(); await cargar();
    expect(find.text('Panel de Administrador de Liga'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver al inicio y cerrar sesión'));
    await cargar(); await cargar();
    expect(salidas, 1);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(find.byType(PantallaLogin), findsOneWidget);
    expect(find.byType(PantallaAdminLiga), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
