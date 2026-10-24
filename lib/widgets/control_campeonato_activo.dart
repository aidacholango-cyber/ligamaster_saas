import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlCampeonatoActivo extends StatefulWidget {
  const ControlCampeonatoActivo({super.key, required this.campeonato, required this.alGuardar});
  final Map<String, dynamic> campeonato;
  final VoidCallback alGuardar;
  @override
  State<ControlCampeonatoActivo> createState() => _ControlState();
}
class _ControlState extends State<ControlCampeonatoActivo> {
  bool _ocupado = false;
  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try { await accion(); if (mounted) widget.alGuardar(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is PostgrestException ? e.message : e.toString())));
    } finally { if (mounted) setState(() => _ocupado = false); }
  }
  Future<void> _fechas() async {
    final c = widget.campeonato;
    final inicio = DateTime.tryParse('${c['fecha_inicio']}');
    final fin = DateTime.tryParse('${c['fecha_fin']}');
    final rango = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _CalendarioCampeonato(inicio: inicio, fin: fin),
    );
    if (rango == null || !mounted) return;
    await _ejecutar(() async {
      await Supabase.instance.client.rpc('lm_configurar_fechas_campeonato', params: {
        'p_campeonato_id': c['id'],
        'p_inicio': rango.start.toIso8601String().split('T').first,
        'p_fin': rango.end.toIso8601String().split('T').first,
      });
    });
  }
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white),
        onPressed: _ocupado ? null : _fechas,
        icon: const Icon(Icons.date_range), label: const Text('Fechas del campeonato')),
      if (widget.campeonato['fecha_inicio'] != null && widget.campeonato['fecha_fin'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${widget.campeonato['fecha_inicio']} · ${widget.campeonato['fecha_fin']}',
            style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 16),
      const Text('Campeonato activo', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      SizedBox(width: 300, child: DropdownButtonFormField<bool>(
        key: ValueKey('${widget.campeonato['id']}:${widget.campeonato['activo']}'),
        initialValue: widget.campeonato['activo'] == true,
        decoration: InputDecoration(
          filled: true,
          fillColor: widget.campeonato['activo'] == true ? const Color(0xFFE2F3E8) : const Color(0xFFFFF0DC),
          prefixIcon: Icon(Icons.sports_soccer, color: widget.campeonato['activo'] == true
              ? const Color(0xFF166534) : const Color(0xFF975A00)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: const [DropdownMenuItem(value: true, child: Text('Activar')),
          DropdownMenuItem(value: false, child: Text('Desactivar'))],
        onChanged: _ocupado ? null : (activo) {
          if (activo == null) return;
          _ejecutar(() async {
            await Supabase.instance.client.rpc('lm_activar_campeonato', params: {
              'p_campeonato_id': widget.campeonato['id'], 'p_activo': activo,
            });
          });
        },
      )),
      const SizedBox(height: 12),
    ],
  );
}

class _CalendarioCampeonato extends StatefulWidget {
  const _CalendarioCampeonato({this.inicio, this.fin});
  final DateTime? inicio, fin;
  @override
  State<_CalendarioCampeonato> createState() => _CalendarioState();
}

class _CalendarioState extends State<_CalendarioCampeonato> {
  DateTime? _inicio, _fin;
  bool _eligiendoInicio = true;
  @override
  void initState() {
    super.initState();
    _inicio = widget.inicio;
    _fin = widget.fin;
  }
  String _texto(DateTime? fecha) => fecha == null
      ? 'Elegir fecha'
      : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Fechas del campeonato'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: TextButton(
                style: TextButton.styleFrom(backgroundColor: _eligiendoInicio
                    ? Theme.of(context).colorScheme.primaryContainer : null),
                onPressed: () => setState(() => _eligiendoInicio = true),
                child: Text('Inicio\n${_texto(_inicio)}', textAlign: TextAlign.center),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextButton(
                style: TextButton.styleFrom(backgroundColor: !_eligiendoInicio
                    ? Theme.of(context).colorScheme.primaryContainer : null),
                onPressed: () => setState(() => _eligiendoInicio = false),
                child: Text('Fin\n${_texto(_fin)}', textAlign: TextAlign.center),
              )),
            ]),
            CalendarDatePicker(
              key: ValueKey(_eligiendoInicio),
              initialDate: (_eligiendoInicio ? _inicio : _fin) ?? _inicio ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (fecha) => setState(() {
                if (_eligiendoInicio) {
                  _inicio = fecha;
                  if (_fin != null && _fin!.isBefore(fecha)) _fin = null;
                } else {
                  _fin = fecha;
                }
              }),
            ),
            if (_inicio != null && _fin != null && _fin!.isBefore(_inicio!))
              const Text('La fecha final debe ser igual o posterior al inicio.',
                style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: _inicio == null || _fin == null || _fin!.isBefore(_inicio!)
            ? null : () => Navigator.pop(context, DateTimeRange(start: _inicio!, end: _fin!)),
        child: const Text('Guardar'),
      ),
    ],
  );
}
