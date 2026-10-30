import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/planilla_vocal_completa.dart';

void main() {
  List<String> validar({
    String vocal = 'V',
    String arbitro = 'A',
    String informeVocal = 'Sin novedades',
    String informeArbitral = 'Sin novedades',
    String? calificacion = 'bueno',
    String cancha = 'CANCHA 1',
    Map<String, Map<String, dynamic>>? controles,
    Set<String>? equipos,
    Map<String, bool>? firmas,
  }) => faltantesPlanillaVocal(
    vocal: vocal,
    arbitro: arbitro,
    informeVocal: informeVocal,
    informeArbitral: informeArbitral,
    calificacion: calificacion,
    cancha: cancha,
    equipos: {'1': 'LOCAL', '2': 'VISITANTE'},
    controles:
        controles ??
        {
          '1': {'balon': true, 'capitan': true, 'camerinos': true},
          '2': {'balon': true, 'capitan': true, 'camerinos': true},
        },
    equiposConJugadores: equipos ?? {'1', '2'},
    firmas:
        firmas ??
        {
          'capitan_local': true,
          'capitan_visitante': true,
          'vocal': true,
          'arbitro': true,
        },
  );
  test(
    'hoja completa acepta ceros deportivos y no obliga a llenar once filas ni cambios',
    () {
      expect(validar(), isEmpty);
    },
  );
  test('bloquea textos vacíos, calificación y cancha pendientes', () {
    expect(validar(vocal: ' '), contains('Vocal'));
    expect(validar(arbitro: ''), contains('Árbitro'));
    expect(validar(informeVocal: ''), contains('Informe vocal'));
    expect(validar(informeArbitral: ' '), contains('Informe arbitral'));
    expect(validar(calificacion: null), contains('Calificación del árbitro'));
    expect(validar(cancha: ''), contains('Cancha'));
  });
  test('exige los seis controles y participación de ambos equipos', () {
    expect(validar(controles: {}).length, 6);
    expect(validar(equipos: {'1'}), contains('Jugadores de VISITANTE'));
  });
  test('exige las cuatro firmas', () {
    expect(validar(firmas: {}).length, 4);
    expect(
      validar(
        firmas: {
          'capitan_local': true,
          'capitan_visitante': true,
          'vocal': true,
        },
      ),
      contains('Firma del árbitro'),
    );
  });
}
