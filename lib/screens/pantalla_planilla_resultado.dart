import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tesoreria_equipo.dart';
import '../widgets/editar_conteo_partidos.dart';
import 'pantalla_vocal.dart';

const _azul = Color(0xFF4351BF);
String _errorActa(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StateError) return e.message.toString();
  return 'No se pudo completar la operación. Comprueba tu conexión.';
}

class _FilaJugador {
  final Map<String, dynamic> datos;
  bool participo;
  int amarillas;
  bool rojaDirecta;
  final TextEditingController goles, autogoles;
  _FilaJugador(this.datos, Map<String, dynamic>? pl)
    : participo = pl?['participo'] == true,
      amarillas = (pl?['amarillas'] as num?)?.toInt() ?? 0,
      rojaDirecta = pl?['roja_directa'] == true,
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
  Future<Map<String, dynamic>>? _conteos;
  Set<String>? _equiposAbiertosGuardados;
  Set<String> get _equiposAbiertos => _equiposAbiertosGuardados ??= <String>{};
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
      // Obtener los escudos actuales sin modificar los datos del acta.
      try {
        final equipos = await _db.from('equipos')
            .select('id,escudo_url,logo_url')
            .inFilter('id', [for (final e in datos['equipos'] as List) e['id']]);
        final porId = {for (final e in equipos) e['id'].toString(): e};
        datos['equipos'] = [for (final e in datos['equipos'] as List)
          {...Map<String, dynamic>.from(e), ...?porId[e['id'].toString()]}];
      } catch (_) {
        // Una imagen no disponible no debe impedir consultar la planilla.
      }
      if (!mounted) return;
      final planillas = {
        for (final p in datos['planillas'] as List)
          p['inscripcion_jugador_id']: Map<String, dynamic>.from(p),
      };
      final jugadoresAnteriores = _jugadores;
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
        _conteos = _consultarConteos();
        _sucio = false;
        _prorroga = resultado?['prorroga_local'] != null;
        _penales = resultado?['penales_local'] != null;
      });
      // Los campos anteriores deben salir del árbol antes de liberar sus controles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final jugador in jugadoresAnteriores) {
          jugador.dispose();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _fallo = _errorActa(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<Map<String, dynamic>> _consultarConteos() async =>
      Map<String, dynamic>.from(await _db.rpc(
        'lm_conteo_partidos_jugadores',
        params: {'p_partido_id': widget.partidoId},
      ));

  Widget _conteoJugador(_FilaJugador jugador) => FutureBuilder<Map<String, dynamic>>(
    future: _conteos,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(() { _conteos = _consultarConteos(); }),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar conteo de partidos'),
        );
      }
      final conteo = snapshot.data?[jugador.datos['inscripcion_id'].toString()] as Map?;
      final partidos = List<Map<String, dynamic>>.from(conteo?['partidos'] as List? ?? []);
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFCE6F3), foregroundColor: const Color(0xFF98105B),
          side: const BorderSide(color: Color(0xFFE6A5CA)),
        ),
        icon: const Icon(Icons.event_available),
        label: Text(snapshot.hasData ? 'Partidos jugados: ${conteo?['total'] ?? 0}' : 'Cargando conteo…'),
        onPressed: !snapshot.hasData ? null : () async {
          Map? conteoActual = conteo;
          await showDialog<void>(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (ctx, actualizarDialogo) => AlertDialog(
            title: Text('Partidos · ${jugador.datos['nombres']} ${jugador.datos['apellidos'] ?? ''}'),
            content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total en este campeonato: ${conteoActual?['total'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Automático: ${conteoActual?['automatico'] ?? conteoActual?['total'] ?? 0} · Ajuste manual: ${conteoActual?['ajuste'] ?? 0}'),
                const SizedBox(height: 8),
                const Text('Conteo automático de resultados confirmados. Solo cuenta a quienes están marcados como participantes.'),
                for (final p in partidos) ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Jornada ${p['jornada']} · Partido ${p['numero_partido']}'),
                  subtitle: Text('${p['local']} vs ${p['visitante']}'),
                ),
                if (partidos.isEmpty) const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Todavía no tiene participaciones confirmadas.'),
                ),
              ],
            ))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar conteo'),
                onPressed: () async {
                  final guardado = await editarConteoPartidos(ctx,
                    inscripcionId: jugador.datos['inscripcion_id'].toString(),
                    total: (conteoActual?['total'] as num?)?.toInt() ?? 0,
                    ajuste: (conteoActual?['ajuste'] as num?)?.toInt() ?? 0,
                  );
                  if (guardado == true && mounted) {
                    try {
                      final nuevos = await _consultarConteos();
                      if (!mounted) return;
                      setState(() { _conteos = Future.value(nuevos); });
                      if (ctx.mounted) actualizarDialogo(() {
                        conteoActual = nuevos[jugador.datos['inscripcion_id'].toString()] as Map?;
                      });
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('La corrección se guardó, pero no se pudo actualizar el conteo: ${_errorActa(e)}')),
                      );
                    }
                  }
                },
              ),
            ],
          )),
        );
        },

      );
    },
  );

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
        'lm_guardar_acta_tarjetas',
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
                'amarillas': j.amarillas,
                'roja_directa': j.rojaDirecta,
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
        child: !(enabled ?? _editable)
            ? InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  enabled: false,
                  filled: true,
                  fillColor: label == 'Autogoles' ? const Color(0xFFFFF0DC) : const Color(0xFFE2F3E8),
                  border: const OutlineInputBorder(),
                ),
                child: Text(c.text, style: const TextStyle(color: Colors.black87)),
              )
            : TextFormField(
          key: ObjectKey(c),
          controller: c,
          enabled: enabled ?? _editable,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: label == 'Autogoles' ? const Color(0xFFFFF0DC) : const Color(0xFFE2F3E8),
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
  Widget _escudoEquipo(dynamic id) {
    final equipo = (_datos!['equipos'] as List).firstWhere(
      (e) => e['id'] == id, orElse: () => <String, dynamic>{});
    final escudo = equipo['escudo_url']?.toString().trim() ?? '';
    final url = escudo.isNotEmpty ? escudo
      : equipo['logo_url']?.toString().trim() ?? '';
    final respaldo = Icon(Icons.shield_outlined, size: 44,
      color: id == _partido['equipo_local_id']
        ? const Color(0xFF166534) : const Color(0xFF1D4ED8));
    return Center(child: Container(
      width: 70, height: 70,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8DE))),
      child: url.isEmpty ? respaldo : Image.network(url, fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, error, stack) => respaldo),
    ));
  }

  Widget _tablaEquipo(dynamic id) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _escudoEquipo(id),
      Center(child: SizedBox(width: 360, child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: id == _partido['equipo_local_id'] ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => setState(() {
          if (!_equiposAbiertos.add(id.toString())) _equiposAbiertos.remove(id.toString());
        }),
        child: Row(children: [
          const SizedBox(width: 24),
          Expanded(child: Text(_nombreEquipo(id), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Icon(_equiposAbiertos.contains(id.toString()) ? Icons.expand_less : Icons.expand_more, size: 24),
        ]),
      ))),
      if (_equiposAbiertos.contains(id.toString()))
      Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFB6DCC7))),
        child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_jugadores.any((j) => j.datos['equipo_id'] == id && j.participo))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay participantes registrados en esta planilla. Puedes ingresarlos desde Ingresar vocalía manual.',
              ),
            ),
          for (final j in _jugadores.where((j) => j.datos['equipo_id'] == id && j.participo))
            Padding(
              key: ValueKey('jugador-acta:${j.datos['inscripcion_id']}'),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${j.datos['nombres']} ${j.datos['apellidos'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Camiseta: ${j.datos['camiseta'] ?? 'Sin registrar'} · ${j.activo ? (j.datos['estado_jugador'] ?? 'Inscrito') : 'Retirado'}',
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _conteoJugador(j),
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
                      SizedBox(
                        width: 145,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('${j.datos['inscripcion_id']}:${j.amarillas}'),
                          initialValue: j.amarillas,
                          decoration: const InputDecoration(
                            labelText: 'Amarillas',
                            filled: true,
                            fillColor: Color(0xFFFFF3C4),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0')),
                            DropdownMenuItem(value: 1, child: Text('1')),
                            DropdownMenuItem(value: 2, child: Text('2')),
                          ],
                          onChanged: _editable
                              ? (valor) {
                                  if (valor == null) return;
                                  setState(() {
                                    j.amarillas = valor;
                                    _sucio = true;
                                  });
                                }
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 195,
                        child: CheckboxListTile(
                          tileColor: const Color(0xFFFDE8E7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Roja directa'),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: j.rojaDirecta,
                          onChanged: _editable
                              ? (valor) {
                                  setState(() {
                                    j.rojaDirecta = valor == true;
                                    _sucio = true;
                                  });
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
          TesoreriaEquipo(partidoId: widget.partidoId, equipoId: id.toString()),
        ],
        ),
      )),
    ]),
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
                            if (!_confirmado && !_cerrado)
                              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_document),
                                label: const Text('Ingresar vocalía manual'),
                                onPressed: _ocupado ? null : () async {
                                  if (!await _descartar() || !mounted) return;
                                  if (!context.mounted) return;
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => PlanillaVocal(partidoId: widget.partidoId, edicionAdministrador: true),
                                  ));
                                  if (mounted) await _leer();
                                },
                              )),
                            if (_confirmado)
                              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('Hoja de vocalía'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFBC1676), foregroundColor: Colors.white,
                                  side: BorderSide.none,
                                ),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PlanillaVocal(partidoId: widget.partidoId, soloLectura: true),
                                )),
                              )),
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
                              'Selecciona un equipo para consultar sus jugadores, partidos jugados y cobros.',
                            ),
                            _tablaEquipo(_partido['equipo_local_id']),
                            _tablaEquipo(_partido['equipo_visitante_id']),
                            const SizedBox(height: 16),
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
