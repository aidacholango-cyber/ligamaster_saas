import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_login.dart';
import 'package:liga_el_rosario/screens/pantalla_acceso_tesoreria.dart';

void main() {
  testWidgets('Tesorería inicia con su alias y edita cobros sin consultar tablas de campeonatos', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final anterior = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library == 'rendering library' && d.exceptionAsString().contains('A RenderFlex overflowed')) return;
      anterior?.call(d);
    };
    addTearDown(() => FlutterError.onError = anterior);
    SharedPreferences.setMockInitialValues({});
    const uid = '22222222-2222-4222-8222-222222222222';
    final expira = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final jwt = base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': expira}))).replaceAll('=', '');
    var guardados = 0;
    var monto = 1100;
    var revision = 1;
    Map<String, dynamic> cobro() => {'moneda': 'USD', 'items': [{'tipo': 'arbitraje', 'centavos': monto}]};
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        dynamic datos;
        final ruta = request.url.path;
        if (ruta.endsWith('/token')) {
          expect(jsonDecode(request.body)['email'], 'tesoreria2027@ligamaster.invalid');
          datos = {'access_token': 'eyJhbGciOiJIUzI1NiJ9.$jwt.firma', 'refresh_token': 'prueba', 'token_type': 'bearer', 'expires_in': 3600,
            'user': {'id': uid, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'tesoreria2027@ligamaster.invalid', 'created_at': '2026-01-01T00:00:00Z', 'app_metadata': {}, 'user_metadata': {}}};
        } else if (ruta.endsWith('/perfiles')) {
          datos = null;
        } else if (ruta.endsWith('lm_es_tesoreria')) {
          datos = true;
        } else if (ruta.endsWith('lm_tesoreria_ligas')) {
          datos = [{'id': 'liga', 'nombre': 'LIGA PRUEBA'}];
        } else if (ruta.endsWith('lm_tesoreria_operador_catalogo')) {
          expect(jsonDecode(request.body)['p_liga_id'], 'liga');
          datos = {'campeonatos': [{'id': 'copa', 'nombre': 'COPA', 'categoria': 'Senior', 'grupo_campeonato_id': 'grupo'}],
            'equipos': [{'id': 12, 'nombre': 'EQUIPO PRUEBA'}]};
        } else if (ruta.endsWith('lm_tesoreria_estado_cuenta')) {
          expect(jsonDecode(request.body)['p_equipo_id'], 12);
          datos = {'puede_editar': true, 'liga': 'LIGA PRUEBA', 'equipo': 'EQUIPO PRUEBA', 'campeonato': 'COPA', 'categoria': 'Senior',
            'cobros': [{'partido_id': 'partido', 'local': 'EQUIPO PRUEBA', 'visitante': 'RIVAL', 'fecha': '2026-11-05', 'jornada': 1, 'numero_partido': 1, 'cobro': cobro(), 'movimientos': []}]};
        } else if (ruta.endsWith('lm_penas_envio_tesoreria')) {
          datos = null;
        } else if (ruta.endsWith('lm_tesoreria_leer')) {
          datos = {'equipo': 'EQUIPO PRUEBA', 'puede_editar': true, 'revision': revision, 'publicado': cobro(), 'borrador': null};
        } else if (ruta.endsWith('lm_tesoreria_guardar')) {
          final p = jsonDecode(request.body);
          expect(p['p_equipo_id'], 12);
          expect(p['p_partido_id'], 'partido');
          expect(p['p_revision'], 1);
          expect(p['p_publicar'], isTrue);
          expect(p['p_cobro']['items'].first['centavos'], 1250);
          monto = 1250; guardados++; datos = ++revision;
        } else {
          fail('Consulta ajena al acceso de Tesorería: $ruta');
        }
        return http.Response(jsonEncode(datos), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump(); await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120))); await tester.pump(const Duration(milliseconds: 450));
    }
    await tester.pumpWidget(const MaterialApp(home: PantallaLogin()));
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('Tesorería').last); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tesoreria2027');
    await tester.enterText(find.byType(TextField).last, 'prueba');
    await tester.tap(find.text('Iniciar Sesión')); await cargar(); await cargar();
    expect(find.byType(PantallaAccesoTesoreria), findsOneWidget);
    await tester.tap(find.text('LIGA PRUEBA')); await cargar(); await cargar();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first); await tester.pumpAndSettle();
    await tester.tap(find.text('COPA').last); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1)); await tester.pumpAndSettle();
    await tester.tap(find.text('Senior').last); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>)); await tester.pumpAndSettle();
    await tester.tap(find.text('EQUIPO PRUEBA').last); await cargar(); await cargar();
    expect(find.text('Total a pagar: USD 11.00'), findsOneWidget);
    await tester.tap(find.text('Total a pagar: USD 11.00')); await cargar(); await cargar();
    await tester.tap(find.text('Ingresar / editar cobros')); await cargar();
    final montoCampo = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Monto');
    await tester.enterText(montoCampo, '12.50');
    await tester.tap(find.text('Publicar cobro')); await cargar(); await cargar();
    expect(guardados, 1);
    expect(tester.takeException(), isNull);
  });
}
