import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/cobro_manual.dart';

void main() {
  test('acepta la moneda manual como código o símbolo', () {
    for (final moneda in ['USD', 'usd', 'COP', '\$', '€', '£']) {
      expect(monedaCobroValida(moneda), isTrue);
    }
    for (final moneda in ['', '12', 'US', 'USD123']) {
      expect(monedaCobroValida(moneda), isFalse);
    }
  });
  test('interpreta montos manuales sin perder centavos', () {
    expect(leerCentavos('12'), 1200);
    expect(leerCentavos('12.5'), 1250);
    expect(leerCentavos(' 12,05 '), 1205);
    expect(leerCentavos('0.01'), 1);
    expect(leerCentavos('0'), 0);
    expect(leerCentavos('9999999.99'), 999999999);
  });

  test('rechaza importes negativos, ambiguos o con más de dos decimales', () {
    for (final valor in [
      '',
      '-1',
      '1.001',
      '1,000.00',
      'NaN',
      '1e3',
      '10000000',
    ]) {
      expect(leerCentavos(valor), isNull, reason: valor);
    }
  });

  test('primer partido sin sanciones suma solo los conceptos ingresados', () {
    final cobros = [
      {'tipo': 'arbitraje', 'centavos': 1250},
      {'tipo': 'mantenimiento', 'centavos': 300},
    ];
    expect(totalCobro(cobros), 1550);
    expect(importeCentavos(totalCobro(cobros)), '15.50');
    expect(importeCentavos(0), '0.00');
  });

  test('conserva el cobro manual y la camiseta de cada sanción', () {
    final cobros = [
      {'tipo': 'ta', 'camiseta': '51', 'centavos': 125},
      {'tipo': 'tr', 'camiseta': '32', 'centavos': 700},
      {'tipo': 'otro', 'concepto': 'Reposición de balón', 'centavos': 2000},
    ];
    expect(totalCobro(cobros), 2825);
    expect(detalleCobro(cobros[0]), 'T.A. · jugador n.º 51');
    expect(detalleCobro(cobros[1]), 'T.R. · jugador n.º 32');
    expect(detalleCobro(cobros[2]), 'Reposición de balón');
  });
}
