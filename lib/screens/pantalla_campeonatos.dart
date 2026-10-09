import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_fixture.dart';
import 'pantalla_posiciones.dart';

const _categorias = ['Fútbol Senior', 'Femenino', 'Sub 40', 'Sub 12'];
const _formatos = {
  'todos_contra_todos': 'Todos contra todos',
  'grupos': 'Grupos',
  'eliminatorias': 'Eliminatorias',
  'grupos_y_eliminatorias': 'Grupos y eliminatorias',
};
String _error(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23505')
      return 'Este registro ya existe. Actualiza la lista antes de intentarlo de nuevo.';
    if (e.code == '42501')
      return 'Tu cuenta no tiene permiso para realizar esta operación.';
    return e.message;
  }
  if (e is StateError) return e.message.toString();
  return 'No se pudo completar la operación. Comprueba tu conexión.';
}

class PantallaCampeonatos extends StatefulWidget {
  final String ligaId;
  final String nombreLiga;
  const PantallaCampeonatos({
    super.key,
    required this.ligaId,
    required this.nombreLiga,
  });
  @override
  State<PantallaCampeonatos> createState() => _PantallaCampeonatosState();
}

class _PantallaCampeonatosState extends State<PantallaCampeonatos> {
  late Future<List<Map<String, dynamic>>> _datos;
  final Map<String, String> _seleccion = {};
  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null)
      throw StateError('Inicia sesión para consultar campeonatos.');
    final perfil = await db
        .from('perfiles')
        .select('rol')
        .eq('id', uid)
        .maybeSingle();
    final liga = await db
        .from('ligas')
        .select('admin_id')
        .eq('id', widget.ligaId)
        .maybeSingle();
    if (liga == null ||
        !(perfil?['rol'] == 'superadmin' ||
            (perfil?['rol'] == 'admin' && liga['admin_id'] == uid))) {
      throw StateError('Esta cuenta no administra la liga seleccionada.');
    }
    final rows = await db
        .from('campeonatos')
        .select()
        .eq('liga_id', widget.ligaId)
        .order('creado_en', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _actualizar() {
    final carga = _leer();
    setState(() {
      _datos = carga;
    });
  }

  Future<void> _crear() async {
    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NuevoCampeonato(ligaId: widget.ligaId),
    );
    if (creado == true && mounted) _actualizar();
  }

  Future<void> _equipos(Map<String, dynamic> campeonato) async {
    final tema = Theme.of(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: tema,
          child: _Participantes(campeonato: campeonato, ligaId: widget.ligaId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F2F5),
    appBar: AppBar(
      title: Text(
        'CAMPEONATOS: ${widget.nombreLiga.toUpperCase().startsWith('LIGA ') ? widget.nombreLiga.toUpperCase() : 'LIGA ${widget.nombreLiga.toUpperCase()}'}',
      ),
      actions: [
        IconButton(
          onPressed: _actualizar,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error(snapshot.error!), textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _actualizar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            final filas = snapshot.data ?? [];
            final grupos = <String, List<Map<String, dynamic>>>{};
            for (final fila in filas) {
              final clave = (fila['grupo_campeonato_id'] ?? fila['id'])
                  .toString();
              grupos.putIfAbsent(clave, () => []).add(fila);
            }
            final campeonatos = <Map<String, dynamic>>[];
            for (final entrada in grupos.entries) {
              entrada.value.sort(
                (a, b) => _categorias
                    .indexOf(a['categoria'])
                    .compareTo(_categorias.indexOf(b['categoria'])),
              );
              campeonatos.add(
                entrada.value.firstWhere(
                  (c) => c['categoria'] == _seleccion[entrada.key],
                  orElse: () => entrada.value.first,
                ),
              );
            }
            return ListView(
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
                          Icon(Icons.sports_soccer, color: Color(0xFF4351BF)),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'LigaMaster SaaS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4351BF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Campeonatos de la liga',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _crear,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuevo campeonato'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (campeonatos.isEmpty)
                        const Text(
                          'Todavía no hay campeonatos. Crea uno y selecciona los equipos que participarán en su categoría.',
                        ),
                      for (final c in campeonatos)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['nombre'].toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4351BF),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('${c['id']}'),
                                  initialValue: c['categoria'],
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                  ),
                                  items: [
                                    for (final fila
                                        in grupos[(c['grupo_campeonato_id'] ??
                                                c['id'])
                                            .toString()]!)
                                      DropdownMenuItem(
                                        value: fila['categoria'].toString(),
                                        child: Text(
                                          fila['categoria'].toString(),
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setState(
                                    () =>
                                        _seleccion[(c['grupo_campeonato_id'] ??
                                                    c['id'])
                                                .toString()] =
                                            v!,
                                  ),
                                ),
                                Text(
                                  '${_formatos[c['formato']] ?? c['formato']}',
                                ),
                                Text('Estado: ${c['estado']}'),
                                _PeriodoInscripcion(
                                  campeonato: c,
                                  alGuardar: _actualizar,
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _equipos(c),
                                  icon: const Icon(Icons.groups_outlined),
                                  label: const Text('Equipos participantes'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final tema = Theme.of(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Theme(
                                          data: tema,
                                          child: PantallaFixture(campeonato: c),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  label: const Text('Fixture'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final tema = Theme.of(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Theme(
                                          data: tema,
                                          child: PantallaPosiciones(campeonato: c),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.leaderboard_outlined),
                                  label: const Text('Posiciones'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _NuevoCampeonato extends StatefulWidget {
  final String ligaId;
  const _NuevoCampeonato({required this.ligaId});
  @override
  State<_NuevoCampeonato> createState() => _NuevoCampeonatoState();
}

class _NuevoCampeonatoState extends State<_NuevoCampeonato> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  String _formato = _formatos.keys.first;
  bool _guardando = false;
  String? _mensaje;
  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_crear_campeonato_completo',
        params: {
          'p_liga_id': widget.ligaId,
          'p_nombre': _nombre.text.trim(),
          'p_formato': _formato,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _mensaje = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      backgroundColor: const Color(0xFFF8F6FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Nuevo campeonato'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  enabled: !_guardando,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del campeonato',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Escribe el nombre del campeonato.'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Incluye Fútbol Senior, Femenino, Sub 40 y Sub 12. Cada categoría tiene sus propios equipos y fechas.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _formato,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Formato',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in _formatos.entries)
                      DropdownMenuItem(value: f.key, child: Text(f.value)),
                  ],
                  onChanged: _guardando
                      ? null
                      : (v) => setState(() => _formato = v!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Se creará en borrador. Después podrás seleccionar los equipos participantes.',
                ),
                if (_mensaje != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _mensaje!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Crear campeonato'),
        ),
      ],
    ),
  );
}

class _EquiposCampeonato extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  final String ligaId;
  final List<Map<String, dynamic>> equipos;
  const _EquiposCampeonato({
    required this.campeonato,
    required this.ligaId,
    required this.equipos,
  });
  @override
  State<_EquiposCampeonato> createState() => _EquiposCampeonatoState();
}

class _EquiposCampeonatoState extends State<_EquiposCampeonato> {
  bool _cargando = true;
  bool _guardando = false;
  String? _mensaje;
  List<Map<String, dynamic>> _equipos = [];
  final Map<int, String> _inscritos = {};
  final Set<int> _seleccionados = {};
  @override
  void initState() {
    super.initState();
    _leer();
  }

  void _leer() {
    _equipos = widget.equipos.map((e) => Map<String, dynamic>.from(e)).toList();
    _inscritos.clear();
    _seleccionados.clear();
    for (final e in _equipos) {
      final estado = e['_estado']?.toString().trim();
      if (estado != null) _inscritos[int.parse(e['id'].toString())] = estado;
    }
    _cargando = false;
  }

  Future<void> _guardar() async {
    if (_guardando || _seleccionados.isEmpty) return;
    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      await Supabase.instance.client.from('campeonato_equipos').upsert([
        for (final id in _seleccionados)
          {
            'campeonato_id': widget.campeonato['id'],
            'equipo_id': id,
            'estado': 'inscrito',
          },
      ], onConflict: 'campeonato_id,equipo_id');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _mensaje = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      backgroundColor: const Color(0xFFF8F6FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Equipos · ${widget.campeonato['categoria']}'),
      content: SizedBox(
        width: 500,
        height: 360,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.campeonato['nombre'].toString()),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona los equipos que participarán en esta categoría.',
                  ),
                  if (_mensaje != null)
                    Text(_mensaje!, style: const TextStyle(color: Colors.red)),
                  Expanded(
                    child: _equipos.isEmpty
                        ? const Center(
                            child: Text('No hay equipos disponibles.'),
                          )
                        : ListView(
                            children: [
                              for (final e in _equipos)
                                Builder(
                                  builder: (_) {
                                    final id = int.parse(e['id'].toString());
                                    final estado = _inscritos[id];
                                    return CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(e['nombre'].toString()),
                                      subtitle: Text(
                                        '${e['liga'] ?? ''}'
                                        '${estado == null
                                            ? ''
                                            : estado == 'inscrito'
                                            ? ' · Ya inscrito'
                                            : ' · Inscripción retirada'}',
                                      ),
                                      value:
                                          estado == 'inscrito' ||
                                          _seleccionados.contains(id),
                                      onChanged:
                                          _guardando || estado == 'inscrito'
                                          ? null
                                          : (v) => setState(() {
                                              if (v == true) {
                                                _seleccionados.add(id);
                                              } else {
                                                _seleccionados.remove(id);
                                              }
                                            }),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: _guardando || _cargando || _seleccionados.isEmpty
              ? null
              : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Inscribir seleccionados'),
        ),
      ],
    ),
  );
}

class AccesoRapidoCampeonatos extends StatefulWidget {
  final String ligaId;
  const AccesoRapidoCampeonatos({super.key, required this.ligaId});
  @override
  State<AccesoRapidoCampeonatos> createState() =>
      _AccesoRapidoCampeonatosState();
}

class _AccesoRapidoCampeonatosState extends State<AccesoRapidoCampeonatos> {
  bool _cargando = false;
  Future<void> _abrir() async {
    final caja = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final posicion = RelativeRect.fromRect(
      caja.localToGlobal(Offset.zero, ancestor: overlay) & caja.size,
      Offset.zero & overlay.size,
    );
    setState(() => _cargando = true);
    try {
      final filas = await Supabase.instance.client
          .from('campeonatos')
          .select()
          .eq('liga_id', widget.ligaId)
          .order('nombre');
      if (!mounted) return;
      if (filas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todavía no hay campeonatos. Pulsa Campeonatos para crear uno.',
            ),
          ),
        );
        return;
      }
      final elegido = await showMenu<String>(
        context: context,
        position: posicion,
        items: [
          for (final c in filas)
            PopupMenuItem(
              value: c['id'].toString(),
              child: Text('${c['nombre']} · ${c['categoria']}'),
            ),
        ],
      );
      if (elegido == null || !mounted) return;
      final campeonato = Map<String, dynamic>.from(
        filas.firstWhere((c) => c['id'].toString() == elegido),
      );
      final tema = Theme.of(context);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Theme(
            data: tema,
            child: _Participantes(
              campeonato: campeonato,
              ligaId: widget.ligaId,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: _cargando ? null : _abrir,
    tooltip: 'Abrir un campeonato',
    icon: Icon(_cargando ? Icons.hourglass_empty : Icons.arrow_drop_down),
  );
}

class _Participantes extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  final String ligaId;
  final Map<String, dynamic>? equipo;
  const _Participantes({
    required this.campeonato,
    required this.ligaId,
    this.equipo,
  });
  @override
  State<_Participantes> createState() => _ParticipantesState();
}

class _ParticipantesState extends State<_Participantes> {
  late Future<List<Map<String, dynamic>>> _datos;
  bool _ocupado = false;
  List<Map<String, dynamic>> _catalogoEquipos = [];
  bool get _jugadores => widget.equipo != null;
  final _db = Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    _datos = _leer();
  }

  void _recargar() {
    final carga = _leer();
    setState(() {
      _datos = carga;
    });
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    if (!_jugadores) {
      final respuesta = await _db.rpc(
        'lm_lista_equipos_campeonato',
        params: {'p_campeonato_id': widget.campeonato['id']},
      );
      _catalogoEquipos = List<Map<String, dynamic>>.from(respuesta);
      return _catalogoEquipos
          .where((e) => e['_estado']?.toString().trim() == 'inscrito')
          .toList();
    }
    final ins = await _db
        .from('campeonato_jugadores')
        .select()
        .eq('campeonato_id', widget.campeonato['id'])
        .eq('equipo_id', widget.equipo!['id'])
        .eq('estado', 'inscrito');
    final jugadores = await _db
        .from('jugadores')
        .select()
        .eq('equipo_id', widget.equipo!['id'])
        .eq('categoria', widget.campeonato['categoria'])
        .order('apellidos');
    return [
      for (final j in jugadores)
        if (ins.any((i) => i['jugador_id'] == j['id']))
          {
            ...j,
            '_inscripcion': ins.firstWhere(
              (i) => i['jugador_id'] == j['id'],
            )['id'],
          },
    ];
  }

  Future<void> _agregar() async {
    if (!_jugadores) {
      if (_ocupado) return;
      setState(() => _ocupado = true);
      try {
        final carga = _leer();
        setState(() {
          _datos = carga;
        });
        await carga;
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => _EquiposCampeonato(
            campeonato: widget.campeonato,
            ligaId: widget.ligaId,
            equipos: _catalogoEquipos,
          ),
        );
        if (mounted) _recargar();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_error(e))));
      } finally {
        if (mounted) setState(() => _ocupado = false);
      }
      return;
    }
    setState(() => _ocupado = true);
    try {
      final todos = await _db
          .from('jugadores')
          .select()
          .eq('equipo_id', widget.equipo!['id'])
          .eq('categoria', widget.campeonato['categoria'])
          .order('apellidos');
      final inscritos = await _db
          .from('campeonato_jugadores')
          .select('jugador_id,estado')
          .eq('campeonato_id', widget.campeonato['id']);
      final disponibles = todos
          .where(
            (j) => !inscritos.any(
              (i) => i['jugador_id'] == j['id'] && i['estado'] == 'inscrito',
            ),
          )
          .toList();
      if (!mounted) return;
      final elegido = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Inscribir jugador'),
          content: SizedBox(
            width: 460,
            height: 320,
            child: disponibles.isEmpty
                ? const Text(
                    'No hay jugadores pendientes de inscripción en esta categoría.',
                  )
                : ListView(
                    children: [
                      for (final j in disponibles)
                        ListTile(
                          title: Text(
                            '${j['nombres']} ${j['apellidos'] ?? ''}',
                          ),
                          subtitle: Text('Cédula: ${j['cedula']}'),
                          onTap: () =>
                              Navigator.pop(ctx, Map<String, dynamic>.from(j)),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (elegido == null) return;
      await _db.from('campeonato_jugadores').upsert({
        'campeonato_id': widget.campeonato['id'],
        'equipo_id': widget.equipo!['id'],
        'jugador_id': elegido['id'],
        'categoria': widget.campeonato['categoria'],
        'estado': 'inscrito',
      }, onConflict: 'campeonato_id,jugador_id');
      if (mounted) _recargar();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _retirar(Map<String, dynamic> fila) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_jugadores ? 'Retirar jugador' : 'Retirar equipo'),
        content: Text(
          _jugadores
              ? 'Se retirará únicamente de este campeonato. Su ficha e historial se conservarán.'
              : 'Se retirará el equipo y sus inscripciones de jugadores de este campeonato. Las fichas e historiales se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _db.rpc(
        'lm_retirar_inscripcion_campeonato',
        params: {
          'p_campeonato_id': widget.campeonato['id'],
          'p_equipo_id': _jugadores ? widget.equipo!['id'] : fila['id'],
          'p_jugador_id': _jugadores ? fila['id'] : null,
        },
      );
      if (mounted) _recargar();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> fila) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarFichaCampeonato(fila: fila, jugador: _jugadores),
    );
    if (guardado == true && mounted) _recargar();
  }

  void _ver(Map<String, dynamic> fila) {
    if (!_jugadores) {
      final tema = Theme.of(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Theme(
            data: tema,
            child: _Participantes(
              campeonato: widget.campeonato,
              ligaId: widget.ligaId,
              equipo: fila,
            ),
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${fila['nombres']} ${fila['apellidos'] ?? ''}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final campo in ['foto_url', 'foto_cedula_url'])
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              campo == 'foto_url'
                                  ? 'Foto del jugador'
                                  : 'Frente de la cédula',
                            ),
                            SizedBox(
                              height: 150,
                              child:
                                  (fila[campo]?.toString().isNotEmpty ?? false)
                                  ? Image.network(
                                      fila[campo].toString(),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Text('Imagen no disponible'),
                                    )
                                  : const Center(child: Text('Sin imagen')),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                for (final campo in {
                  'cedula': 'Cédula',
                  'categoria': 'Categoría',
                  'fecha_nacimiento': 'Nacimiento',
                  'posicion': 'Posición',
                  'num_camiseta': 'Camiseta',
                  'telefono': 'Teléfono',
                  'email': 'Correo',
                  'direccion': 'Dirección',
                  'estado': 'Estado',
                  'observaciones': 'Observaciones',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      '${campo.value}: ${fila[campo.key] ?? 'Sin registrar'}',
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F2F5),
    appBar: AppBar(
      title: Text(
        _jugadores
            ? 'JUGADORES: ${widget.equipo!['nombre']}'
            : 'EQUIPOS: ${widget.campeonato['nombre']}',
      ),
      actions: [
        IconButton(
          onPressed: _ocupado ? null : _recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(child: Text(_error(snapshot.error!)));
            final filas = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF4351BF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _ocupado ? null : _agregar,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _jugadores ? 'Inscribir jugador' : 'Añadir equipos',
                          ),
                        ),
                      ),
                      if (filas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Todavía no hay participantes inscritos.',
                          ),
                        ),
                      for (final f in filas)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _jugadores
                                      ? '${f['nombres']} ${f['apellidos'] ?? ''}'
                                      : f['nombre'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_jugadores)
                                  Text(
                                    'Cédula: ${f['cedula']} · ${f['posicion'] ?? ''}',
                                  ),
                                Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: _jugadores
                                          ? 'Ver datos'
                                          : 'Ver jugadores',
                                      onPressed: _ocupado
                                          ? null
                                          : () => _ver(f),
                                      icon: Icon(
                                        _jugadores
                                            ? Icons.visibility_outlined
                                            : Icons.groups_outlined,
                                        color: const Color(0xFF4351BF),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar datos generales',
                                      onPressed: _ocupado
                                          ? null
                                          : () => _editar(f),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Retirar del campeonato',
                                      onPressed: _ocupado
                                          ? null
                                          : () => _retirar(f),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _EditarFichaCampeonato extends StatefulWidget {
  final Map<String, dynamic> fila;
  final bool jugador;
  const _EditarFichaCampeonato({required this.fila, required this.jugador});
  @override
  State<_EditarFichaCampeonato> createState() => _EditarFichaCampeonatoState();
}

class _EditarFichaCampeonatoState extends State<_EditarFichaCampeonato> {
  final _form = GlobalKey<FormState>();
  final _ctrl = <String, TextEditingController>{};
  bool _guardando = false;
  String? _mensaje;
  Map<String, String> get campos => widget.jugador
      ? {
          'nombres': 'Nombres',
          'apellidos': 'Apellidos',
          'cedula': 'Cédula',
          'num_camiseta': 'Número de camiseta',
          'fecha_nacimiento': 'Fecha de nacimiento',
          'posicion': 'Posición',
          'telefono': 'Teléfono',
          'email': 'Correo',
          'direccion': 'Dirección',
        }
      : {
          'nombre': 'Nombre del equipo',
          'barrio': 'Barrio',
          'presidente_nombre': 'Nombre del presidente',
          'presidente_telefono': 'Teléfono del presidente',
        };
  @override
  void initState() {
    super.initState();
    for (final k in campos.keys) {
      _ctrl[k] = TextEditingController(text: widget.fila[k]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final datos = <String, dynamic>{
        for (final c in _ctrl.entries) c.key: c.value.text.trim(),
      };
      if (widget.jugador) {
        datos['num_camiseta'] = int.tryParse(
          _ctrl['num_camiseta']!.text.trim(),
        );
      }
      final row = await Supabase.instance.client
          .from(widget.jugador ? 'jugadores' : 'equipos')
          .update(datos)
          .eq('id', widget.fila['id'])
          .select('id')
          .maybeSingle();
      if (row == null)
        throw StateError('No se pudo guardar: revisa tus permisos.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _mensaje = _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: Text(widget.jugador ? 'Editar jugador' : 'Editar equipo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.jugador
                      ? 'Los cambios se aplican a la ficha de la liga. Si cambias los datos del jugador, deberá revisarse y calificarse nuevamente.'
                      : 'Los cambios se aplican al equipo también fuera de este campeonato.',
                ),
                for (final c in campos.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _ctrl[c.key],
                      enabled: !_guardando,
                      decoration: InputDecoration(
                        labelText: c.value,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (['nombre', 'nombres', 'cedula'].contains(c.key) &&
                            t.isEmpty)
                          return 'Completa este dato.';
                        if (c.key == 'cedula' &&
                            !RegExp(r'^\d{10}$').hasMatch(t))
                          return 'Escribe 10 dígitos.';
                        if (c.key == 'num_camiseta' &&
                            t.isNotEmpty &&
                            (int.tryParse(t) == null || int.parse(t) < 0))
                          return 'Escribe un número válido.';
                        return null;
                      },
                    ),
                  ),
                if (_mensaje != null)
                  Text(_mensaje!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}

class _PeriodoInscripcion extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  final VoidCallback alGuardar;
  const _PeriodoInscripcion({
    required this.campeonato,
    required this.alGuardar,
  });
  @override
  State<_PeriodoInscripcion> createState() => _PeriodoInscripcionState();
}

class _PeriodoInscripcionState extends State<_PeriodoInscripcion> {
  Future<void> _abrir() async {
    final cambio = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoPeriodo(campeonato: widget.campeonato),
    );
    if (cambio == true && mounted) widget.alGuardar();
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _abrir,
    icon: const Icon(Icons.date_range_outlined),
    label: const Text('Fechas de inscripción'),
  );
}

class _DialogoPeriodo extends StatefulWidget {
  final Map<String, dynamic> campeonato;
  const _DialogoPeriodo({required this.campeonato});
  @override
  State<_DialogoPeriodo> createState() => _DialogoPeriodoState();
}

class _DialogoPeriodoState extends State<_DialogoPeriodo> {
  DateTime? _inicio, _fin;
  bool _guardando = false;
  String? _fallo;
  @override
  void initState() {
    super.initState();
    _inicio = DateTime.tryParse(
      widget.campeonato['inscripcion_inicio']?.toString() ?? '',
    )?.toLocal();
    _fin = DateTime.tryParse(
      widget.campeonato['inscripcion_fin']?.toString() ?? '',
    )?.toLocal();
  }

  String _texto(DateTime? d) => d == null
      ? 'Seleccionar'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  Future<void> _elegir(bool inicio) async {
    final actual = (inicio ? _inicio : _fin) ?? DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null || !mounted) return;
    setState(() {
      final d = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      );
      if (inicio) {
        _inicio = d;
      } else {
        _fin = d;
      }
    });
  }

  Future<void> _guardar() async {
    if (_inicio == null || _fin == null || !_fin!.isAfter(_inicio!)) {
      setState(
        () => _fallo =
            'Selecciona inicio y cierre; el cierre debe ser posterior.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await Supabase.instance.client.rpc(
        'lm_configurar_inscripcion',
        params: {
          'p_campeonato_id': widget.campeonato['id'],
          'p_inicio': _inicio!.toUtc().toIso8601String(),
          'p_fin': _fin!.toUtc().toIso8601String(),
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: const Text('Periodo de inscripción'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.campeonato['nombre']} · ${widget.campeonato['categoria']}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Horas según la zona horaria de este dispositivo. Fuera de este periodo el delegado solo podrá consultar las fichas.',
            ),
            TextButton.icon(
              onPressed: _guardando
                  ? null
                  : () {
                      final ahora = DateTime.now();
                      setState(() {
                        _inicio = ahora.subtract(const Duration(minutes: 1));
                        _fin = ahora.add(const Duration(days: 7));
                        _fallo = null;
                      });
                    },
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Abrir 7 días para pruebas'),
            ),
            TextButton(
              onPressed: _guardando ? null : () => _elegir(true),
              child: Text('Inicio: ${_texto(_inicio)}'),
            ),
            TextButton(
              onPressed: _guardando ? null : () => _elegir(false),
              child: Text('Cierre: ${_texto(_fin)}'),
            ),
            if (_fallo != null)
              Text(_fallo!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
