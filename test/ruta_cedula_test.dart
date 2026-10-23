import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/security/ruta_cedula.dart';

void main() {
  const base =
      'https://ejemplo.supabase.co/storage/v1/object/public/cedulas_jugadores/';
  test('conserva referencias antiguas sin cambiar archivos', () {
    expect(rutaCedula('${base}19/documento.png', base), '19/documento.png');
    expect(rutaCedula('${base}documento.png', base), 'documento.png');
    expect(
      rutaCedula('${base}19/foto%20frente.png', base),
      '19/foto frente.png',
    );
  });
  test('rechaza hosts, protocolos, buckets y rutas no autorizados', () {
    for (final url in [
      'https://externo.example/storage/v1/object/public/cedulas_jugadores/19/a.png',
      base.replaceFirst('https:', 'http:') + '19/a.png',
      base.replaceFirst('cedulas_jugadores', 'fotos_jugadores') + '19/a.png',
      '${base}19/a.png?token=secreto',
      '${base}19/a.png#fragmento',
      '${base}19/%252e%252e/a.png',
      '${base}19/a%2fb.png',
      '${base}19/a%5cb.png',
      '${base}19//a.png',
      base,
    ]) {
      expect(() => rutaCedula(url, base), throwsFormatException, reason: url);
    }
  });
}
