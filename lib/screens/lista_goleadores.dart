import 'package:flutter/material.dart';

/// Presentación común para administrador y delegado, por campeonato/categoría.
class ListaGoleadores extends StatelessWidget {
  final List<Map<String, dynamic>> jugadores;
  const ListaGoleadores({super.key, required this.jugadores});

  int _goles(Map<String, dynamic> j) =>
      int.tryParse('${j['goles']}') ?? 0;
  String _nombre(Map<String, dynamic> j) =>
      '${j['nombres'] ?? ''} ${j['apellidos'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final ordenados = List<Map<String, dynamic>>.of(jugadores)
      ..sort((a, b) {
        final diferencia = _goles(b).compareTo(_goles(a));
        return diferencia != 0 ? diferencia : _nombre(a).compareTo(_nombre(b));
      });
    var posicion = 0;
    int? anteriores;
    final tarjetas = <Widget>[];
    for (final jugador in ordenados) {
      final goles = _goles(jugador);
      if (goles != anteriores) posicion++;
      anteriores = goles;
      final lider = posicion == 1;
      final color = lider ? const Color(0xFF166534) : const Color(0xFF4351BF);
      final foto = jugador['foto_url']?.toString().trim() ?? '';
      final avatar = Container(
        width: 84, height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: color, width: 3)),
        padding: const EdgeInsets.all(3),
        child: ClipOval(child: foto.isEmpty
          ? const ColoredBox(color: Color(0xFFE8EAF6),
              child: Icon(Icons.person, size: 44, color: Color(0xFF4351BF)))
          : Image.network(foto, fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE8EAF6),
                child: Icon(Icons.person, size: 44, color: Color(0xFF4351BF))))),
      );
      tarjetas.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lider ? const Color(0xFFF0FDF4) : const Color(0xFFF5F5FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lider ? const Color(0xFF86CBA2) : const Color(0xFFDADCF2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 42, child: Column(children: [
            Icon(lider ? Icons.emoji_events : Icons.sports_soccer,
              color: lider ? const Color(0xFF946200) : color),
            const SizedBox(height: 4),
            Text('$posicion', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.bold, color: color)),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(children: [
            avatar,
            const SizedBox(height: 8),
            Text(_nombre(jugador), textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${jugador['equipo'] ?? ''}', textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13)),
          ])),
          const SizedBox(width: 8),
          Container(width: 64, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('$goles', style: const TextStyle(color: Colors.white,
                fontSize: 28, fontWeight: FontWeight.bold)),
              Text(goles == 1 ? 'GOL' : 'GOLES',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            ])),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: tarjetas);
  }
}

