import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_login.dart';
import 'package:liga_el_rosario/screens/pantalla_admin_liga.dart';

void main() {
  testWidgets('Atrás del navegador vuelve del panel al acceso y cierra la sesión', (tester) async {
    tester.view.physicalSize = const Size(1500, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalle) {
      if (detalle.library == 'rendering library' && detalle.exceptionAsString().contains('A RenderFlex overflowed')) return;
      anterior?.call(detalle);
    };
    addTearDown(() => FlutterError.onError = anterior);
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
          return http.Response('', 204, request: request);
        } else if (request.url.path.endsWith('/perfiles')) {
          datos = {'rol': 'admin', 'nombre': 'ADMIN PRUEBA'};
        } else if (request.url.path.endsWith('/ligas')) {
          datos = request.url.queryParameters['select'] == 'id'
            ? [{'id': 'liga'}] : {'id': 'liga', 'nombre': 'LIGA PRUEBA', 'admin_id': uid};
        }
        return http.Response(jsonEncode(datos), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 450));
    }
    await tester.pumpWidget(const MaterialApp(home: PantallaLogin()));
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador de Liga').last); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextField).last, 'prueba');
    await tester.tap(find.text('Iniciar Sesión'));
    await cargar(); await cargar(); await cargar();
    expect(find.byType(PantallaAdminLiga), findsOneWidget);
    expect(Supabase.instance.client.auth.currentSession, isNotNull);
    expect(Navigator.of(tester.element(find.byType(PantallaAdminLiga))).canPop(), isTrue);
    // Es el mismo evento de plataforma que Flutter web recibe del botón Atrás.
    await tester.binding.handlePopRoute();
    await cargar(); await cargar();
    expect(find.byType(PantallaAdminLiga), findsNothing);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(salidas, 1);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    for (final campo in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(campo.controller!.text, isEmpty);
    }
    expect(tester.takeException(), isNull);
  });
}
