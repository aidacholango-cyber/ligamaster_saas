import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'editar_conteo_partidos.dart';

Future<Map<String, dynamic>> leerConteoSanciones(String partidoId) async {
  final db = Supabase.instance.client;
  try {
    return Map<String, dynamic>.from(
      await db.rpc(
        'lm_penas_conteo_jugadores',
        params: {'p_partido_id': partidoId},
      ),
    );
  } on PostgrestException catch (e) {
    if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    // El RPC anterior solo autoriza al administrador.
    return {
      'puede_editar': true,
      'conteos': await db.rpc(
        'lm_conteo_partidos_jugadores',
        params: {'p_partido_id': partidoId},
      ),
    };
  }
}

class ConteoRevisionSanciones extends StatelessWidget {
  const ConteoRevisionSanciones({
    super.key,
    required this.datos,
    required this.jugador,
    required this.recargar,
  });
  final Future<Map<String, dynamic>> datos;
  final Map<String, dynamic> jugador;
  final Future<Map<String, dynamic>> Function() recargar;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: datos,
    builder: (context, snap) {
      final conteo =
          (snap.data?['conteos'] as Map?)?['${jugador['id']}'] as Map?;
      final disciplina =
          (snap.data?['disciplina'] as Map?)?['${jugador['id']}'] as Map?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snap.data?.containsKey('disciplina') == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    backgroundColor: const Color(0xFFFFF2CF),
                    label: Text(
                      'T.A. acumuladas: ${disciplina?['amarillas_total'] ?? 0}',
                    ),
                  ),
                  Chip(
                    backgroundColor: const Color(0xFFFFE9E7),
                    label: Text(
                      'T.R. directas: ${disciplina?['rojas_directas'] ?? 0}',
                    ),
                  ),
                  Chip(
                    backgroundColor: const Color(0xFFFFE9E7),
                    label: Text(
                      'Doble amarilla: ${disciplina?['expulsiones_doble_amarilla'] ?? 0}',
                    ),
                  ),
                  Chip(
                    backgroundColor: const Color(0xFFF0F4FF),
                    label: Text(
                      'Ciclo T.A.: ${disciplina?['amarillas_ciclo_actual'] ?? 0}/5',
                    ),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFCE6F3),
              foregroundColor: const Color(0xFF98105B),
            ),
            icon: const Icon(Icons.event_available, size: 18),
            label: Text(
              snap.hasError
                  ? 'Reintentar conteo de partidos'
                  : !snap.hasData
                  ? 'Cargando conteo…'
                  : conteo == null
                  ? 'Conteo no disponible'
                  : 'Partidos jugados: ${conteo['total']}',
            ),
            onPressed: snap.hasError
                ? () async {
                    try {
                      await recargar();
                    } catch (_) {}
                  }
                : conteo == null
                ? null
                : () async {
                    Map actual = conteo;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, actualizar) => AlertDialog(
                          title: Text('Partidos · ${jugador['nombre']}'),
                          content: SizedBox(
                            width: 420,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total en este campeonato: ${actual['total']}',
                                  ),
                                  Text(
                                    'Automático: ${actual['automatico']} · Ajuste manual: ${actual['ajuste']}',
                                  ),
                                  const SizedBox(height: 12),
                                  for (final p
                                      in actual['partidos'] as List? ?? [])
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        'Jornada ${p['jornada']} · Partido ${p['numero_partido']}',
                                      ),
                                      subtitle: Text(
                                        '${p['local']} vs ${p['visitante']}',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar'),
                            ),
                            if (snap.data?['puede_editar'] == true)
                              FilledButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar conteo'),
                                onPressed: () async {
                                  final guardado = await editarConteoPartidos(
                                    ctx,
                                    inscripcionId: '${jugador['id']}',
                                    total: (actual['total'] as num).toInt(),
                                    ajuste: (actual['ajuste'] as num).toInt(),
                                  );
                                  if (guardado != true || !ctx.mounted) return;
                                  try {
                                    final nuevos = await recargar();
                                    if (ctx.mounted)
                                      actualizar(() {
                                        actual =
                                            (nuevos['conteos']
                                                    as Map)['${jugador['id']}']
                                                as Map;
                                      });
                                  } catch (_) {
                                    if (ctx.mounted)
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'La corrección se guardó. Reintenta actualizar el conteo.',
                                          ),
                                        ),
                                      );
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
          ),
        ],
      );
    },
  );
}
