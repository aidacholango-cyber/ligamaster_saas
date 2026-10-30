import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liga_el_rosario/screens/pantalla_tecnica.dart';

void main() {
  testWidgets('el basurero pide confirmación y refresca la lista al eliminar', (tester) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    var eliminado = false;
    await Supabase.initialize(url: 'https://ejemplo.supabase.co', publishableKey: 'prueba-local',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object? datos;
        if (request.url.path.endsWith('lm_tecnica_borrar_partido')) {
          expect(jsonDecode(request.body)['p_partido_id'], 'p1');
          eliminado = true;
        } else {
          expect(request.url.path, endsWith('lm_tecnica_catalogo'));
          datos = {
            'campeonatos': [{'id': 'c1', 'nombre': 'COPA', 'liga': 'LIGA', 'categoria': 'Senior'}],
            'fases': [{'id': 'f1', 'campeonato_id': 'c1', 'nombre': 'Primera fase', 'tipo': 'todos_contra_todos'}],
            'equipos': [], 'grupos': [],
            'partidos': [if (!eliminado) {'id': 'p1', 'fase_id': 'f1', 'local': 'LOCAL', 'visitante': 'VISITA', 'jornada': 1, 'numero_partido': 1, 'confirmado': false}],
          };
        }
        return http.Response(jsonEncode(datos), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    Future<void> cargar() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const MaterialApp(home: PantallaTecnica()));
    await cargar();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first); await tester.pumpAndSettle();
    await tester.tap(find.text('LIGA · COPA · Senior').last); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last); await tester.pumpAndSettle();
    await tester.tap(find.text('Primera fase').last); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar partido')); await tester.pumpAndSettle();
    expect(eliminado, isFalse);
    await tester.tap(find.text('Cancelar')); await tester.pumpAndSettle();
    expect(eliminado, isFalse);
    await tester.tap(find.byTooltip('Eliminar partido')); await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar')); await cargar(); await cargar();
    expect(eliminado, isTrue);
    expect(find.text('LOCAL vs VISITA'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
