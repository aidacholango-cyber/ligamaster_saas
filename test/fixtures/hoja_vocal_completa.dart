Map<String, dynamic> hojaVocalCompleta({
  String partidoId = 'partido',
  int version = 1,
}) => {
  'editable': true,
  'partido': {
    'id': partidoId,
    'local': 'LOCAL',
    'visitante': 'VISITANTE',
    'equipo_local_id': 1,
    'equipo_visitante_id': 2,
    'fecha_hora': '2026-10-29T15:00:00Z',
    'cancha': 'CANCHA 1',
  },
  'jugadores': [
    for (var id = 1; id <= 2; id++)
      {
        'id': 'j$id',
        'equipo_id': id,
        'nombres': 'JUGADOR',
        'apellidos': '$id',
        'camiseta': id,
        'habilitado': true,
        'fecha_nacimiento': '1990-01-01',
      },
  ],
  'borrador': {
    'version': version,
    'vocal': 'VOCAL',
    'arbitro': 'ARBITRO',
    'informe_vocal': 'Sin novedades',
    'informe_arbitral': 'Sin novedades',
    'jugadores': [
      for (var id = 1; id <= 2; id++)
        {'id': 'j$id', 'tipo': 'titular', 'ta': 0, 'tr': false, 'goles': 0},
    ],
    'controles_equipo': {
      for (var id = 1; id <= 2; id++)
        '$id': {'balon': true, 'capitan': true, 'camerinos': true},
    },
    'firmas': {
      for (final firma in [
        'capitan_local',
        'capitan_visitante',
        'vocal',
        'arbitro',
      ])
        firma: [
          [
            [0.1, 0.1],
            [0.4, 0.5],
          ],
        ],
    },
  },
};
