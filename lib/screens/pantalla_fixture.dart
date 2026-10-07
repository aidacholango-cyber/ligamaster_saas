import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_planilla_resultado.dart';

const _azul = Color(0xFF4351BF);
const _tipos = {
  'todos_contra_todos': 'Todos contra todos',
  'grupos': 'Grupos',
  'eliminatoria': 'Eliminatorias',
};
const _etapas = {
  'regular': 'Fase regular',
  'octavos': 'Octavos',
  'cuartos': 'Cuartos',
  'semifinal': 'Semifinal',
  'tercer_puesto': 'Tercer puesto',
  'final': 'Final',
};
String _error(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23505')
      return 'Ya existe un registro con ese nombre o número. Actualiza la pantalla.';
    if (e.code == '42501') return 'No tienes permiso para esta operación.';
    return e.message;
  }
  if (e is StateError) return e.message.toString();
  return 'No se pudo completar la operación. Comprueba tu conexión.';
}

List<Map<String, dynamic>> _filas(dynamic value) =>
    List<Map<String, dynamic>>.from(value as List);
String _fecha(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return 'Fecha y hora por definir';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year} · ${dos(d.hour)}:${dos(d.minute)}';
}

class PantallaFixture extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  const PantallaFixture({super.key, required this.campeonato});
  @override
  State<PantallaFixture> createState() => _PantallaFixtureState();
}

class _PantallaFixtureState extends State<PantallaFixture> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _fases = [],
      _grupos = [],
      _asignaciones = [],
      _equipos = [],
      _inscritos = [],
      _partidos = [];
  Set<String> _confirmados = {};
  String? _faseId, _grupoId, _fallo;
  bool _cargando = true, _ocupado = false, _cerrado = false;
  int _lectura = 0;
  Map<String, dynamic>? get _fase =>
      _fases.where((f) => f['id'] == _faseId).firstOrNull;
  List<Map<String, dynamic>> get _gruposFase =>
      _grupos.where((g) => g['fase_id'] == _faseId).toList();
  List<Map<String, dynamic>> get _activos => _equipos
      .where(
        (e) => _inscritos.any(
          (i) => i['equipo_id'] == e['id'] && i['estado'] == 'inscrito',
        ),
      )
      .toList();
  List<Map<String, dynamic>> get _equiposSeleccionados => _activos
      .where(
        (e) =>
            _fase?['tipo'] != 'grupos' ||
            _asignaciones.any(
              (a) => a['grupo_id'] == _grupoId && a['equipo_id'] == e['id'],
            ),
      )
      .toList();
  List<Map<String, dynamic>> get _visibles => _partidos
      .where(
        (p) =>
            p['fase_id'] == _faseId &&
            (_fase?['tipo'] != 'grupos' || p['grupo_id'] == _grupoId),
      )
      .toList();
  String _equipo(dynamic id) =>
      _equipos.where((e) => e['id'] == id).firstOrNull?['nombre']?.toString() ??
      'Equipo $id';
  bool get _editable =>
      !_ocupado &&
      !_cerrado &&
      _fase != null &&
      _fase!['estado'] != 'finalizada';
  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<List<Map<String, dynamic>>> _leerPartidos(dynamic id) async {
    final todos = <Map<String, dynamic>>[];
    for (var inicio = 0; ; inicio += 500) {
      final pagina = _filas(
        await _db
            .from('campeonato_partidos')
            .select()
            .eq('campeonato_id', id)
            .order('jornada')
            .order('numero_partido')
            .order('id')
            .range(inicio, inicio + 499),
      );
      todos.addAll(pagina);
      if (pagina.length < 500) return todos;
    }
  }

  Future<void> _leer() async {
    final lectura = ++_lectura;
    setState(() {
      _cargando = true;
      _fallo = null;
    });
    try {
      final id = widget.campeonato['id'];
      final c = await _db
          .from('campeonatos')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (c == null) throw StateError('No tienes acceso a este campeonato.');
      final datos = await Future.wait([
        _db
            .from('campeonato_fases')
            .select()
            .eq('campeonato_id', id)
            .order('orden'),
        _db.from('campeonato_equipos').select().eq('campeonato_id', id),
        _db
            .from('equipos')
            .select('id,nombre')
            .eq('liga_id', c['liga_id'].toString())
            .order('nombre'),
        _db.from('campeonato_grupo_equipos').select().eq('campeonato_id', id),
        _leerPartidos(id),
      ]);
      final fases = _filas(datos[0]), partidos = _filas(datos[4]);
      final grupos = fases.isEmpty
          ? <Map<String, dynamic>>[]
          : _filas(
              await _db
                  .from('campeonato_grupos')
                  .select()
                  .inFilter('fase_id', fases.map((f) => f['id']).toList())
                  .order('orden'),
            );
      final confirmados = <Map<String, dynamic>>[];
      for (var inicio = 0; inicio < partidos.length; inicio += 100) {
        confirmados.addAll(
          _filas(
            await _db
                .from('campeonato_resultados')
                .select('partido_id')
                .inFilter(
                  'partido_id',
                  partidos.skip(inicio).take(100).map((p) => p['id']).toList(),
                )
                .eq('estado', 'confirmado'),
          ),
        );
      }
      if (!mounted || lectura != _lectura) return;
      setState(() {
        _fases = fases;
        _inscritos = _filas(datos[1]);
        _equipos = _filas(datos[2]);
        _asignaciones = _filas(datos[3]);
        _partidos = partidos;
        _grupos = grupos;
        _confirmados = confirmados
            .map((r) => r['partido_id'].toString())
            .toSet();
        _cerrado = ['finalizado', 'archivado'].contains(c['estado']);
        if (!_fases.any((f) => f['id'] == _faseId))
          _faseId = _fases.firstOrNull?['id']?.toString();
        if (!_gruposFase.any((g) => g['id'] == _grupoId))
          _grupoId = _gruposFase.firstOrNull?['id']?.toString();
      });
    } catch (e) {
      if (mounted && lectura == _lectura) setState(() => _fallo = _error(e));
    } finally {
      if (mounted && lectura == _lectura) setState(() => _cargando = false);
    }
  }

  Future<void> _dialogo(Widget dialogo) async {
    final cambio = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialogo,
    );
    if (cambio == true && mounted) await _leer();
  }

  void _grupo({bool editar = false}) {
    final actual = editar
        ? _gruposFase.where((g) => g['id'] == _grupoId).firstOrNull
        : null;
    _dialogo(
      _GrupoDialog(
        fase: _fase!,
        grupo: actual,
        equipos: _activos,
        asignaciones: _asignaciones,
      ),
    );
  }

  Future<void> _generar() async {
    bool vuelta = false;
    final cantidad = _equiposSeleccionados.length;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, cambiar) => AlertDialog(
          title: const Text('Generar fixture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$cantidad equipos · ${cantidad * (cantidad - 1) ~/ (vuelta ? 1 : 2)} partidos.',
              ),
              SwitchListTile(
                title: const Text('Ida y vuelta'),
                subtitle: Text(
                  vuelta ? 'Cada pareja juega dos veces.' : 'Una sola vuelta.',
                ),
                value: vuelta,
                onChanged: (v) => cambiar(() => vuelta = v),
              ),
              const Text(
                'Los encuentros se crearán por jornadas. Después podrás asignar fecha, hora y cancha. Si hay un número impar de equipos, uno descansa en cada jornada.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
    if (aceptar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final total = await _db.rpc(
        'lm_fixture_generar',
        params: {
          'p_fase': _faseId,
          'p_grupo': _fase!['tipo'] == 'grupos' ? _grupoId : null,
          'p_ida_vuelta': vuelta,
        },
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se generaron $total partidos.')),
        );
      if (mounted) await _leer();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F2F5),
    appBar: AppBar(
      title: Text(
        'FIXTURE: ${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
      ),
      actions: [
        IconButton(
          onPressed: _ocupado ? null : _leer,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _fallo != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fallo!),
                  TextButton(onPressed: _leer, child: const Text('Reintentar')),
                ],
              ),
            ),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FB),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sports_soccer, color: _azul),
                            SizedBox(width: 12),
                            Text(
                              'LigaMaster SaaS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _azul,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_cerrado)
                          const Text('Campeonato cerrado: solo consulta.'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _ocupado || _cerrado
                                  ? null
                                  : () => _dialogo(
                                      _FaseDialog(
                                        campeonato: widget.campeonato,
                                      ),
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear fase'),
                            ),
                            if (_fase?['tipo'] == 'grupos')
                              OutlinedButton.icon(
                                onPressed: _editable ? () => _grupo() : null,
                                icon: const Icon(Icons.group_add_outlined),
                                label: const Text('Crear grupo'),
                              ),
                          ],
                        ),
                        if (_fases.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Crea la primera fase para comenzar. Los equipos se seleccionan en Equipos participantes del campeonato.',
                            ),
                          ),
                        if (_fases.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('fase-$_faseId'),
                            initialValue: _faseId,
                            decoration: const InputDecoration(
                              labelText: 'Fase',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final f in _fases)
                                DropdownMenuItem(
                                  value: f['id'].toString(),
                                  child: Text('${f['orden']}. ${f['nombre']}'),
                                ),
                            ],
                            onChanged: _ocupado
                                ? null
                                : (v) => setState(() {
                                    _faseId = v;
                                    _grupoId = _gruposFase.firstOrNull?['id']
                                        ?.toString();
                                  }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_tipos[_fase?['tipo']]} · ${_etapas[_fase?['etapa']]} · ${_fase?['estado']}',
                          ),
                          if (_fase?['tipo'] == 'grupos') ...[
                            const SizedBox(height: 12),
                            if (_gruposFase.isEmpty)
                              const Text(
                                'Crea un grupo y selecciona sus equipos inscritos.',
                              )
                            else
                              DropdownButtonFormField<String>(
                                key: ValueKey('grupo-$_grupoId'),
                                initialValue: _grupoId,
                                decoration: const InputDecoration(
                                  labelText: 'Grupo',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final g in _gruposFase)
                                    DropdownMenuItem(
                                      value: g['id'].toString(),
                                      child: Text(g['nombre'].toString()),
                                    ),
                                ],
                                onChanged: _ocupado
                                    ? null
                                    : (v) => setState(() => _grupoId = v),
                              ),
                            if (_grupoId != null)
                              TextButton.icon(
                                onPressed: _editable && _visibles.isEmpty
                                    ? () => _grupo(editar: true)
                                    : null,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar grupo y equipos'),
                              ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Equipos disponibles: ${_equiposSeleccionados.length}',
                          ),
                          if (_equiposSeleccionados.length < 2)
                            const Text(
                              'Necesitas al menos dos equipos inscritos en esta categoría y, si corresponde, en el grupo seleccionado.',
                            ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (_fase?['tipo'] != 'eliminatoria')
                                ElevatedButton.icon(
                                  onPressed:
                                      _editable &&
                                          _fase?['estado'] == 'pendiente' &&
                                          _visibles.isEmpty &&
                                          _equiposSeleccionados.length >= 2
                                      ? _generar
                                      : null,
                                  icon: const Icon(
                                    Icons.auto_fix_high_outlined,
                                  ),
                                  label: const Text('Generar fixture'),
                                ),
                              OutlinedButton.icon(
                                onPressed:
                                    _editable &&
                                        _equiposSeleccionados.length >= 2
                                    ? () => _dialogo(
                                        _PartidoDialog(
                                          fase: _fase!,
                                          grupoId: _fase!['tipo'] == 'grupos'
                                              ? _grupoId
                                              : null,
                                          equipos: _equiposSeleccionados,
                                        ),
                                      )
                                    : null,
                                icon: const Icon(Icons.add),
                                label: const Text('Programar partido'),
                              ),
                            ],
                          ),
                          if (_fase?['tipo'] == 'eliminatoria')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Programa los cruces de esta etapa con los equipos clasificados. No se adelantan ganadores automáticamente.',
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (_visibles.isEmpty)
                            const Text(
                              'Todavía no hay partidos en esta fase o grupo.',
                            ),
                          for (final p in _visibles)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jornada ${p['jornada']} · Partido ${p['numero_partido']}',
                                      style: const TextStyle(
                                        color: _azul,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_equipo(p['equipo_local_id'])}  vs  ${_equipo(p['equipo_visitante_id'])}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(_fecha(p['fecha_hora'])),
                                    Text(
                                      'Cancha: ${p['cancha'] ?? 'Por definir'}',
                                    ),
                                    Text(
                                      _confirmados.contains(p['id'])
                                          ? 'Resultado confirmado'
                                          : p['estado'].toString(),
                                    ),
                                    TextButton.icon(
                                      onPressed:
                                          _editable &&
                                              !_confirmados.contains(p['id'])
                                          ? () => _dialogo(
                                              _PartidoDialog(
                                                fase: _fase!,
                                                grupoId: p['grupo_id']
                                                    ?.toString(),
                                                equipos: _equipos,
                                                partido: p,
                                              ),
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.orange,
                                      ),
                                      label: const Text('Editar programación'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _ocupado
                                          ? null
                                          : () async {
                                              final tema = Theme.of(context);
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => Theme(
                                                    data: tema,
                                                    child:
                                                        PantallaPlanillaResultado(
                                                          partidoId: p['id']
                                                              .toString(),
                                                        ),
                                                  ),
                                                ),
                                              );
                                              if (mounted) await _leer();
                                            },
                                      icon: const Icon(
                                        Icons.assignment_outlined,
                                      ),
                                      label: const Text('Planilla y resultado'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}

class _FaseDialog extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  const _FaseDialog({required this.campeonato});
  @override
  State<_FaseDialog> createState() => _FaseDialogState();
}

class _FaseDialogState extends State<_FaseDialog> {
  final _nombre = TextEditingController();
  String _tipo = 'todos_contra_todos', _etapa = 'regular';
  bool _guardando = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    final f = widget.campeonato['formato'];
    _tipo = f == 'eliminatorias'
        ? 'eliminatoria'
        : f == 'grupos' || f == 'grupos_y_eliminatorias'
        ? 'grupos'
        : 'todos_contra_todos';
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _fallo = 'Escribe el nombre de la fase.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await Supabase.instance.client.rpc(
        'lm_fixture_crear_fase',
        params: {
          'p_campeonato': widget.campeonato['id'],
          'p_nombre': _nombre.text.trim(),
          'p_tipo': _tipo,
          'p_etapa': _etapa,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Dialogo(
    titulo: 'Crear fase',
    ocupado: _guardando,
    error: _fallo,
    guardar: _guardar,
    children: [
      TextField(
        controller: _nombre,
        enabled: !_guardando,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Nombre de la fase'),
      ),
      DropdownButtonFormField<String>(
        initialValue: _tipo,
        decoration: const InputDecoration(labelText: 'Tipo'),
        items: [
          for (final t in _tipos.entries)
            DropdownMenuItem(value: t.key, child: Text(t.value)),
        ],
        onChanged: _guardando
            ? null
            : (v) => setState(() {
                _tipo = v!;
                if (_tipo != 'eliminatoria') _etapa = 'regular';
              }),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('$_tipo-$_etapa'),
        initialValue: _etapa,
        decoration: const InputDecoration(labelText: 'Etapa'),
        items: [
          for (final e in _etapas.entries)
            if (_tipo == 'eliminatoria' || e.key == 'regular')
              DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: _guardando ? null : (v) => setState(() => _etapa = v!),
      ),
      const Text(
        'Crea las fases en orden. La semifinal activa la comprobación de cuatro participaciones al registrar las planillas.',
      ),
    ],
  );
}

class _GrupoDialog extends StatefulWidget {
  final Map<String, dynamic> fase;
  final Map<String, dynamic>? grupo;
  final List<Map<String, dynamic>> equipos, asignaciones;
  const _GrupoDialog({
    required this.fase,
    this.grupo,
    required this.equipos,
    required this.asignaciones,
  });
  @override
  State<_GrupoDialog> createState() => _GrupoDialogState();
}

class _GrupoDialogState extends State<_GrupoDialog> {
  final _nombre = TextEditingController();
  final Set<int> _ids = {};
  bool _guardando = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    _nombre.text = widget.grupo?['nombre']?.toString() ?? '';
    for (final a in widget.asignaciones) {
      if (widget.grupo != null &&
          a['grupo_id'] == widget.grupo!['id'] &&
          widget.equipos.any((e) => e['id'] == a['equipo_id']))
        _ids.add((a['equipo_id'] as num).toInt());
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty || _ids.length < 2) {
      setState(
        () => _fallo = 'Escribe un nombre y selecciona al menos dos equipos.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await Supabase.instance.client.rpc(
        'lm_fixture_guardar_grupo',
        params: {
          'p_fase': widget.fase['id'],
          'p_nombre': _nombre.text.trim(),
          'p_equipos': _ids.toList(),
          'p_grupo': widget.grupo?['id'],
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Dialogo(
    titulo: widget.grupo == null ? 'Crear grupo' : 'Editar grupo',
    ocupado: _guardando,
    error: _fallo,
    guardar: _guardar,
    children: [
      TextField(
        controller: _nombre,
        enabled: !_guardando,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nombre del grupo'),
      ),
      const Text('Cada equipo puede pertenecer a un solo grupo de esta fase.'),
      for (final e in widget.equipos)
        if (!widget.asignaciones.any(
          (a) =>
              a['fase_id'] == widget.fase['id'] &&
              a['equipo_id'] == e['id'] &&
              a['grupo_id'] != widget.grupo?['id'],
        ))
          CheckboxListTile(
            title: Text(e['nombre'].toString()),
            value: _ids.contains(e['id']),
            onChanged: _guardando
                ? null
                : (v) => setState(() {
                    final id = (e['id'] as num).toInt();
                    if (v == true) {
                      _ids.add(id);
                    } else {
                      _ids.remove(id);
                    }
                  }),
          ),
    ],
  );
}

class _PartidoDialog extends StatefulWidget {
  final Map<String, dynamic> fase;
  final String? grupoId;
  final List<Map<String, dynamic>> equipos;
  final Map<String, dynamic>? partido;
  const _PartidoDialog({
    required this.fase,
    this.grupoId,
    required this.equipos,
    this.partido,
  });
  @override
  State<_PartidoDialog> createState() => _PartidoDialogState();
}

class _PartidoDialogState extends State<_PartidoDialog> {
  final _jornada = TextEditingController(text: '1'),
      _cancha = TextEditingController();
  int? _local, _visitante;
  DateTime? _fechaHora;
  String _estado = 'programado';
  bool _guardando = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    final p = widget.partido;
    if (p != null) {
      _local = (p['equipo_local_id'] as num).toInt();
      _visitante = (p['equipo_visitante_id'] as num).toInt();
      _jornada.text = p['jornada'].toString();
      _cancha.text = p['cancha']?.toString() ?? '';
      _fechaHora = DateTime.tryParse(
        p['fecha_hora']?.toString() ?? '',
      )?.toLocal();
      _estado = p['estado'].toString();
    }
  }

  @override
  void dispose() {
    _jornada.dispose();
    _cancha.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final actual = _fechaHora ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (h != null && mounted)
      setState(
        () => _fechaHora = DateTime(d.year, d.month, d.day, h.hour, h.minute),
      );
  }

  Future<void> _guardar() async {
    final jornada = int.tryParse(_jornada.text.trim());
    if (_local == null ||
        _visitante == null ||
        _local == _visitante ||
        jornada == null ||
        jornada < 1) {
      setState(
        () => _fallo =
            'Selecciona equipos diferentes y una jornada mayor que cero.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await Supabase.instance.client.rpc(
        'lm_fixture_guardar_partido',
        params: {
          'p_fase': widget.fase['id'],
          'p_grupo': widget.grupoId,
          'p_local': _local,
          'p_visitante': _visitante,
          'p_jornada': jornada,
          'p_fecha': _fechaHora?.toUtc().toIso8601String(),
          'p_cancha': _cancha.text.trim(),
          'p_estado': _estado,
          'p_partido': widget.partido?['id'],
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _fallo = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _equipo(bool local) => DropdownButtonFormField<int>(
    initialValue: local ? _local : _visitante,
    decoration: InputDecoration(labelText: local ? 'Local' : 'Visitante'),
    items: [
      for (final e in widget.equipos)
        DropdownMenuItem(
          value: (e['id'] as num).toInt(),
          child: Text(e['nombre'].toString()),
        ),
    ],
    onChanged: _guardando || widget.partido != null
        ? null
        : (v) => setState(() {
            if (local) {
              _local = v;
            } else {
              _visitante = v;
            }
          }),
  );
  @override
  Widget build(BuildContext context) => _Dialogo(
    titulo: widget.partido == null
        ? 'Programar partido'
        : 'Editar programación',
    ocupado: _guardando,
    error: _fallo,
    guardar: _guardar,
    children: [
      _equipo(true),
      _equipo(false),
      TextField(
        controller: _jornada,
        enabled: !_guardando,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Jornada'),
      ),
      TextButton.icon(
        onPressed: _guardando ? null : _elegirFecha,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          _fechaHora == null
              ? 'Seleccionar fecha y hora'
              : _fecha(_fechaHora?.toIso8601String()),
        ),
      ),
      if (_fechaHora != null)
        TextButton(
          onPressed: _guardando
              ? null
              : () => setState(() => _fechaHora = null),
          child: const Text('Dejar fecha por definir'),
        ),
      const Text(
        'La hora se muestra según la zona horaria de este dispositivo.',
      ),
      TextField(
        controller: _cancha,
        enabled: !_guardando,
        maxLength: 150,
        decoration: const InputDecoration(labelText: 'Cancha (opcional)'),
      ),
      DropdownButtonFormField<String>(
        initialValue: _estado,
        decoration: const InputDecoration(labelText: 'Estado'),
        items: [
          for (final e in ['programado', 'aplazado', 'cancelado'])
            DropdownMenuItem(value: e, child: Text(e)),
        ],
        onChanged: _guardando ? null : (v) => setState(() => _estado = v!),
      ),
    ],
  );
}

class _Dialogo extends StatelessWidget {
  final String titulo;
  final bool ocupado;
  final String? error;
  final VoidCallback guardar;
  final List<Widget> children;
  const _Dialogo({
    required this.titulo,
    required this.ocupado,
    this.error,
    required this.guardar,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: AlertDialog(
      backgroundColor: const Color(0xFFF8F6FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(titulo),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in children)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: ocupado ? null : guardar,
          child: Text(ocupado ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
