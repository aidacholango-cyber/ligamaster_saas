import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/canchas.dart';
import 'pantalla_login.dart';

class PantallaTecnica extends StatefulWidget {
  const PantallaTecnica({super.key});
  @override
  State<PantallaTecnica> createState() => _PantallaTecnicaState();
}

class _PantallaTecnicaState extends State<PantallaTecnica> {
  Map<String, dynamic>? _datos;
  String? _campeonato, _fase, _error;
  bool _cargando = true;
  bool _borrando = false;
  List<Map<String, dynamic>> _lista(String clave) =>
      List<Map<String, dynamic>>.from(_datos?[clave] ?? []);
  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = Map<String, dynamic>.from(
        await Supabase.instance.client.rpc('lm_tecnica_catalogo'),
      );
      if (mounted) {
        setState(() {
          _datos = datos;
          if (!_lista('campeonatos').any((c) => c['id'] == _campeonato)) {
            _campeonato = null;
            _fase = null;
          }
          if (!_lista('fases').any((f) => f['id'] == _fase && f['campeonato_id'] == _campeonato)) {
            _fase = null;
          }
        });
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo cargar la programación.',
        );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([Map<String, dynamic>? partido]) async {
    final fase = _lista('fases').where((f) => f['id'] == _fase).firstOrNull;
    if (fase == null) return;
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => ProgramacionTecnicaDialog(
        fase: fase,
        equipos: _lista(
          'equipos',
        ).where((e) => e['campeonato_id'] == _campeonato).toList(),
        grupos: _lista('grupos').where((g) => g['fase_id'] == _fase).toList(),
        partido: partido,
      ),
    );
    if (guardado == true && mounted) await _leer();
  }

  Future<void> _borrar(Map<String, dynamic> partido) async {
    if (_borrando) return;
    final acepta = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar partido'),
      content: Text('¿Eliminar ${partido['local']} vs ${partido['visitante']} · Jornada ${partido['jornada']} · Partido ${partido['numero_partido']}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)), onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete_outline), label: const Text('Eliminar'))],
    ));
    if (acepta != true || !mounted) return;
    setState(() => _borrando = true);
    try {
      await Supabase.instance.client.rpc('lm_tecnica_borrar_partido', params: {'p_partido_id': partido['id']});
      if (mounted) await _leer();
    } catch (e) {
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : 'No se pudo eliminar el partido.');
    } finally { if (mounted) setState(() => _borrando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final campeonatos = _lista('campeonatos');
    final fases = _lista(
      'fases',
    ).where((f) => f['campeonato_id'] == _campeonato).toList();
    final partidos = _lista(
      'partidos',
    ).where((p) => p['fase_id'] == _fase).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comisión técnica'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _leer,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PantallaLogin()),
                  (_) => false,
                );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      const Text(
                        'LigaMaster SaaS',
                        style: TextStyle(
                          color: Color(0xFF4351BF),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Programación de partidos y turnos de vocalía',
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: 360,
                            child: DropdownButtonFormField<String>(
                              initialValue: _campeonato,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Liga · Campeonato · Categoría',
                                filled: true,
                                fillColor: Color(0xFFE2F2E8),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final c in campeonatos)
                                  DropdownMenuItem(
                                    value: c['id'].toString(),
                                    child: Text(
                                      '${c['liga']} · ${c['nombre']} · ${c['categoria']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                _campeonato = v;
                                _fase = null;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_campeonato),
                              initialValue: _fase,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Fase',
                                filled: true,
                                fillColor: Color(0xFFFCE7F3),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final f in fases)
                                  DropdownMenuItem(
                                    value: f['id'].toString(),
                                    child: Text('${f['nombre']}'),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _fase = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _fase == null || _borrando ? null : () => _editar(),
                        icon: const Icon(Icons.add),
                        label: const Text('Programar partido'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF166534),
                        ),
                      ),
                      for (final p in partidos)
                        Card(
                          color: const Color(0xFFEFF4FF),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            title: Text('${p['local']} vs ${p['visitante']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Jornada ${p['jornada']} · Partido ${p['numero_partido']}\n${fechaProgramacion(p['fecha_hora'])} · ${p['cancha'] ?? 'Sin cancha'}\nVocalía: ${p['equipo_vocal'] ?? 'Sin asignar'}',
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                            trailing: p['confirmado'] == true
                                ? const Icon(Icons.lock_outline)
                                : Row(mainAxisSize: MainAxisSize.min, children: [IconButton(
                                    tooltip: 'Editar programación',
                                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFCE7F3)),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Color(0xFFBC1676),
                                      size: 20,
                                    ),
                                    onPressed: _borrando ? null : () => _editar(p),
                                  ), const SizedBox(width: 6), IconButton(
                                    tooltip: 'Eliminar partido',
                                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFDE7E7)),
                                    onPressed: _borrando ? null : () => _borrar(p),
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318), size: 20),
                                  )]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

String fechaProgramacion(dynamic valor) {
  final d = DateTime.tryParse('$valor')?.toLocal();
  if (d == null) return 'Fecha por definir';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
}

class ProgramacionTecnicaDialog extends StatefulWidget {
  const ProgramacionTecnicaDialog({
    super.key,
    required this.fase,
    required this.equipos,
    required this.grupos,
    this.partido,
  });
  final Map<String, dynamic> fase;
  final List<Map<String, dynamic>> equipos, grupos;
  final Map<String, dynamic>? partido;
  @override
  State<ProgramacionTecnicaDialog> createState() =>
      _ProgramacionTecnicaDialogState();
}

class _ProgramacionTecnicaDialogState extends State<ProgramacionTecnicaDialog> {
  final _jornada = TextEditingController(text: '1');
  int? _local, _visitante, _vocal;
  String? _grupo, _cancha, _error;
  DateTime? _fecha;
  bool _guardando = false;
  @override
  void initState() {
    super.initState();
    final p = widget.partido;
    if (p != null) {
      _local = (p['equipo_local_id'] as num).toInt();
      _visitante = (p['equipo_visitante_id'] as num).toInt();
      _vocal = (p['equipo_vocal_id'] as num?)?.toInt();
      _grupo = p['grupo_id']?.toString();
      _cancha = canchaValida(p['cancha']);
      _fecha = DateTime.tryParse('${p['fecha_hora']}')?.toLocal();
      _jornada.text = '${p['jornada']}';
    }
  }

  @override
  void dispose() {
    _jornada.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final actual = _fecha ?? DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora != null && mounted)
      setState(
        () => _fecha = DateTime(
          dia.year,
          dia.month,
          dia.day,
          hora.hour,
          hora.minute,
        ),
      );
  }

  Future<void> _guardar() async {
    if (_local == null ||
        _visitante == null ||
        _local == _visitante ||
        _vocal == null ||
        _fecha == null ||
        _cancha == null ||
        (int.tryParse(_jornada.text) ?? 0) < 1 ||
        (widget.fase['tipo'] == 'grupos' && _grupo == null)) {
      setState(
        () => _error =
            'Completa equipos diferentes, jornada, fecha, horario, cancha y equipo de vocalía.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_tecnica_guardar_partido',
        params: {
          'p_fase': widget.fase['id'],
          'p_grupo': _grupo,
          'p_local': _local,
          'p_visitante': _visitante,
          'p_jornada': int.parse(_jornada.text),
          'p_fecha': _fecha!.toUtc().toIso8601String(),
          'p_cancha': _cancha,
          'p_vocal': _vocal,
          'p_partido': widget.partido?['id'],
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo guardar. Intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _equipo(
    String etiqueta,
    int? valor,
    ValueChanged<int?> cambio, {
    bool habilitado = true,
  }) => DropdownButtonFormField<int>(
    initialValue: valor,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: etiqueta,
      border: const OutlineInputBorder(),
    ),
    items: [
      if (valor != null && !widget.equipos.any((e) => e['equipo_id'] == valor))
        DropdownMenuItem(value: valor, enabled: false, child: Text('Equipo $valor (sin inscripción activa)')),
      for (final e in widget.equipos)
        DropdownMenuItem(
          value: (e['equipo_id'] as num).toInt(),
          child: Text('${e['nombre']}'),
        ),
    ],
    onChanged: _guardando || !habilitado ? null : cambio,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.partido == null ? 'Programar partido' : 'Editar programación',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _equipo(
              'Local',
              _local,
              (v) => setState(() => _local = v),
              habilitado: widget.partido == null,
            ),
            const SizedBox(height: 16),
            _equipo(
              'Visitante',
              _visitante,
              (v) => setState(() => _visitante = v),
              habilitado: widget.partido == null,
            ),
            const SizedBox(height: 16),
            if (widget.fase['tipo'] == 'grupos') ...[
              DropdownButtonFormField<String>(
                initialValue: _grupo,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: [
                  for (final g in widget.grupos)
                    DropdownMenuItem(
                      value: '${g['id']}',
                      child: Text('${g['nombre']}'),
                    ),
                ],
                onChanged: widget.partido != null || _guardando
                    ? null
                    : (v) => setState(() => _grupo = v),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _jornada,
              enabled: !_guardando,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jornada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBC1676),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _guardando ? null : _elegirFecha,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _fecha == null
                    ? 'Elegir fecha y horario'
                    : fechaProgramacion(_fecha!.toIso8601String()),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cancha,
              decoration: const InputDecoration(
                labelText: 'Cancha',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in canchasDisponibles)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: _guardando ? null : (v) => setState(() => _cancha = v),
            ),
            const SizedBox(height: 16),
            _equipo(
              'Equipo encargado de la vocalía',
              _vocal,
              (v) => setState(() => _vocal = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}
