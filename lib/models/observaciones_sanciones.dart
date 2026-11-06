import 'dart:convert';

class ObservacionesSanciones {
  String general = '';
  final Map<String, String> equipos = {};

  ObservacionesSanciones(String texto) {
    try {
      final datos = jsonDecode(texto);
      if (datos is Map &&
          datos['formato'] == 'penas_equipos_v1' &&
          datos['equipos'] is Map) {
        general = '${datos['general'] ?? ''}';
        for (final e in (datos['equipos'] as Map).entries) {
          equipos['${e.key}'] = '${e.value}';
        }
        return;
      }
    } catch (_) {}
    general = texto;
  }

  String guardar() => jsonEncode({
    'formato': 'penas_equipos_v1',
    'general': general,
    'equipos': equipos,
  });
}
