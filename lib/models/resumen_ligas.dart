List<Map<String, dynamic>> resumirLigas(
  List<Map<String, dynamic>> ligas,
  List<Map<String, dynamic>> equipos,
  List<Map<String, dynamic>> jugadores,
) {
  final ligaPorEquipo = {
    for (final e in equipos) e['id'].toString(): e['liga_id'].toString(),
  };
  final identidades = <String, Set<String>>{};
  final categorias = <String, Map<String, int>>{};
  for (final jugador in jugadores) {
    final liga = ligaPorEquipo[jugador['equipo_id'].toString()];
    if (liga == null) continue;
    final cedula = (jugador['cedula'] ?? '').toString().trim();
    (identidades[liga] ??= {}).add(
      cedula.isEmpty ? 'ficha:${jugador['id']}' : 'cedula:$cedula',
    );
    final categoria = (jugador['categoria'] ?? 'Sin categoría').toString();
    final conteo = categorias[liga] ??= {};
    conteo[categoria] = (conteo[categoria] ?? 0) + 1;
  }
  return [
    for (final liga in ligas)
      {
        'nombre': liga['nombre'],
        'jugadores': identidades[liga['id'].toString()]?.length ?? 0,
        'categorias': categorias[liga['id'].toString()] ?? <String, int>{},
      },
  ];
}
