import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/edad_sub12.dart';

void main() {
  final hoy = DateTime(2026, 10, 24);
  test('rechaza nacidos en 2010 y hasta el último día de 2013', () {
    expect(errorEdadSub12(DateTime(2010, 2, 12), hoy: hoy), isNotNull);
    expect(errorEdadSub12(DateTime(2013, 12, 31), hoy: hoy), isNotNull);
  });
  test('acepta 2014 en cualquier mes y años posteriores', () {
    for (final fecha in [DateTime(2014, 1, 1), DateTime(2014, 12, 31), DateTime(2015, 6, 1)]) {
      expect(errorEdadSub12(fecha, hoy: hoy), isNull);
    }
    expect(edadSub12(DateTime(2014, 12, 31), hoy: hoy), 12);
  });
}
