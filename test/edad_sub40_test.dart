import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/edad_sub40.dart';

void main() {
  final hoy = DateTime(2026, 10, 24);
  test('acepta 39 años por año calendario, sin importar mes ni día', () {
    for (final fecha in [DateTime(1987, 1, 1), DateTime(1987, 12, 31), DateTime(1980, 6, 1)]) {
      expect(errorEdadSub40(fecha, hoy: hoy), isNull);
    }
    expect(edadSub40(DateTime(1987, 12, 31), hoy: hoy), 39);
  });
  test('permite inscribir la excepción de 38 y rechaza 37 o menos', () {
    expect(errorEdadSub40(DateTime(1988, 1, 1), hoy: hoy), isNull);
    expect(errorEdadSub40(DateTime(1988, 12, 31), hoy: hoy), isNull);
    expect(errorEdadSub40(DateTime(1989, 1, 1), hoy: hoy), isNotNull);
    expect(errorEdadSub40(DateTime(2010, 2, 12), hoy: hoy), isNotNull);
  });
}
