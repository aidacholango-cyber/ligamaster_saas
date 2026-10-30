import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TurnoVocalia extends StatefulWidget {
  const TurnoVocalia({super.key, required this.partidoId});
  final String partidoId;
  @override
  State<TurnoVocalia> createState() => _TurnoVocaliaState();
}

class _TurnoVocaliaState extends State<TurnoVocalia> {
  late Future<dynamic> _turno;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant TurnoVocalia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partidoId != widget.partidoId) _cargar();
  }

  void _cargar() {
    _turno = Supabase.instance.client.rpc(
      'lm_turno_vocalia',
      params: {'p_partido_id': widget.partidoId},
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _turno,
    builder: (context, snap) {
      if (snap.hasError || snap.data == null) return const SizedBox.shrink();
      final nombre = snap.data is Map ? snap.data['equipo'] : null;
      if (nombre == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: Chip(
            avatar: const Icon(Icons.groups_outlined, color: Color(0xFFBC1676)),
            label: Text('Equipo de vocalía: $nombre'),
            backgroundColor: const Color(0xFFFCE7F3),
          ),
        ),
      );
    },
  );
}
