import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/estado_cuenta.dart';

void main() {
  test(
    'envía al próximo encuentro válido por fecha, sin depender del orden',
    () {
      final origen = {'partido_id': 'origen', 'fecha': '2026-10-23T20:00:00Z'};
      final proximo = {
        'partido_id': 'proximo',
        'fecha': '2026-11-07T20:00:00Z',
      };
      final historial = <Map<String, dynamic>>[
        {'partido_id': 'posterior', 'fecha': '2026-11-14T20:00:00Z'},
        {
          'partido_id': 'cancelado',
          'fecha': '2026-10-24T20:00:00Z',
          'estado': 'cancelado',
        },
        {
          'partido_id': 'aplazado',
          'fecha': '2026-10-25T20:00:00Z',
          'estado': 'aplazado',
        },
        {'partido_id': 'sin-fecha', 'fecha': null},
        proximo,
        origen,
      ];
      expect(siguientePartidoTesoreria(origen, historial), same(proximo));
      expect(siguientePartidoTesoreria(historial.first, historial), isNull);
      expect(siguientePartidoTesoreria(historial[3], historial), isNull);
      historial.add({'partido_id': 'coincidente', 'fecha': proximo['fecha']});
      expect(siguientePartidoTesoreria(origen, historial), isNull);
    },
  );
}
