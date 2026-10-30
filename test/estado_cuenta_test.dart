import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/estado_cuenta.dart';

Map<String, dynamic> partido({String moneda = 'USD'}) => {
  'fecha': '2026-10-20T12:00:00',
  'jornada': 1,
  'numero_partido': 2,
  'local': '<Equipo>',
  'visitante': 'Rival',
  'cobro': {
    'moneda': moneda,
    'items': [
      {'tipo': 'arbitraje', 'centavos': 1000},
      {'tipo': 'mantenimiento', 'centavos': 350},
      {'tipo': 'ta', 'centavos': 100, 'camiseta': '7'},
    ],
  },
  'movimientos': [
    {'tipo': 'aporte_equipo', 'moneda': moneda, 'centavos': 1000},
    {'tipo': 'pago_arbitro', 'moneda': moneda, 'centavos': 500},
    {
      'tipo': 'aporte_equipo',
      'moneda': moneda,
      'centavos': 900,
      'anulado_en': '2026-10-21',
    },
  ],
};

void main() {
  test('partidos sin cobro no se inventan ni suman al estado del equipo', () {
    final sinCobro = {...partido(), 'cobro': null, 'movimientos': <dynamic>[]};
    final balance = balancesTesoreria([partido(), sinCobro])['USD']!;
    expect(balance.cobrado, 1450);
    expect(balance.recibido, 1000);
    final html = htmlEstadoCuenta({'equipo': 'Equipo'}, [sinCobro]);
    expect(html, contains('Cobro de este equipo pendiente de publicar'));
  });
  test(
    'suma cobros, excluye anulados y no descuenta dos veces el arbitraje',
    () {
      final balance = balancesTesoreria([partido()])['USD']!;
      expect(balance.cobrado, 1450);
      expect(balance.recibido, 1000);
      expect(balance.saldo, 450);
      expect(balance.arbitros, 500);
    },
  );
  test('no mezcla monedas ni oculta saldos a favor', () {
    final usd = partido();
    (usd['movimientos'] as List).add({
      'tipo': 'aporte_equipo',
      'moneda': 'USD',
      'centavos': 500,
    });
    final balances = balancesTesoreria([usd, partido(moneda: 'EUR')]);
    expect(balances.length, 2);
    expect(balances['USD']!.saldo, -50);
    expect(dineroTesoreria(-50), '-0.50');
    expect(balances['EUR']!.saldo, 450);
  });
  test('el período incluye sus límites y excluye otros partidos', () {
    expect(
      partidosEnPeriodo(
        [partido()],
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 20),
      ),
      hasLength(1),
    );
    expect(
      partidosEnPeriodo([partido()], DateTime(2026, 10, 21), null),
      isEmpty,
    );
  });
  test(
    'el informe escapa texto y conserva sanciones, anulaciones y entregas',
    () {
      final p = partido();
      for (final m in p['movimientos'] as List) {
        m['fecha'] = '2026-10-20';
        m['referencia'] = '<script>alert(1)</script>';
      }
      final html = htmlEstadoCuenta(
        {
          'equipo': 'Equipo & prueba',
          'liga': 'Liga',
          'campeonato': 'Copa',
          'categoria': 'Senior',
        },
        [p],
      );
      expect(html, contains('Equipo &amp; prueba'));
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>')));
      expect(html, contains('jugador n.º 7'));
      expect(html, contains('ANULADO'));
      expect(html, contains('Entrega al árbitro'));
    },
  );
}
