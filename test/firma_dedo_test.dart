import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/widgets/firma_dedo.dart';

void main() {
  test('la firma conserva coordenadas relativas al guardar y leer', () {
    final trazos = [
      [const Offset(0.1, 0.25), const Offset(0.8, 0.75)],
    ];
    expect(leerFirma(guardarFirma(trazos)), trazos);
    expect(leerFirma(null), isEmpty);
  });

  testWidgets('permite firmar con el dedo y limpiar únicamente ese cuadro', (
    tester,
  ) async {
    TrazosFirma trazos = [];
    final dibujando = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, cambiar) => FirmaDedo(
                  titulo: 'Firma del vocal',
                  trazos: trazos,
                  alDibujar: dibujando.add,
                  onChanged: (valor) => cambiar(() => trazos = valor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final centro = tester.getCenter(find.bySemanticsLabel('Área de Firma del vocal'));
    final dedo = await tester.createGesture(kind: PointerDeviceKind.touch);
    await dedo.down(centro - const Offset(80, 0));
    await dedo.moveTo(centro);
    await tester.pump();
    await dedo.moveTo(centro + const Offset(80, 20));
    await dedo.up();
    await tester.pump();
    expect(trazos, hasLength(1));
    expect(trazos.single.length, greaterThan(1));
    expect(dibujando.first, isTrue);
    expect(dibujando.last, isFalse);
    expect(find.text('Firma con el dedo'), findsNothing);
    for (final punto in trazos.single) {
      expect(punto.dx, inInclusiveRange(0, 1));
      expect(punto.dy, inInclusiveRange(0, 1));
    }
    await tester.tap(find.text('Limpiar firma'));
    await tester.pump();
    expect(trazos, isEmpty);
    expect(find.text('Firma con el dedo'), findsNothing);
  });

  testWidgets('una firma en solo consulta no se puede limpiar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmaDedo(
            titulo: 'Firma capitán',
            trazos: [
              [const Offset(0.2, 0.2), const Offset(0.8, 0.8)],
            ],
            onChanged: null,
          ),
        ),
      ),
    );
    final boton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Limpiar firma'),
    );
    expect(boton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
