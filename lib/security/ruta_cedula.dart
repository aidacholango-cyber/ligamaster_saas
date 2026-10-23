/// Solo acepta referencias del bucket de cédulas del proyecto configurado.
/// Los enlaces antiguos se conservan en la base; no se descargan hosts externos.
String rutaCedula(String referencia, String basePublica) {
  final base = Uri.parse(basePublica);
  final uri = Uri.tryParse(referencia.trim());
  if (uri == null ||
      uri.scheme != base.scheme ||
      uri.host != base.host ||
      uri.port != base.port ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException('Referencia de documento inválida');
  }
  final segmentos = uri.pathSegments;
  const prefijo = ['storage', 'v1', 'object', 'public', 'cedulas_jugadores'];
  if (segmentos.length <= prefijo.length) {
    throw const FormatException('Ruta de documento inválida');
  }
  for (var i = 0; i < prefijo.length; i++) {
    if (segmentos[i] != prefijo[i]) {
      throw const FormatException('Bucket de documento inválido');
    }
  }
  final ruta = segmentos.skip(prefijo.length).toList();
  if (ruta.any(
    (s) =>
        s.isEmpty ||
        s == '.' ||
        s == '..' ||
        s.contains('/') ||
        s.contains(r'\') ||
        s.contains('%'),
  )) {
    throw const FormatException('Ruta de documento inválida');
  }
  return ruta.join('/');
}
