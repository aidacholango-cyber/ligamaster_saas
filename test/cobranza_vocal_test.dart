import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/widgets/cobranza_vocal.dart';

void main() {
  testWidgets(
    'el vocal registra dinero del equipo y árbitro sin mezclar ni duplicar saldos',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
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
          final p = jsonDecode(request.body);
          Object datos = {};
          expect(p['p_partido_id'], 'partido');
          expect(p['p_equipo_id'], 12);
          if (request.url.path.endsWith('lm_tesoreria_cobranza_vocal')) {
            datos = {
              'liga_id': 'liga',
              'partido_id': 'partido',
              'puede_registrar': true,
              'cobro': {
                'moneda': 'USD',
                'items': [
                  {'tipo': 'arbitraje', 'centavos': 1500},
                ],
              },
              'movimientos': movimientos,
            };
          } else if (request.url.path.endsWith(
            'lm_tesoreria_registrar_movimiento',
          )) {
            expect(
              p['p_centavos'],
              p['p_tipo'] == 'aporte_equipo' ? 1000 : 500,
            );
            if (p['p_tipo'] == 'pago_arbitro')
              expect(p['p_beneficiario'], 'ARBITRO PRUEBA');
            movimientos.add({
              'id': p['p_id'],
              'tipo': p['p_tipo'],
              'centavos': p['p_centavos'],
              'moneda': 'USD',
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
        const MaterialApp(
          home: Scaffold(
            body: CobranzaVocal(partidoId: 'partido', equipoId: 12),
          ),
        ),
      );
      await cargar();
      await tester.tap(find.text('Recibido del equipo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.tap(find.text('Guardar movimiento'));
      await cargar();
      await cargar();
      expect(find.textContaining('Saldo: USD 5.00'), findsOneWidget);
      await tester.tap(find.text('Pagado al árbitro'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '5');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ARBITRO PRUEBA',
      );
      await tester.tap(find.text('Guardar movimiento'));
      await cargar();
      await cargar();
      expect(movimientos, hasLength(2));
      expect(
        find.textContaining(
          'Recibido: USD 10.00 · Pagado al árbitro: USD 5.00 · Saldo: USD 5.00',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CobranzaVocal(
              partidoId: 'partido',
              equipoId: 12,
              habilitado: false,
            ),
          ),
        ),
      );
      await cargar();
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Recibido del equipo'),
      );
      expect(boton.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
