import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_tesoreria.dart';

void main() {
  testWidgets('registra un aporte y actualiza recibido y saldo sin salir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final movimientos = <Map<String, dynamic>>[];
    await Supabase.initialize(
      url: 'https://ejemplo.supabase.co',
      publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        Object datos = {};
        if (request.url.path.endsWith('lm_tesoreria_catalogo')) {
          expect(jsonDecode(request.body)['p_liga_id'], 'liga');
          datos = {
            'campeonatos': [
              {'id': 'copa', 'nombre': 'COPA', 'categoria': 'Senior'},
              {
                'id': 'copa-femenino',
                'nombre': 'COPA',
                'categoria': 'Femenino',
              },
            ],
            'equipos': [
              {'id': 12, 'nombre': 'EQUIPO PRUEBA'},
              {'id': 20, 'nombre': 'EQUIPO RIVAL'},
            ],
          };
        } else if (request.url.path.endsWith('/campeonatos')) {
          expect(request.url.queryParameters['liga_id'], 'eq.liga');
          datos = [
            {'id': 'copa', 'grupo_campeonato_id': 'grupo-copa'},
            {'id': 'copa-femenino', 'grupo_campeonato_id': 'grupo-copa'},
          ];
        } else if (request.url.path.endsWith('lm_tesoreria_estado_cuenta')) {
          final parametros = jsonDecode(request.body);
          expect(parametros['p_campeonato_id'], 'copa');
          expect(parametros['p_equipo_id'], isIn([12, 20]));
          datos = {
            'puede_editar': true,
            'liga': 'LIGA',
            'equipo': 'EQUIPO PRUEBA',
            'campeonato': 'COPA',
            'categoria': 'Senior',
            'cobros': [
              {
                'partido_id': 'partido',
                'local': 'EQUIPO PRUEBA',
                'visitante': 'RIVAL',
                'fecha': '2026-10-20',
                'jornada': 1,
                'numero_partido': 2,
                'cobro': {
                  'moneda': 'USD',
                  'items': [
                    {'tipo': 'arbitraje', 'centavos': 1500},
                  ],
                },
                'movimientos': movimientos,
              },
            ],
          };
          if (parametros['p_equipo_id'] == 20) {
            final cuenta = datos as Map<String, dynamic>;
            cuenta['equipo'] = 'EQUIPO RIVAL';
            cuenta['cobros'] = [for (var n = 1; n <= 2; n++) {
              'partido_id': 'rival-$n', 'local': 'EQUIPO PRUEBA', 'visitante': 'EQUIPO RIVAL',
              'fecha': '2026-10-20', 'jornada': n, 'numero_partido': n,
              'cobro': {'moneda': 'USD', 'items': [{'tipo': 'arbitraje', 'centavos': n == 1 ? 1450 : 2200}]},
              'movimientos': <dynamic>[],
            }];
          }
        } else if (request.url.path.endsWith(
          'lm_tesoreria_registrar_movimiento',
        )) {
          final p = jsonDecode(request.body);
          expect(p['p_partido_id'], 'partido');
          expect(p['p_equipo_id'], 12);
          expect(p['p_tipo'], 'aporte_equipo');
          expect(p['p_moneda'], 'USD');
          expect(p['p_centavos'], 1000);
          movimientos.add({
            'id': p['p_id'],
            'tipo': p['p_tipo'],
            'moneda': 'USD',
            'centavos': 1000,
            'fecha': p['p_fecha'],
            'referencia': '',
            'beneficiario': '',
          });
          datos = p['p_id'];
        } else {
          fail('Consulta inesperada: ${request.url.path}');
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
      const MaterialApp(home: PantallaTesoreria(ligaId: 'liga')),
    );
    await cargar();
    await tester.tap(find.byKey(const ValueKey('tesoreria-campeonato')));
    await tester.pumpAndSettle();
    expect(find.text('COPA'), findsOneWidget);
    await tester.tap(find.text('COPA').last);
    await cargar();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Femenino'), findsOneWidget);
    await tester.tap(find.text('Senior').last);
    await cargar();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EQUIPO PRUEBA').last);
    await cargar();
    expect(find.text('USD 15.00'), findsNWidgets(3));
    await tester.tap(find.text('Registrar pago / entrega al árbitro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.tap(find.text('Guardar movimiento'));
    await cargar();
    await cargar();
    expect(movimientos, hasLength(1));
    expect(find.text('USD 10.00'), findsOneWidget);
    expect(find.text('USD 5.00'), findsOneWidget);
    expect(find.text('Pago recibido del equipo'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EQUIPO RIVAL').last);
    await cargar();
    expect(find.text('Estado de cuenta de EQUIPO RIVAL'), findsOneWidget);
    expect(find.text('USD 36.50'), findsNWidgets(2));
    expect(find.text('USD 10.00'), findsNothing);
    expect(find.text('USD 5.00'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
