import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _azul = Color(0xFF4351BF);
String _errorActa(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StateError) return e.message.toString();
  return 'No se pudo completar la operación. Comprueba tu conexión.';
}

class _FilaJugador {
  final Map<String, dynamic> datos;
  bool participo;
  final TextEditingController goles, autogoles;
  _FilaJugador(this.datos, Map<String, dynamic>? pl)
    : participo = pl?['participo'] == true,
      goles = TextEditingController(text: (pl?['goles'] ?? 0).toString()),
      autogoles = TextEditingController(
        text: (pl?['autogoles'] ?? 0).toString(),
      );
  bool get activo =>
      datos['estado_inscripcion'] == 'inscrito' &&
      datos['estado_equipo'] == 'inscrito';
  void dispose() {
    goles.dispose();
    autogoles.dispose();
  }
}

class PantallaPlanillaResultado extends StatefulWidget {
  final String partidoId;
  const PantallaPlanillaResultado({super.key, required this.partidoId});
  @override
  State<PantallaPlanillaResultado> createState() =>
      _PantallaPlanillaResultadoState();
}

class _PantallaPlanillaResultadoState extends State<PantallaPlanillaResultado> {
  final _db = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _marcador = <String, TextEditingController>{
    for (final k in [
      'goles_local',
      'goles_visitante',
      'prorroga_local',
      'prorroga_visitante',
      'penales_local',
      'penales_visitante',
    ])
      k: TextEditingController(text: '0'),
  };
  Map<String, dynamic>? _datos;
  List<_FilaJugador> _jugadores = [];
  bool _cargando = true,
      _ocupado = false,
      _sucio = false,
      _prorroga = false,
      _penales = false;
  String? _fallo;
  Map<String, dynamic> get _partido =>
      Map<String, dynamic>.from(_datos!['partido']);
  Map<String, dynamic>? get _resultado => _datos?['resultado'] == null
      ? null
      : Map<String, dynamic>.from(_datos!['resultado']);
  bool get _confirmado => _resultado?['estado'] == 'confirmado';
  bool get _cerrado =>
      ['finalizado', 'archivado'].contains(_datos?['campeonato']?['estado']) ||
      _datos?['fase']?['estado'] == 'finalizada';
  bool get _editable =>
      !_ocupado &&
      !_confirmado &&
      !_cerrado &&
      _datos != null &&
      _partido['estado'] == 'programado';
  String _nombreEquipo(dynamic id) {
    for (final e in _datos!['equipos'] as List) {
      if (e['id'] == id) return e['nombre'].toString();
    }
    return 'Equipo $id';
  }

  void _cambio() {
    setState(() => _sucio = true);
  }

  @override
  void initState() {
    super.initState();
    _leer();
  }

  @override
  void dispose() {
    for (final c in _marcador.values) {
      c.dispose();
    }
    for (final j in _jugadores) {
      j.dispose();
    }
    super.dispose();
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _fallo = null;
    });
    try {
      final datos = Map<String, dynamic>.from(
        await _db.rpc(
          'lm_leer_acta',
          params: {'p_partido_id': widget.partidoId},
        ),
      );
      if (!mounted) return;
      final planillas = {
        for (final p in datos['planillas'] as List)
          p['inscripcion_jugador_id']: Map<String, dynamic>.from(p),
      };
      for (final j in _jugadores) {
        j.dispose();
      }
      final resultado = datos['resultado'] as Map?;
      _jugadores = [
        for (final j in datos['jugadores'] as List)
          _FilaJugador(
            Map<String, dynamic>.from(j),
            planillas[j['inscripcion_id']],
          ),
      ];
      for (final k in _marcador.keys) {
        _marcador[k]!.text = (resultado?[k] ?? 0).toString();
      }
      setState(() {
        _datos = datos;
        _sucio = false;
        _prorroga = resultado?['prorroga_local'] != null;
        _penales = resultado?['penales_local'] != null;
      });
    } catch (e) {
      if (mounted) setState(() => _fallo = _errorActa(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<bool> _descartar() async {
    if (!_sucio) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              '¿Deseas descartar los cambios de esta planilla?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _actualizar() async {
    if (await _descartar() && mounted) await _leer();
  }

  int _numero(TextEditingController c) => int.tryParse(c.text) ?? 0;
  List<int> get _totales {
    var local = 0, visitante = 0;
    for (final j in _jugadores.where((j) => j.participo)) {
      if (j.datos['equipo_id'] == _partido['equipo_local_id']) {
        local += _numero(j.goles);
        visitante += _numero(j.autogoles);
      } else {
        visitante += _numero(j.goles);
        local += _numero(j.autogoles);
      }
    }
    return [local, visitante];
  }

  Future<void> _guardar(bool confirmar) async {
    if (!_editable || !_form.currentState!.validate()) return;
    if (confirmar) {
      final totales = _totales;
      if (!_jugadores.any(
            (j) =>
                j.participo &&
                j.datos['equipo_id'] == _partido['equipo_local_id'],
          ) ||
          !_jugadores.any(
            (j) =>
                j.participo &&
                j.datos['equipo_id'] == _partido['equipo_visitante_id'],
          )) {
        setState(
          () => _fallo = 'Marca al menos un participante por cada equipo.',
        );
        return;
      }
      if (totales[0] !=
              _numero(_marcador['goles_local']!) +
                  (_prorroga ? _numero(_marcador['prorroga_local']!) : 0) ||
          totales[1] !=
              _numero(_marcador['goles_visitante']!) +
                  (_prorroga ? _numero(_marcador['prorroga_visitante']!) : 0)) {
        setState(
          () => _fallo =
              'Los goles y autogoles de las planillas deben coincidir con el marcador, incluida la prórroga y sin contar la tanda de penales.',
        );
        return;
      }
      final si = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar resultado'),
          content: const Text(
            'Se guardarán la planilla y el marcador. Las participaciones y goles contarán en las estadísticas. Para corregir después deberás reabrir el resultado con un motivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (si != true || !mounted) return;
    }
    setState(() {
      _ocupado = true;
      _fallo = null;
    });
    try {
      await _db.rpc(
        'lm_guardar_acta',
        params: {
          'p_partido_id': widget.partidoId,
          'p_version': _datos!['version'],
          'p_confirmar': confirmar,
          'p_planillas': [
            for (final j in _jugadores)
              {
                'inscripcion_id': j.datos['inscripcion_id'],
                'participo': j.participo,
                'goles': j.participo ? _numero(j.goles) : 0,
                'autogoles': j.participo ? _numero(j.autogoles) : 0,
              },
          ],
          'p_resultado': {
            for (final k in _marcador.keys)
              k:
                  (k.startsWith('prorroga') && !_prorroga) ||
                      (k.startsWith('penales') && !_penales)
                  ? null
                  : _numero(_marcador[k]!),
          },
        },
      );
      if (!mounted) return;
      setState(() => _sucio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmar ? 'Resultado confirmado.' : 'Borrador guardado.',
          ),
        ),
      );
      await _leer();
    } catch (e) {
      if (mounted) setState(() => _fallo = _errorActa(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _reabrir() async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _MotivoReapertura(),
    );
    if (texto == null || !mounted) return;
    setState(() {
      _ocupado = true;
      _fallo = null;
    });
    try {
      await _db.rpc(
        'lm_reabrir_acta',
        params: {
          'p_partido_id': widget.partidoId,
          'p_version': _datos!['version'],
          'p_motivo': texto,
        },
      );
      if (mounted) await _leer();
    } catch (e) {
      if (mounted) setState(() => _fallo = _errorActa(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _entero(TextEditingController c, String label, {bool? enabled}) =>
      SizedBox(
        width: 145,
        child: TextFormField(
          controller: c,
          enabled: enabled ?? _editable,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 0 || n > 2147483647
                ? 'Ingresa un entero válido.'
                : null;
          },
          onChanged: (_) => _cambio(),
        ),
      );
  Widget _tablaEquipo(dynamic id) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nombreEquipo(id),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _azul,
            ),
          ),
          if (!_jugadores.any((j) => j.datos['equipo_id'] == id))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay jugadores inscritos en este campeonato y categoría. Agrégalos desde Equipos participantes.',
              ),
            ),
          for (final j in _jugadores.where((j) => j.datos['equipo_id'] == id))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: j.participo,
                    title: Text(
                      '${j.datos['nombres']} ${j.datos['apellidos'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Camiseta: ${j.datos['camiseta'] ?? 'Sin registrar'} · ${j.activo ? (j.datos['estado_jugador'] ?? 'Inscrito') : 'Retirado'}',
                    ),
                    onChanged: _editable && (j.activo || j.participo)
                        ? (v) => setState(() {
                            j.participo = v == true;
                            _sucio = true;
                            if (!j.participo) {
                              j.goles.text = '0';
                              j.autogoles.text = '0';
                            }
                          })
                        : null,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _entero(
                        j.goles,
                        'Goles',
                        enabled: _editable && j.participo && j.activo,
                      ),
                      _entero(
                        j.autogoles,
                        'Autogoles',
                        enabled: _editable && j.participo && j.activo,
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado && !_sucio,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && !_ocupado && await _descartar() && mounted) {
        setState(() => _sucio = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF2F2F5),
      appBar: AppBar(
        title: const Text('Planilla y resultado'),
        actions: [
          IconButton(
            onPressed: _ocupado || _cargando ? null : _actualizar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _datos == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fallo ?? 'No se pudo cargar la planilla.'),
                  TextButton(onPressed: _leer, child: const Text('Reintentar')),
                ],
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Form(
                  key: _form,
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
                            const SizedBox(height: 16),
                            Text(
                              '${_datos!['campeonato']['nombre']} · ${_datos!['campeonato']['categoria']}',
                            ),
                            Text(
                              '${_nombreEquipo(_partido['equipo_local_id'])} vs ${_nombreEquipo(_partido['equipo_visitante_id'])}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_datos!['fase']['nombre']} · Jornada ${_partido['jornada']} · Partido ${_partido['numero_partido']}',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _confirmado
                                  ? 'Resultado confirmado'
                                  : _resultado == null
                                  ? 'Sin resultado guardado'
                                  : 'Resultado en borrador',
                              style: TextStyle(
                                color: _confirmado ? Colors.green : _azul,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_cerrado)
                              const Text(
                                'Campeonato o fase cerrados: solo consulta.',
                              ),
                            if (_partido['estado'] != 'programado')
                              Text(
                                'Partido ${_partido['estado']}: la programación debe estar activa para registrar un resultado.',
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Marca únicamente a quienes jugaron. Los goles incluyen los anotados en prórroga. No incluyas los penales de la tanda en los goles del jugador.',
                            ),
                            _tablaEquipo(_partido['equipo_local_id']),
                            _tablaEquipo(_partido['equipo_visitante_id']),
                            const SizedBox(height: 16),
                            const Text(
                              'Marcador del tiempo reglamentario',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _entero(_marcador['goles_local']!, 'Local'),
                                _entero(
                                  _marcador['goles_visitante']!,
                                  'Visitante',
                                ),
                              ],
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Hubo prórroga'),
                              value: _prorroga,
                              onChanged: _editable
                                  ? (v) => setState(() {
                                      _prorroga = v;
                                      _sucio = true;
                                      if (!v) _penales = false;
                                    })
                                  : null,
                            ),
                            if (_prorroga) ...[
                              const Text(
                                'Goles adicionales durante la prórroga, no el marcador acumulado.',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _entero(
                                    _marcador['prorroga_local']!,
                                    'Prórroga local',
                                  ),
                                  _entero(
                                    _marcador['prorroga_visitante']!,
                                    'Prórroga visitante',
                                  ),
                                ],
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Hubo tanda de penales'),
                                value: _penales,
                                onChanged: _editable
                                    ? (v) => setState(() {
                                        _penales = v;
                                        _sucio = true;
                                      })
                                    : null,
                              ),
                            ],
                            if (_penales)
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _entero(
                                    _marcador['penales_local']!,
                                    'Penales local',
                                  ),
                                  _entero(
                                    _marcador['penales_visitante']!,
                                    'Penales visitante',
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Marcador según planillas: ${_totales[0]} – ${_totales[1]} (incluye autogoles a favor del rival).',
                            ),
                            if (_fallo != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: SelectableText(
                                  _fallo!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (!_confirmado) ...[
                                  OutlinedButton(
                                    onPressed: _editable
                                        ? () => _guardar(false)
                                        : null,
                                    child: Text(
                                      _ocupado
                                          ? 'Guardando…'
                                          : 'Guardar borrador',
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _editable
                                        ? () => _guardar(true)
                                        : null,
                                    child: const Text('Guardar y confirmar'),
                                  ),
                                ],
                                if (_confirmado)
                                  OutlinedButton.icon(
                                    onPressed: _ocupado || _cerrado
                                        ? null
                                        : _reabrir,
                                    icon: const Icon(Icons.edit_note),
                                    label: const Text('Reabrir con motivo'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class _MotivoReapertura extends StatefulWidget {
  const _MotivoReapertura();
  @override
  State<_MotivoReapertura> createState() => _MotivoReaperturaState();
}

class _MotivoReaperturaState extends State<_MotivoReapertura> {
  final _motivo = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reabrir resultado'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _motivo,
        maxLength: 1000,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Motivo de la corrección'),
        validator: (v) => (v?.trim().length ?? 0) < 10
            ? 'Escribe al menos 10 caracteres.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(context, _motivo.text.trim());
        },
        child: const Text('Reabrir'),
      ),
    ],
  );
}
