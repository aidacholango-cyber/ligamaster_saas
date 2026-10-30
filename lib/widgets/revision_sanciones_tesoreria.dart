import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevisionSancionesTesoreria extends StatefulWidget {
  const RevisionSancionesTesoreria({
    super.key,
    required this.partidoId,
    required this.equipoId,
  });
  final String partidoId, equipoId;
  @override
  State<RevisionSancionesTesoreria> createState() =>
      _RevisionSancionesTesoreriaState();
}

class _RevisionSancionesTesoreriaState
    extends State<RevisionSancionesTesoreria> {
  late Future<dynamic> _datos;
  void _leer() {
    _datos = Supabase.instance.client.rpc(
      'lm_penas_envio_tesoreria',
      params: {
        'p_partido_id': widget.partidoId,
        'p_equipo_id': int.parse(widget.equipoId),
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _leer();
  }

  @override
  void didUpdateWidget(covariant RevisionSancionesTesoreria old) {
    super.didUpdateWidget(old);
    if (old.partidoId != widget.partidoId || old.equipoId != widget.equipoId)
      _leer();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _datos,
    builder: (context, snap) {
      if (snap.hasError) {
        final e = snap.error;
        if (e is PostgrestException &&
            (e.code == 'PGRST202' || e.code == '42883'))
          return const SizedBox.shrink();
        return TextButton.icon(
          onPressed: () => setState(_leer),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar consulta de sanciones revisadas'),
        );
      }
      if (snap.data is! Map) return const SizedBox.shrink();
      final datos = snap.data as Map;
      final filas = List<Map<String, dynamic>>.from(datos['jugadores'] ?? []);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2CF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Penas y sanciones · Revisión ${datos['revision']}',
              style: const TextStyle(
                color: Color(0xFF925900),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (datos['desactualizada'] == true)
              const Text(
                'La hoja cambió después del envío. Solicita una nueva revisión antes de cobrar.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            if (datos['hay_revision_posterior'] == true)
              const Text(
                'Hay una revisión posterior que todavía no se ha enviado a Tesorería.',
              ),
            Text('${datos['observaciones'] ?? ''}'),
            for (final j in filas)
              Text(
                'N.º ${j['camiseta'] ?? '—'} · ${j['nombre']} · T.A. ${j['ta']} · T.R. ${j['tr'] == true ? 'Sí' : 'No'}${j['suspension_manual'] == null ? '' : ' · Suspensión manual: ${j['suspension_manual']} partidos'}',
              ),
            if (filas.isEmpty)
              const Text(
                'Sin tarjetas ni suspensiones informadas para este equipo.',
              ),
            const SizedBox(height: 6),
            const Text(
              'Los importes se ingresan manualmente en los cobros. Este envío no genera ni duplica valores.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
