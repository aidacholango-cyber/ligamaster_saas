String nombreCortoVocal(dynamic nombres, dynamic apellidos) {
  String primero(dynamic valor) =>
      (valor ?? '').toString().trim().split(RegExp(r'\s+')).first;
  return '${primero(nombres)} ${primero(apellidos)}'.trim();
}

List<Map<String, dynamic>> buscarCamisetaVocal(
  List<Map<String, dynamic>> jugadoresDelEquipo,
  String texto,
) {
  final numero = int.tryParse(texto.trim());
  if (numero == null || numero < 0) return [];
  // No elegir arbitrariamente si dos inscripciones tienen la misma camiseta.
  return jugadoresDelEquipo
      .where((j) => int.tryParse('${j['camiseta']}') == numero)
      .toList();
}
