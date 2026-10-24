import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool?> editarConteoPartidos(
  BuildContext context, {
  required String inscripcionId,
  required int total,
  required int ajuste,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _EditarConteo(inscripcionId: inscripcionId, total: total, ajuste: ajuste),
);

class _EditarConteo extends StatefulWidget {
  const _EditarConteo({
    required this.inscripcionId,
    required this.total,
    required this.ajuste,
  });
  final String inscripcionId;
  final int total, ajuste;
  @override
  State<_EditarConteo> createState() => _EditarConteoState();
}

class _EditarConteoState extends State<_EditarConteo> {
  final _form = GlobalKey<FormState>();
  late final _total = TextEditingController(text: '${widget.total}');
  final _motivo = TextEditingController();
  bool _ocupado = false;
  String? _error;
  @override
  void dispose() {
    _total.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar({bool restaurar = false}) async {
    if (_ocupado || !_form.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_corregir_conteo_jugador',
        params: {
          'p_inscripcion_id': widget.inscripcionId,
          'p_total': restaurar ? null : int.parse(_total.text),
          'p_ajuste_anterior': widget.ajuste,
          'p_motivo': _motivo.text.trim(),
        },
      );
      if (mounted) {
        setState(() => _ocupado = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo guardar la corrección.',
        );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('Editar conteo de partidos'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'La corrección se suma al conteo automático. Los siguientes partidos confirmados seguirán sumando normalmente.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _total,
                  enabled: !_ocupado,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Total correcto de partidos',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 0 || n > 10000
                        ? 'Ingresa un total entre 0 y 10000.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivo,
                  enabled: !_ocupado,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la corrección',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe el motivo.' : null,
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _ocupado ? null : () => _guardar(restaurar: true),
          child: const Text('Usar solo automático'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: const Text('Guardar corrección'),
        ),
      ],
    ),
  );
}
