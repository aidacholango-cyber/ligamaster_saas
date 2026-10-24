import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectorCampeonatoVigente extends StatefulWidget {
  const SelectorCampeonatoVigente({super.key, required this.equipoId,
    this.categoria, this.administrador = false, this.habilitado = true,
    this.alSeleccionar, this.idsPermitidos});
  final String equipoId;
  final String? categoria;
  final bool administrador, habilitado;
  final Set<String>? idsPermitidos;
  final ValueChanged<Map<String, dynamic>>? alSeleccionar;
  @override
  State<SelectorCampeonatoVigente> createState() => _SelectorState();
}

class _SelectorState extends State<SelectorCampeonatoVigente> {
  List<Map<String, dynamic>> _lista = [];
  String? _id, _error;
  bool _cargando = true;
  @override
  void initState() { super.initState(); _leer(); }
  @override
  void didUpdateWidget(covariant SelectorCampeonatoVigente old) {
    super.didUpdateWidget(old);
    if (old.equipoId != widget.equipoId || old.categoria != widget.categoria) _leer();
  }
  bool _vigente(Map<String, dynamic> c) {
    final hoy = DateTime.now();
    final fecha = DateTime(hoy.year, hoy.month, hoy.day);
    final inicio = DateTime.tryParse('${c['fecha_inicio']}');
    final fin = DateTime.tryParse('${c['fecha_fin']}');
    return inicio != null && fin != null && !fecha.isBefore(inicio) &&
      !fecha.isAfter(fin) && !['finalizado', 'archivado'].contains(c['estado']);
  }
  Future<void> _leer() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final datos = await Supabase.instance.client.rpc('lm_campeonatos_vigencia_equipo',
        params: {'p_equipo_id': int.parse(widget.equipoId)});
      if (!mounted) return;
      final lista = List<Map<String, dynamic>>.from(datos).where(
        (c) => (widget.categoria == null || c['categoria'] == widget.categoria) &&
          (widget.idsPermitidos == null || widget.idsPermitidos!.contains(c['id'].toString()))).toList();
      final elegido = lista.where((c) => c['id'].toString() == _id).firstOrNull ??
        lista.where(_vigente).firstOrNull ?? lista.firstOrNull;
      setState(() { _lista = lista; _id = elegido?['id'].toString(); });
      if (elegido != null) widget.alSeleccionar?.call(elegido);
    } catch (e) {
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : e.toString());
    } finally { if (mounted) setState(() => _cargando = false); }
  }
  Future<void> _fechas(Map<String, dynamic> c) async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(context: context,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      initialDateRange: c['fecha_inicio'] != null && c['fecha_fin'] != null
        ? DateTimeRange(start: DateTime.parse(c['fecha_inicio']), end: DateTime.parse(c['fecha_fin'])) : null,
      currentDate: ahora, helpText: 'Inicio y fin del campeonato', saveText: 'Guardar');
    if (rango == null || !mounted) return;
    setState(() => _cargando = true);
    try {
      await Supabase.instance.client.rpc('lm_configurar_fechas_campeonato', params: {
        'p_campeonato_id': c['id'],
        'p_inicio': rango.start.toIso8601String().split('T').first,
        'p_fin': rango.end.toIso8601String().split('T').first,
      });
      if (mounted) await _leer();
    } catch (e) {
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : e.toString());
    } finally { if (mounted) setState(() => _cargando = false); }
  }
  @override
  Widget build(BuildContext context) {
    final c = _lista.where((c) => c['id'].toString() == _id).firstOrNull;
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!), TextButton(onPressed: _leer, child: const Text('Reintentar')),
        ],
        if (!_cargando && _lista.isEmpty && _error == null) const Text('No hay campeonatos en esta categoría.'),
        if (c != null) ...[
          DropdownButtonFormField<String>(key: ValueKey('${widget.equipoId}:${widget.categoria}:$_id'),
            initialValue: _id, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Campeonato', border: OutlineInputBorder()),
            items: [for (final item in _lista) DropdownMenuItem(value: item['id'].toString(),
              child: Text('${item['nombre']} · ${item['categoria']}${_vigente(item) ? ' · Vigente' : ''}', overflow: TextOverflow.ellipsis))],
            onChanged: _cargando || !widget.habilitado ? null : (id) {
              setState(() => _id = id);
              widget.alSeleccionar?.call(_lista.firstWhere((c) => c['id'].toString() == id));
            }),
          Text(c['fecha_inicio'] == null || c['fecha_fin'] == null ? 'Fechas del campeonato sin configurar'
            : 'Inicio: ${c['fecha_inicio']} · Fin: ${c['fecha_fin']}'),
          if (widget.administrador) TextButton.icon(onPressed: _cargando ? null : () => _fechas(c),
            icon: const Icon(Icons.date_range), label: const Text('Fechas del campeonato')),
        ],
      ])));
  }
}
