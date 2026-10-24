/// Opciones compartidas por programación y vocalía.
const canchasDisponibles = ['CANCHA 1', 'CANCHA 2', 'CANCHA SUB 12'];

String? canchaValida(Object? valor) {
  final normalizado = valor?.toString().trim().toUpperCase()
      .replaceAll(RegExp(r'\s+'), '') ?? '';
  for (final cancha in canchasDisponibles) {
    if (cancha.replaceAll(' ', '') == normalizado) return cancha;
  }
  return null;
}
