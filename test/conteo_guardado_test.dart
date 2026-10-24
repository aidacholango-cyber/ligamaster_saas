import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/widgets/editar_conteo_partidos.dart';

void main() {
  testWidgets(
    'guardar la corrección cierra el editor y devuelve éxito sin salir de la pantalla',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Map<String, dynamic>? enviado;
      await Supabase.initialize(
        url: 'https://ejemplo.supabase.co',
        publishableKey: 'prueba-local',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          enviado = Map<String, dynamic>.from(jsonDecode(request.body));
          return http.Response(
            'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      bool actualizado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  actualizado =
                      await editarConteoPartidos(
                        context,
                        inscripcionId: 'inscripcion-prueba',
                        total: 1,
                        ajuste: 0,
                      ) ==
                      true;
                },
                child: const Text('Abrir conteo'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir conteo'));
      await tester.pumpAndSettle();
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), '4');
      await tester.enterText(campos.at(1), 'Corrección de participaciones');
      await tester.tap(find.text('Guardar corrección'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(enviado?['p_total'], 4);
      expect(actualizado, isTrue);
      expect(find.text('Editar conteo de partidos'), findsNothing);
      expect(find.text('Abrir conteo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
