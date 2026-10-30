import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estado_cuenta.dart';
import 'movimiento_tesoreria_dialog.dart';

/// Recaudación del equipo en el partido abierto por el vocal de la jornada.
/// La autorización y el equipo/partido se comprueban también en Supabase.
class CobranzaVocal extends StatefulWidget {
  const CobranzaVocal({
    super.key,
    required this.partidoId,
    required this.equipoId,
    this.habilitado = true,
  });
  final String partidoId;
  final int equipoId;
  final bool habilitado;
  @override
  State<CobranzaVocal> createState() => _CobranzaVocalState();
}

class _CobranzaVocalState extends State<CobranzaVocal> {
  late Future<Map<String, dynamic>> _datos;
  bool _abriendo = false;
  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  @override
  void didUpdateWidget(covariant CobranzaVocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partidoId != widget.partidoId ||
        oldWidget.equipoId != widget.equipoId)
      _datos = _leer();
  }

  Future<Map<String, dynamic>> _leer() async => Map<String, dynamic>.from(
    await Supabase.instance.client.rpc(
      'lm_tesoreria_cobranza_vocal',
      params: {
        'p_partido_id': widget.partidoId,
        'p_equipo_id': widget.equipoId,
      },
    ),
  );

  Future<void> _registrar(Map<String, dynamic> datos, String tipo) async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    try {
      final guardado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MovimientoTesoreriaDialog(
          ligaId: '${datos['liga_id']}',
          equipoId: widget.equipoId,
          partido: {...datos, 'partido_id': widget.partidoId},
          tipoInicial: tipo,
        ),
      );
      if (guardado == true && mounted)
        setState(() {
          _datos = _leer();
        });
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _datos,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return TextButton.icon(
          onPressed: () => setState(() {
            _datos = _leer();
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('No se pudo cargar la recaudación. Reintentar'),
        );
      if (!snapshot.hasData)
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Cargando recaudación…'),
        );
      final datos = snapshot.data!;
      if (datos['cobro'] == null)
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'El administrador debe publicar el cobro de este equipo para registrar el dinero recibido.',
            textAlign: TextAlign.center,
          ),
        );
      final balances = balancesTesoreria([datos]);
      final puede =
          widget.habilitado && datos['puede_registrar'] == true && !_abriendo;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            for (final b in balances.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Recibido: ${b.key} ${dineroTesoreria(b.value.recibido)} · '
                  'Pagado al árbitro: ${b.key} ${dineroTesoreria(b.value.arbitros)} · '
                  'Saldo: ${b.key} ${dineroTesoreria(b.value.saldo)}',
                  textAlign: TextAlign.center,
                ),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF166534),
                  ),
                  onPressed: puede
                      ? () => _registrar(datos, 'aporte_equipo')
                      : null,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Recibido del equipo'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF925900),
                  ),
                  onPressed: puede
                      ? () => _registrar(datos, 'pago_arbitro')
                      : null,
                  icon: const Icon(Icons.sports, size: 18),
                  label: const Text('Pagado al árbitro'),
                ),
                IconButton(
                  onPressed: _abriendo
                      ? null
                      : () => setState(() {
                          _datos = _leer();
                        }),
                  tooltip: 'Actualizar recaudación',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Registra solo el dinero de este equipo. En el pago al árbitro, ingresa únicamente la parte de este equipo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    },
  );
}
