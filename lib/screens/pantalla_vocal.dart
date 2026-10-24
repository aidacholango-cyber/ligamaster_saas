import 'dart:async';
import '../models/canchas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/estilo_panel.dart';
import '../models/jugador_vocal.dart';
import '../widgets/tesoreria_equipo.dart';
import '../widgets/firma_dedo.dart';
import 'pantalla_login.dart';

String _fechaVocal(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _horario(dynamic valor) {
  final fecha = DateTime.tryParse(valor.toString());
  if (fecha == null) return 'Horario por definir';
  final d = fecha.toUtc().add(const Duration(hours: -5));
  return '${_fechaVocal(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _falloVocal(Object e) {
  if (e is PostgrestException) {
    if (e.code == 'PGRST202' || e.code == '42883')
      return 'Falta instalar el módulo del vocal en Supabase.';
    return e.message;
  }
  return 'No se pudo completar la operación. Revisa tu conexión e intenta nuevamente.';
}

class PantallaVocal extends StatefulWidget {
  const PantallaVocal({super.key});
  @override
  State<PantallaVocal> createState() => _PantallaVocalState();
}

class _PantallaVocalState extends State<PantallaVocal> {
  DateTime _fecha = DateTime.now().toUtc().add(const Duration(hours: -5));
  String? _cancha, _partidoId, _error;
  List<Map<String, dynamic>> _partidos = [];
  bool _cargando = true;
  int _paso = 0;
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
      final respuesta = await Supabase.instance.client.rpc(
        'lm_vocal_partidos',
        params: {
          'p_fecha':
              '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
        },
      );
      if (!mounted) return;
      setState(() {
        _partidos = (respuesta as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _cancha = null;
        _partidoId = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _falloVocal(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _salir() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _falloVocal(e));
    }
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha del partido',
      confirmText: 'Siguiente',
      cancelText: 'Cancelar',
    );
    if (fecha == null || !mounted) return;
    setState(() {
      _fecha = fecha;
      _paso = 1;
      _cancha = null;
      _partidoId = null;
    });
    await _leer();
  }

  @override
  Widget build(BuildContext context) {
    const canchas = canchasDisponibles;
    final disponibles = _partidos
        .where((p) => canchaValida(p['cancha']) == _cancha)
        .toList();
    return Theme(
      data: temaLigaMaster(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel del vocal'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando
                  ? null
                  : () async {
                      setState(() => _paso = _paso == 0 ? 0 : 1);
                      await _leer();
                    },
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: _salir,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _MarcaVocal(),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Partidos programados',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_paso == 0) ...[
                          const Text('Selecciona la fecha para continuar.'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _cargando ? null : _elegirFecha,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              'Elegir fecha · ${_fechaVocal(_fecha)}',
                            ),
                          ),
                        ] else ...[
                          Text(
                            _fechaVocal(_fecha),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (_cargando)
                            const CircularProgressIndicator()
                          else if (_error != null) ...[
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _leer,
                              child: const Text('Reintentar'),
                            ),
                          ] else if (_partidos.isEmpty)
                            const Text(
                              'No hay partidos programados para esta fecha.',
                              textAlign: TextAlign.center,
                            )
                          else if (_paso == 1) ...[
                            const Text('Selecciona la cancha'),
                            const SizedBox(height: 16),
                            ControlCentrado(
                              child: DropdownButtonFormField<String>(
                                initialValue: _cancha,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Cancha',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.sports_soccer),
                                ),
                                hint: const Text('Selecciona una cancha'),
                                items: [
                                  for (final cancha in canchas)
                                    DropdownMenuItem(
                                      value: cancha,
                                      child: Text(cancha),
                                    ),
                                ],
                                onChanged: (cancha) => setState(() {
                                  _cancha = cancha;
                                  _partidoId = null;
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _cancha == null
                                  ? null
                                  : () => setState(() => _paso = 2),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Siguiente'),
                            ),
                          ] else ...[
                            Text(
                              _cancha ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Selecciona el horario y partido'),
                            const SizedBox(height: 16),
                            ControlCentrado(
                              child: Column(
                                children: [
                                  for (final p in disponibles)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Card(
                                        color: _partidoId == p['id'].toString()
                                            ? const Color(0xFFE8E9FF)
                                            : null,
                                        child: ListTile(
                                          leading: Icon(
                                            _partidoId == p['id'].toString()
                                                ? Icons.check_circle
                                                : Icons.schedule,
                                          ),
                                          title: Text(
                                            _horario(
                                              p['fecha_hora'],
                                            ).split(' · ').last,
                                          ),
                                          subtitle: Text(
                                            "${p['local']} vs ${p['visitante']}\n${p['liga']} · ${p['campeonato']} · ${p['categoria']}",
                                          ),
                                          isThreeLine: true,
                                          onTap: () => setState(
                                            () =>
                                                _partidoId = p['id'].toString(),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Guardar'),
                              onPressed: _partidoId == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlanillaVocal(
                                          partidoId: _partidoId!,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _cargando
                                ? null
                                : () {
                                    if (_paso == 1) {
                                      _elegirFecha();
                                    } else {
                                      setState(() => _paso = 1);
                                    }
                                  },
                            icon: const Icon(Icons.arrow_back),
                            label: Text(
                              _paso == 1 ? 'Cambiar fecha' : 'Volver a canchas',
                            ),
                          ),
                        ],
                      ],
                    ),
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

class PlanillaVocal extends StatefulWidget {
  const PlanillaVocal({super.key, required this.partidoId, this.soloLectura = false,
    this.edicionAdministrador = false});
  final bool soloLectura;
  final bool edicionAdministrador;
  final String partidoId;
  @override
  State<PlanillaVocal> createState() => _PlanillaVocalState();
}

class _PlanillaVocalState extends State<PlanillaVocal> {
  Timer? _autoguardado;
  bool _autoSuspendido = false, _confirmando = false;
  String? _errorSincronizacion;
  final _vocal = TextEditingController(), _arbitro = TextEditingController();
  final _informeArbitral = TextEditingController(), _informeVocal = TextEditingController();
  final _focoVocal = FocusNode(), _focoArbitro = FocusNode();
  final _focoInformeVocal = FocusNode(), _focoInformeArbitral = FocusNode();
  bool get _escribiendo => _focoVocal.hasFocus || _focoArbitro.hasFocus ||
      _focoInformeVocal.hasFocus || _focoInformeArbitral.hasFocus;
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _datos;
  final Map<String, Map<String, dynamic>> _filas = {};
  final Map<String, Map<String, dynamic>> _controlesEquipo = {};
  final Map<String, TrazosFirma> _firmas = {};
  bool _firmando = false;
  bool _guardadoAutomatico = false;
  bool _cargando = true,
      _guardando = false,
      _sucio = false,
      _permitirSalir = false;
  int _version = 0;
  String? _error;
  bool get _editable => !widget.soloLectura && _datos?['editable'] == true && !_guardando;
  bool get _informesEditables => !widget.soloLectura && _datos?['editable'] == true &&
      (!_guardando || _guardadoAutomatico);
  List<Map<String, dynamic>> get _jugadores =>
      (_datos?['jugadores'] as List? ?? [])
          .map((j) => Map<String, dynamic>.from(j))
          .toList();
  @override
  void initState() {
    super.initState();
    _leer();
    _autoguardado = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          _editable &&
          !_confirmando &&
          !_firmando &&
          !_escribiendo &&
          _sucio &&
          !_autoSuspendido &&
          _vocal.text.trim().isNotEmpty &&
          _arbitro.text.trim().isNotEmpty &&
          _filas.values.every((j) => j['goles'] != null)) {
        _guardar(automatico: true);
      }
    });
  }

  @override
  void dispose() {
    _autoguardado?.cancel();
    _vocal.dispose();
    _arbitro.dispose();
    _informeArbitral.dispose();
    _informeVocal.dispose();
    _focoVocal.dispose();
    _focoArbitro.dispose();
    _focoInformeVocal.dispose();
    _focoInformeArbitral.dispose();
    super.dispose();
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = Map<String, dynamic>.from(
        await Supabase.instance.client.rpc(
          widget.soloLectura ? 'lm_hoja_vocalia_leer' : widget.edicionAdministrador
              ? 'lm_admin_hoja_vocalia_leer' : 'lm_vocal_leer_planilla_controles',
          params: {'p_partido_id': widget.partidoId},
        ),
      );
      if (!mounted) return;
      final borrador = datos['borrador'] as Map?;
      _firmas.clear();
      final firmas = borrador?['firmas'] as Map?;
      if (firmas != null) {
        for (final entrada in firmas.entries) {
          _firmas[entrada.key.toString()] = leerFirma(entrada.value);
        }
      }
      _controlesEquipo.clear();
      final controles = borrador?['controles_equipo'] as Map?;
      if (controles != null) {
        for (final entrada in controles.entries) {
          _controlesEquipo[entrada.key.toString()] = Map<String, dynamic>.from(entrada.value as Map);
        }
      }
      _vocal.text = (borrador?['vocal'] ?? '').toString();
      _arbitro.text = (borrador?['arbitro'] ?? '').toString();
      _informeArbitral.text = (borrador?['informe_arbitral'] ?? '').toString();
      _informeVocal.text = (borrador?['informe_vocal'] ?? '').toString();
      _version = (borrador?['version'] as num?)?.toInt() ?? 0;
      _filas.clear();
      for (final j in borrador?['jugadores'] as List? ?? []) {
        _filas[j['id'].toString()] = Map<String, dynamic>.from(j);
      }
      setState(() {
        _datos = datos;
        _sucio = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _falloVocal(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _salir() async {
    if (_guardando) return;
    if (_sucio) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text('¿Deseas salir y descartar estos cambios?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar y salir'),
            ),
          ],
        ),
      );
      if (descartar != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _permitirSalir = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _finalizar() async {
    if (!_editable || _firmando || !_form.currentState!.validate()) return;
    _confirmando = true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar partido y publicar'),
        content: const Text(
          'Se confirmarán los goles y tarjetas ingresados. Los delegados y administradores verán el resultado oficial. Después del cierre esta planilla quedará bloqueada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar planilla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminar y publicar'),
          ),
        ],
      ),
    );
    _confirmando = false;
    if (confirmar == true && mounted) await _guardar(finalizar: true);
  }

  Future<void> _guardar({
    bool automatico = false,
    bool finalizar = false,
  }) async {
    if (!_editable || _firmando || !_form.currentState!.validate()) return;
    final informeVocalEnviado = _informeVocal.text.trim();
    final informeArbitralEnviado = _informeArbitral.text.trim();
    setState(() {
      _guardadoAutomatico = automatico;
      _guardando = true;
    });
    try {
      final version = await Supabase.instance.client.rpc(
        widget.edicionAdministrador ? 'lm_admin_vocal_guardar_planilla_firmas'
            : 'lm_vocal_guardar_planilla_firmas',
        params: {
          'p_partido_id': widget.partidoId,
          'p_vocal': _vocal.text.trim(),
          'p_arbitro': _arbitro.text.trim(),
          'p_version': _version,
          'p_jugadores': _filas.values.toList(),
          'p_controles': _controlesEquipo,
          'p_finalizar': finalizar,
          'p_informe_arbitral': informeArbitralEnviado,
          'p_informe_vocal': informeVocalEnviado,
          'p_firmas': {for (final f in _firmas.entries) f.key: guardarFirma(f.value)},
        },
      );
      if (!mounted) return;
      setState(() {
        _version = (version as num).toInt();
        _sucio = _informeVocal.text.trim() != informeVocalEnviado ||
            _informeArbitral.text.trim() != informeArbitralEnviado;
        _autoSuspendido = false;
        _errorSincronizacion = null;
        if (finalizar) _datos!['editable'] = false;
      });
      if (!automatico) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalizar
                  ? 'Partido terminado. Resultado oficial publicado.'
                  : 'Planilla del vocal guardada.',
            ),
          ),
        );
      }
    } catch (e) {
      if (automatico) {
        if (mounted)
          setState(() {
            _autoSuspendido = true;
            _errorSincronizacion = _falloVocal(e);
          });
        return;
      }
      if (mounted)
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No se pudo guardar'),
            content: Text(_falloVocal(e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver a la planilla'),
              ),
            ],
          ),
        );
    } finally {
      if (mounted) setState(() {
        _guardando = false;
        _guardadoAutomatico = false;
      });
    }
  }

  Future<void> _agregar(dynamic equipoId, {bool cambio = false, int? espacio}) async {
    if (!_editable) return;
    final cantidad = _jugadores.where((j) => j['equipo_id'] == equipoId &&
      _filas.containsKey(j['id'].toString()) &&
      (_filas[j['id'].toString()]!['tipo'] == 'cambio') == cambio).length;
    if (cantidad >= (cambio ? 6 : 11)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cambio ? 'Ya ingresaste los 6 cambios.' : 'Ya ingresaste los 11 titulares.'),
      ));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _BuscarCamiseta(
        jugadores: _jugadores.where((j) => j['equipo_id'] == equipoId).toList(),
        agregados: _filas.keys.toSet(),
        limite: (cambio ? 6 : 11) - cantidad,
        alIngresar: (elegido) {
          if (!mounted) return;
          setState(() {
            _filas[elegido['id'].toString()] = {
              'id': elegido['id'], 'ta': 0, 'tr': false, 'goles': 0,
              'tipo': cambio ? 'cambio' : 'titular',
            };
            _sucio = true;
          });
        },
      ),
    );
  }
  Future<void> _elegirSalida(dynamic equipoId, Map<String, dynamic> entrada) async {
    final titulares = _jugadores.where((j) => j['equipo_id'] == equipoId &&
      _filas.containsKey(j['id'].toString()) &&
      _filas[j['id'].toString()]!['tipo'] != 'cambio').toList();
    final elegido = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BuscarCamiseta(jugadores: titulares,
        agregados: _filas.values.where((f) => f['id'] != entrada['id'])
          .map((f) => f['sale_id']?.toString()).whereType<String>().toSet()),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _filas[entrada['id'].toString()]!['sale_id'] = elegido['id'];
      _sucio = true;
    });
  }

  Widget _tablaEquipo(dynamic equipoId, List<Map<String, dynamic>> jugadores, Color color, bool cambio) {
    final lista = jugadores.where((j) => (_filas[j['id'].toString()]!['tipo'] == 'cambio') == cambio).toList();
    final espacios = <Map<String, dynamic>?>[
      ...lista,
      for (var i = lista.length; i < (cambio ? 6 : 11); i++) null,
    ];
    return
SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 420,
                child: DataTable(
                dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                headingTextStyle: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                border: TableBorder.all(color: Colors.black, width: 1),
                dividerThickness: 0,
                horizontalMargin: 4,
                columnSpacing: 8,
                headingRowColor: const WidgetStatePropertyAll(Color(0xFFD9EFE2)),
                dataRowColor: const WidgetStatePropertyAll(Colors.white),
                columns: [
                  if (cambio) const DataColumn(
                    columnWidth: FixedColumnWidth(28),
                    label: SizedBox(
                      width: 16,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Sale', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  DataColumn(headingRowAlignment: MainAxisAlignment.center, columnWidth: FixedColumnWidth(cambio ? 28 : 56), label: const Text('N.º')),
                  const DataColumn(headingRowAlignment: MainAxisAlignment.center, columnWidth: FixedColumnWidth(148), label: Text('Jugador')),
                  const DataColumn(headingRowAlignment: MainAxisAlignment.center, columnWidth: FixedColumnWidth(44), label: Text('T.A.')),
                  const DataColumn(headingRowAlignment: MainAxisAlignment.center, columnWidth: FixedColumnWidth(44), label: Text('T.R.')),
                  const DataColumn(headingRowAlignment: MainAxisAlignment.center, columnWidth: FixedColumnWidth(64), label: Text('Goles')),
                  const DataColumn(columnWidth: FixedColumnWidth(64), label: Text('')),
                ],
                rows: [
                  for (final j in espacios)
                    if (j == null)
                      DataRow(cells: [
                        if (cambio) DataCell.empty,
                        DataCell.empty, DataCell.empty,
                        DataCell.empty, DataCell.empty,
                        DataCell.empty, DataCell.empty,
                      ])
                    else DataRow(
                      key: ValueKey(j['id']),
                      cells: [
                        if (cambio) DataCell(
                          Text(_jugadores.where((s) => s['id'].toString() == _filas[j['id'].toString()]!['sale_id']?.toString())
                            .map((s) => '${s['camiseta']}').firstOrNull ?? ''),
                          onTap: _editable ? () => _elegirSalida(equipoId, j) : null,
                        ),
                        DataCell(
                          Text(
                            '${j['camiseta'] ?? '—'}',
                            style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Text(
                              nombreCortoVocal(j['nombres'], j['apellidos']),
                            ),
                          ),
                        ),
                        DataCell(
                          DropdownButton<int>(
                            style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                            isDense: true,
                            iconSize: 16,
                            value: _filas[j['id']]!['ta'] as int,
                            items: [
                              for (var n = 0; n <= 2; n++)
                                DropdownMenuItem(value: n, child: Text('$n')),
                            ],
                            onChanged: !_editable
                                ? null
                                : (v) => setState(() {
                                    _filas[j['id']]!['ta'] = v;
                                    _sucio = true;
                                  }),
                          ),
                        ),
                        DataCell(
                          Checkbox(
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            value: _filas[j['id']]!['tr'] == true,
                            onChanged: !_editable
                                ? null
                                : (v) => setState(() {
                                    _filas[j['id']]!['tr'] = v;
                                    _sucio = true;
                                  }),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 40,
                            child: TextFormField(
                              key: ValueKey('goles:${j['id']}'),
                              initialValue: '${_filas[j['id']]!['goles']}',
                              enabled: _editable,
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                              ),
                              validator: (v) =>
                                  int.tryParse(v ?? '') == null ? '0–99' : null,
                              onChanged: (v) => setState(() {
                                _filas[j['id']]!['goles'] = int.tryParse(v);
                                _sucio = true;
                              }),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Quitar de la planilla',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: !_editable
                                ? null
                                : () => setState(() {
                                    _filas.remove(j['id']);
                                    for (final fila in _filas.values) {
                                      if (fila['sale_id'] == j['id']) fila.remove('sale_id');
                                    }
                                    _sucio = true;
                                  }),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              ),
            );
  }

  Widget _cuadroFirma(String clave, String titulo) => FirmaDedo(
    titulo: titulo,
    trazos: _firmas[clave] ?? [],
    alDibujar: (dibujando) => _firmando = dibujando,
    onChanged: !_editable ? null : (trazos) => setState(() {
      _firmas[clave] = trazos;
      _sucio = true;
    }),
  );

  Widget _equipo(dynamic equipoId, String nombre, String fecha, Color color) {
    final jugadores = _jugadores
        .where(
          (j) =>
              j['equipo_id'] == equipoId &&
              _filas.containsKey(j['id'].toString()),
        )
        .toList();
    return SizedBox(
      width: 460,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFB6DCC7)),
          ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              nombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(fecha, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                for (final opcion in const {'balon': 'Balón', 'capitan': 'Capitán', 'camerinos': 'Camerinos'}.entries)
                  TextButton(
                    onPressed: !_editable ? null : () => setState(() {
                      final controles = _controlesEquipo.putIfAbsent(equipoId.toString(), () => {});
                      controles[opcion.key] = controles[opcion.key] != true;
                      _sucio = true;
                    }),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(opcion.value, style: const TextStyle(color: Colors.black)),
                      const SizedBox(width: 6),
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                          border: Border.all(color: Colors.black)),
                        child: _controlesEquipo[equipoId.toString()]?[opcion.key] == true
                            ? const Icon(Icons.check, size: 17, color: Colors.black) : null,
                      ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Tooltip(
              message: 'Ingresar jugador por número de camiseta',
              child: IconButton(
                onPressed: _editable ? () => _agregar(equipoId) : null,
                iconSize: 84,
                icon: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        size: 84,
                        color: _editable
                            ? const Color(0xFF008C45)
                            : Colors.grey,
                      ),
                      const Positioned(
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_soccer,
                            size: 35,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _tablaEquipo(equipoId, jugadores, color, false),
          ],
        ),
      ),
    ),
            const SizedBox(height: 12),
            Tooltip(
              message: 'Ingresar cambio por número de camiseta',
              child: IconButton(
                onPressed: _editable ? () => _agregar(equipoId, cambio: true) : null,
                iconSize: 84,
                icon: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        size: 84,
                        color: _editable
                            ? const Color(0xFF008C45)
                            : Colors.grey,
                      ),
                      const Positioned(
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_soccer,
                            size: 35,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFB6DCC7)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _tablaEquipo(equipoId, jugadores, color, true),
                  TesoreriaEquipo(partidoId: widget.partidoId, equipoId: equipoId.toString()),
                ]),
              ),
            ),
      ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partido = _datos?['partido'] as Map?;
    return Theme(
      data: temaLigaMaster(),
      child: PopScope(
        canPop: _permitirSalir || (!_sucio && !_guardando),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _salir();
        },
        child: Scaffold(
          appBar: AppBar(title: Text(widget.soloLectura ? 'Hoja de vocalía' :
            widget.edicionAdministrador ? 'Vocalía · Ingreso manual' : 'Planilla del vocal')),
          body: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _leer,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const _MarcaVocal(),
                          const SizedBox(height: 20),
                          ControlCentrado(
                            ancho: 620,
                            child: Column(children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: TextFormField(
                                  controller: _vocal, focusNode: _focoVocal, enabled: _editable, maxLength: 150,
                                  decoration: const InputDecoration(labelText: 'Vocal',
                                    prefixIcon: Icon(Icons.person_outline), counterText: ''),
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre del vocal.' : null,
                                  onChanged: (_) => setState(() => _sucio = true),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: TextFormField(
                                  controller: _arbitro, focusNode: _focoArbitro, enabled: _editable, maxLength: 150,
                                  decoration: const InputDecoration(labelText: 'Árbitro',
                                    prefixIcon: Icon(Icons.sports), counterText: ''),
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre del árbitro.' : null,
                                  onChanged: (_) => setState(() => _sucio = true),
                                )),
                              ]),
                              const SizedBox(height: 12),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: TextFormField(
                                  controller: _informeVocal, enabled: _informesEditables,
                                  focusNode: _focoInformeVocal,
                                  minLines: 3, maxLines: 5, maxLength: 5000,
                                  decoration: const InputDecoration(labelText: 'Informe vocal',
                                    alignLabelWithHint: true, border: OutlineInputBorder(), counterText: ''),
                                  onChanged: (_) => setState(() => _sucio = true),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: TextFormField(
                                  controller: _informeArbitral, enabled: _informesEditables,
                                  focusNode: _focoInformeArbitral,
                                  minLines: 3, maxLines: 5, maxLength: 5000,
                                  decoration: const InputDecoration(labelText: 'Informe arbitral',
                                    alignLabelWithHint: true, border: OutlineInputBorder(), counterText: ''),
                                  onChanged: (_) => setState(() => _sucio = true),
                                )),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cancha: ${partido!['cancha'] ?? 'Sin cancha'}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (_datos?['editable'] != true)
                            const Text(
                              'Partido cerrado · Solo consulta',
                              textAlign: TextAlign.center,
                            ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final local = _equipo(
                                partido['equipo_local_id'],
                                partido['local'].toString(),
                                _horario(partido['fecha_hora']),
                                const Color(0xFF166534),
                              );
                              final visitante = _equipo(
                                partido['equipo_visitante_id'],
                                partido['visitante'].toString(),
                                _horario(partido['fecha_hora']),
                                const Color(0xFF4351BF),
                              );
                              return constraints.maxWidth >= 1000
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(child: local),
                                        const SizedBox(width: 16),
                                        Flexible(child: visitante),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        local,
                                        const SizedBox(height: 12),
                                        visitante,
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 20),
                          ControlCentrado(
                            ancho: 936,
                            child: Column(children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: _cuadroFirma('capitan_local', 'Firma capitán · ${partido['local']}')),
                                const SizedBox(width: 16),
                                Expanded(child: _cuadroFirma('capitan_visitante', 'Firma capitán · ${partido['visitante']}')),
                              ]),
                              const SizedBox(height: 16),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: _cuadroFirma('vocal', 'Firma del vocal')),
                                const SizedBox(width: 16),
                                Expanded(child: _cuadroFirma('arbitro', 'Firma del árbitro')),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'TA: tarjeta amarilla · TR: tarjeta roja\nGuardado automático durante el partido. Al terminar, publica el resultado oficial.',
                            textAlign: TextAlign.center,
                          ),
                          if (_errorSincronizacion != null)
                            Text(
                              'No se ha sincronizado: $_errorSincronizacion. Pulsa Guardar planilla para reintentar.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _editable ? _finalizar : null,
                              icon: const Icon(Icons.sports_score),
                              label: const Text('Terminar partido y publicar'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _editable ? _guardar : null,
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _guardando ? 'Guardando…' : 'Guardar planilla',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MarcaVocal extends StatelessWidget {
  const _MarcaVocal();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      CircleAvatar(
        radius: 30,
        backgroundColor: Color(0xFF4351BF),
        child: Icon(Icons.sports_soccer, color: Colors.white, size: 36),
      ),
      SizedBox(height: 10),
      Text(
        'LigaMaster SaaS',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4351BF),
        ),
      ),
    ],
  );
}

class _BuscarCamiseta extends StatefulWidget {
  const _BuscarCamiseta({required this.jugadores, required this.agregados,
    this.alIngresar, this.limite = 1});
  final List<Map<String, dynamic>> jugadores;
  final Set<String> agregados;
  final ValueChanged<Map<String, dynamic>>? alIngresar;
  final int limite;
  @override
  State<_BuscarCamiseta> createState() => _BuscarCamisetaState();
}

class _BuscarCamisetaState extends State<_BuscarCamiseta> {
  final _numero = TextEditingController();
  late final Set<String> _agregados = {...widget.agregados};
  Map<String, dynamic>? _seleccion;
  int _ingresados = 0;
  String? _aviso;
  @override
  void dispose() { _numero.dispose(); super.dispose(); }
  List<Map<String, dynamic>> get _coincidencias => buscarCamisetaVocal(widget.jugadores, _numero.text);
  Map<String, dynamic>? get _elegido => _seleccion ?? (_coincidencias.length == 1 ? _coincidencias.first : null);
  bool get _valido => _elegido != null && _elegido!['habilitado'] == true &&
    !_agregados.contains(_elegido!['id'].toString()) && _ingresados < widget.limite;
  void _cambiar(String valor) {
    setState(() { _numero.text = valor; _seleccion = null; _aviso = null; });
  }
  void _confirmar(bool siguiente) {
    if (!_valido) return;
    final j = _elegido!;
    if (widget.alIngresar == null) { Navigator.pop(context, j); return; }
    widget.alIngresar!(j);
    setState(() {
      _agregados.add(j['id'].toString());
      _ingresados++;
      _numero.clear();
      _seleccion = null;
      _aviso = 'Jugador ingresado en la planilla.';
    });
    if (!siguiente || _ingresados >= widget.limite) Navigator.pop(context);
  }
  Widget _tecla(String etiqueta) => Expanded(child: Padding(
    padding: const EdgeInsets.all(3),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: etiqueta == 'C' || etiqueta == '⌫'
            ? const Color(0xFFF8D5E9) : const Color(0xFFFCEAF4),
        foregroundColor: const Color(0xFF98105B),
        side: const BorderSide(color: Color(0xFFE6A5CA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        if (etiqueta == '⌫') {
          if (_numero.text.isNotEmpty) _cambiar(_numero.text.substring(0, _numero.text.length - 1));
        } else if (etiqueta == 'C') {
          _cambiar('');
        } else if (_numero.text.length < 3) {
          _cambiar('${_numero.text}$etiqueta');
        }
      },
      child: Text(etiqueta, style: const TextStyle(fontSize: 20)),
    ),
  ));
  @override
  Widget build(BuildContext context) {
    final elegido = _elegido;
    return Theme(data: temaLigaMaster(), child: AlertDialog(
      backgroundColor: const Color(0xFFFFF8FC),
      title: const Text('Número de camiseta', textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF98105B), fontWeight: FontWeight.bold)),
      content: SizedBox(width: 320, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _numero, autofocus: true,
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: const InputDecoration(labelText: 'Número'),
            onChanged: (_) => setState(() { _seleccion = null; _aviso = null; }),
            onSubmitted: (_) { if (_valido) _confirmar(widget.alIngresar != null); },
          ),
          const SizedBox(height: 8),
          if (_aviso != null) Text(_aviso!),
          if (_numero.text.isNotEmpty && _coincidencias.isEmpty)
            const Text('No hay un jugador inscrito con ese número en este equipo.'),
          if (_coincidencias.length > 1)
            for (final j in _coincidencias)
              ListTile(dense: true,
                title: Text('${j['nombres']} ${j['apellidos']}'),
                selected: _seleccion?['id'] == j['id'],
                onTap: () => setState(() => _seleccion = j)),
          if (elegido != null) ...[
            if ((elegido['foto_url'] ?? '').toString().isNotEmpty)
              ClipOval(child: Image.network(elegido['foto_url'].toString(), width: 48, height: 48,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48))),
            Text('${elegido['nombres']} ${elegido['apellidos']}', textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
            if (elegido['habilitado'] != true) const Text('No está inscrito y calificado para jugar.'),
            if (_agregados.contains(elegido['id'].toString())) const Text('Ya ingresado'),
          ],
          const SizedBox(height: 8),
          for (final fila in const [['1','2','3'], ['4','5','6'], ['7','8','9'], ['C','0','⌫']])
            Row(children: [for (final tecla in fila) _tecla(tecla)]),
        ],
      ))),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF98105B)),
          onPressed: _numero.text.isEmpty ? () => Navigator.pop(context) : _valido ? () => _confirmar(false) : null,
          child: const Text('Listo'),
        ),
        if (widget.alIngresar != null) FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBC1676), foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFF0D5E5),
            disabledForegroundColor: const Color(0xFF95607E),
          ),
          onPressed: _valido ? () => _confirmar(true) : null,
          icon: const Icon(Icons.arrow_forward), label: const Text('Guardar y siguiente'),
        ) else FilledButton(onPressed: _valido ? () => _confirmar(false) : null,
          child: const Text('Seleccionar')),
      ],
    ));
  }
}
