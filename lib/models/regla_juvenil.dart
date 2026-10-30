bool aplicaReglaJuvenil(String? categoria) =>
    const ['Fútbol Senior', 'Femenino', 'Sub 40'].contains(categoria);

DateTime? nacimientoJuvenil(Object? valor) {
  final texto = valor?.toString().trim() ?? '';
  final partes = texto.split('/');
  if (partes.length == 3) {
    final d = int.tryParse(partes[0]),
        m = int.tryParse(partes[1]),
        a = int.tryParse(partes[2]);
    if (d == null || m == null || a == null) return null;
    final fecha = DateTime(a, m, d);
    return fecha.year == a && fecha.month == m && fecha.day == d ? fecha : null;
  }
  return DateTime.tryParse(texto);
}

/// Día oficial del encuentro, usando la misma zona de las jornadas de vocalía.
DateTime? fechaReglaJuvenil(Object? valor) {
  final texto = valor?.toString() ?? '';
  final fecha = DateTime.tryParse(texto);
  if (fecha == null) return null;
  final local = texto.contains('T')
      ? fecha.toUtc().subtract(const Duration(hours: 5))
      : fecha;
  return DateTime(local.year, local.month, local.day);
}

bool cumpleReglaJuvenil(
  String categoria,
  DateTime nacimiento,
  DateTime partido,
) {
  if (nacimiento.isAfter(partido)) return false;
  if (categoria == 'Sub 40') return partido.year - nacimiento.year == 38;
  var edad = partido.year - nacimiento.year;
  if (partido.month < nacimiento.month ||
      (partido.month == nacimiento.month && partido.day < nacimiento.day))
    edad--;
  return edad < 18;
}

/// La obligación se comprueba en los titulares, sin reloj ni cambio de tiempo.
String? validarReglaJuvenil({
  required String categoria,
  required DateTime? fecha,
  required List<Map<String, dynamic>> jugadores,
  required List<Map<String, dynamic>> filas,
}) {
  if (!aplicaReglaJuvenil(categoria) || filas.isEmpty) return null;
  if (fecha == null)
    return 'Programa la fecha del partido para validar la edad del juvenil.';
  final catalogo = {for (final j in jugadores) '${j['id']}': j};
  final equipos = <Object?>{
    for (final f in filas) catalogo['${f['id']}']?['equipo_id'],
  };
  for (final f in filas) {
    final j = catalogo['${f['id']}'];
    final nacimiento = nacimientoJuvenil(j?['fecha_nacimiento']);
    if (j == null || nacimiento == null || nacimiento.isAfter(fecha)) {
      return 'Un jugador no tiene fecha de nacimiento válida. Corrige su ficha antes de ingresarlo.';
    }
    if (categoria == 'Sub 40' && fecha.year - nacimiento.year < 38) {
      return 'Sub 40 solo admite jugadores de 39 años en adelante y la excepción de 38 años.';
    }
  }
  bool juvenil(Map<String, dynamic> f) => cumpleReglaJuvenil(
    categoria,
    nacimientoJuvenil(catalogo['${f['id']}']!['fecha_nacimiento'])!,
    fecha,
  );
  for (final equipo in equipos) {
    final delEquipo = filas
        .where((f) => catalogo['${f['id']}']?['equipo_id'] == equipo)
        .toList();
    final iniciales = delEquipo.where((f) => f['tipo'] != 'cambio').toList();
    if (iniciales.length > 10 && !iniciales.any(juvenil)) {
      return categoria == 'Sub 40'
          ? 'Primer tiempo: sin el jugador de 38 años, el equipo solo puede jugar con 10.'
          : 'Primer tiempo: para jugar con 11 titulares debe haber al menos un menor de 18 años.';
    }
    if (categoria == 'Sub 40' && iniciales.where(juvenil).length > 1) {
      return 'Sub 40 permite máximo un jugador de 38 años en cancha a la vez.';
    }
    if (categoria == 'Sub 40') {
      final salidas = {
        for (final f in delEquipo)
          if (f['sale_id'] != null) '${f['sale_id']}',
      };
      final activos = delEquipo
          .where((f) => !salidas.contains('${f['id']}'))
          .toList();
      if (categoria == 'Sub 40' && activos.where(juvenil).length > 1) {
        return 'Sub 40 permite máximo un jugador de 38 años en cancha a la vez. Indica quién sale.';
      }
    }
  }
  return null;
}
