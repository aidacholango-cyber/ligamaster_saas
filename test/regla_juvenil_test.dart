import 'package:flutter_test/flutter_test.dart';
import 'package:liga_el_rosario/models/regla_juvenil.dart';

void main() {
  final fecha = DateTime(2026, 10, 29);
  List<Map<String, dynamic>> catalogo({
    bool sub40 = false,
    int juveniles = 0,
  }) => [
    for (var i = 1; i <= 12; i++)
      {
        'id': '$i',
        'equipo_id': 1,
        'fecha_nacimiento': i <= juveniles
            ? (sub40 ? '31/12/1988' : '30/10/2008')
            : sub40
            ? '01/01/1980'
            : '01/01/1990',
      },
  ];
  List<Map<String, dynamic>> filas(int cuantos) => [
    for (var i = 1; i <= cuantos; i++) {'id': '$i', 'tipo': 'titular'},
  ];
  String? validar(
    String categoria,
    List<Map<String, dynamic>> jugadores,
    List<Map<String, dynamic>> alineacion,
  ) => validarReglaJuvenil(
    categoria: categoria,
    fecha: fecha,
    jugadores: jugadores,
    filas: alineacion,
  );

  test('Senior/Femenino: 10 sin juvenil sí; 11 sin juvenil no', () {
    for (final c in ['Fútbol Senior', 'Femenino']) {
      expect(validar(c, catalogo(), filas(10)), isNull);
      expect(validar(c, catalogo(), filas(11)), isNotNull);
      expect(validar(c, catalogo(juveniles: 1), filas(11)), isNull);
      expect(validar(c, catalogo(juveniles: 3), filas(11)), isNull);
    }
  });
  test('menor de 18 en el día oficial del encuentro, no por año solamente', () {
    expect(
      cumpleReglaJuvenil('Femenino', DateTime(2008, 10, 30), fecha),
      isTrue,
    );
    expect(
      cumpleReglaJuvenil('Femenino', DateTime(2008, 10, 29), fecha),
      isFalse,
    );
    expect(
      cumpleReglaJuvenil('Femenino', DateTime(2008, 10, 28), fecha),
      isFalse,
    );
  });
  test('la falta de juvenil en un equipo no se compensa con el del rival', () {
    final jugadores = [
      ...catalogo(),
      {'id': 'rival', 'equipo_id': 2, 'fecha_nacimiento': '01/01/2010'},
    ];
    expect(
      validar('Fútbol Senior', jugadores, [
        ...filas(11),
        {'id': 'rival', 'tipo': 'titular'},
      ]),
      isNotNull,
    );
  });
  test(
    'los suplentes no satisfacen el juvenil requerido entre los titulares',
    () {
      final jugadores = catalogo();
      jugadores.last['fecha_nacimiento'] = '01/01/2010';
      expect(
        validar('Fútbol Senior', jugadores, [
          ...filas(11),
          {'id': '12', 'tipo': 'cambio'},
        ]),
        isNotNull,
      );
      // Puede completar desde la tabla de cambios, sin alterar los diez titulares.
      expect(
        validar('Fútbol Senior', jugadores, [
          ...filas(10),
          {'id': '11', 'tipo': 'cambio'},
        ]),
        isNull,
      );
    },
  );
  test(
    'Sub 40: uno de 38 habilita 11; dos están prohibidos; sin él admite 10',
    () {
      expect(validar('Sub 40', catalogo(sub40: true), filas(10)), isNull);
      expect(validar('Sub 40', catalogo(sub40: true), filas(11)), isNotNull);
      expect(
        validar('Sub 40', catalogo(sub40: true, juveniles: 1), filas(11)),
        isNull,
      );
      expect(
        validar('Sub 40', catalogo(sub40: true, juveniles: 2), filas(11)),
        isNotNull,
      );
    },
  );
  test('Sub 40 permite reemplazar al de 38 con otro de 38, sin coincidir', () {
    final jugadores = catalogo(sub40: true, juveniles: 1);
    jugadores.last['fecha_nacimiento'] = '01/01/1988';
    expect(
      validar('Sub 40', jugadores, [
        ...filas(11),
        {'id': '12', 'tipo': 'cambio', 'sale_id': '1'},
      ]),
      isNull,
    );
    expect(
      validar('Sub 40', jugadores, [
        ...filas(11),
        {'id': '12', 'tipo': 'cambio', 'sale_id': '2'},
      ]),
      isNotNull,
    );
  });
  test('no aplica a Sub 12 y no adivina edades si faltan datos', () {
    expect(validar('Sub 12', [], filas(11)), isNull);
    expect(validar('Fútbol Senior', [], filas(1)), isNotNull);
    expect(
      validarReglaJuvenil(
        categoria: 'Fútbol Senior',
        fecha: null,
        jugadores: catalogo(),
        filas: filas(10),
      ),
      isNotNull,
    );
  });
}
