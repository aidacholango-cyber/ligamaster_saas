List<String> faltantesPlanillaVocal({
  required String vocal,
  required String arbitro,
  required String informeVocal,
  required String informeArbitral,
  required String? calificacion,
  required String cancha,
  required Map<String, String> equipos,
  required Map<String, Map<String, dynamic>> controles,
  required Set<String> equiposConJugadores,
  required Map<String, bool> firmas,
}) {
  final faltantes = <String>[];
  for (final campo in {
    'Vocal': vocal,
    'Árbitro': arbitro,
    'Informe vocal': informeVocal,
    'Informe arbitral': informeArbitral,
    'Cancha': cancha,
  }.entries) {
    if (campo.value.trim().isEmpty) faltantes.add(campo.key);
  }
  if (!const ['malo', 'bueno', 'excelente'].contains(calificacion)) {
    faltantes.add('Calificación del árbitro');
  }
  for (final equipo in equipos.entries) {
    if (!equiposConJugadores.contains(equipo.key)) {
      faltantes.add('Jugadores de ${equipo.value}');
    }
    for (final control in const {
      'balon': 'Balón',
      'capitan': 'Capitán',
      'camerinos': 'Camerinos',
    }.entries) {
      if (controles[equipo.key]?[control.key] != true) {
        faltantes.add('${control.value} · ${equipo.value}');
      }
    }
  }
  for (final firma in const {
    'capitan_local': 'Firma del capitán local',
    'capitan_visitante': 'Firma del capitán visitante',
    'vocal': 'Firma del vocal',
    'arbitro': 'Firma del árbitro',
  }.entries) {
    if (firmas[firma.key] != true) faltantes.add(firma.value);
  }
  return faltantes;
}
