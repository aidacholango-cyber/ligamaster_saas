import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/estilo_panel.dart';
import '../models/jugador_vocal.dart';
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
    final canchas =
        _partidos.map((p) => p['cancha'].toString()).toSet().toList()..sort();
    final disponibles = _partidos
        .where((p) => p['cancha'].toString() == _cancha)
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final (i, titulo) in [
                              'Fecha',
                              'Cancha',
                              'Horario',
                            ].indexed)
                              Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: i == _paso
                                      ? const Color(0xFF4351BF)
                                      : Colors.grey.shade300,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: i == _paso
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                label: Text(titulo),
                                backgroundColor: i == _paso
                                    ? const Color(0xFFE8E9FF)
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                              child: Column(
                                children: [
                                  for (final cancha in canchas)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            double.infinity,
                                            56,
                                          ),
                                          backgroundColor: _cancha == cancha
                                              ? const Color(0xFFE8E9FF)
                                              : null,
                                          side: BorderSide(
                                            color: _cancha == cancha
                                                ? const Color(0xFF4351BF)
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        onPressed: () => setState(() {
                                          _cancha = cancha;
                                          _partidoId = null;
                                        }),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _cancha == cancha
                                                  ? Icons.check_circle
                                                  : Icons.sports_soccer,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                cancha,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
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
  const PlanillaVocal({super.key, required this.partidoId});
  final String partidoId;
  @override
  State<PlanillaVocal> createState() => _PlanillaVocalState();
}

class _PlanillaVocalState extends State<PlanillaVocal> {
  Timer? _autoguardado;
  bool _autoSuspendido = false, _confirmando = false;
  String? _errorSincronizacion;
  final _vocal = TextEditingController(), _arbitro = TextEditingController();
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _datos;
  final Map<String, Map<String, dynamic>> _filas = {};
  bool _cargando = true,
      _guardando = false,
      _sucio = false,
      _permitirSalir = false;
  int _version = 0;
  String? _error;
  bool get _editable => _datos?['editable'] == true && !_guardando;
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
          'lm_vocal_leer_partido',
          params: {'p_partido_id': widget.partidoId},
        ),
      );
      if (!mounted) return;
      final borrador = datos['borrador'] as Map?;
      _vocal.text = (borrador?['vocal'] ?? '').toString();
      _arbitro.text = (borrador?['arbitro'] ?? '').toString();
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
    if (!_editable || !_form.currentState!.validate()) return;
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
    if (!_editable || !_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final version = await Supabase.instance.client.rpc(
        finalizar ? 'lm_vocal_finalizar' : 'lm_vocal_guardar',
        params: {
          'p_partido_id': widget.partidoId,
          'p_vocal': _vocal.text.trim(),
          'p_arbitro': _arbitro.text.trim(),
          'p_version': _version,
          'p_jugadores': _filas.values.toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        _version = (version as num).toInt();
        _sucio = false;
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
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregar(dynamic equipoId) async {
    final elegido = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BuscarCamiseta(
        jugadores: _jugadores.where((j) => j['equipo_id'] == equipoId).toList(),
        agregados: _filas.keys.toSet(),
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _filas[elegido['id'].toString()] = {
        'id': elegido['id'],
        'ta': 0,
        'tr': false,
        'goles': 0,
      };
      _sucio = true;
    });
  }

  Widget _equipo(dynamic equipoId, String nombre, String fecha, Color color) {
    final jugadores = _jugadores
        .where(
          (j) =>
              j['equipo_id'] == equipoId &&
              _filas.containsKey(j['id'].toString()),
        )
        .toList();
    return Card(
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
            if (jugadores.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Todavía no se han ingresado jugadores.',
                  textAlign: TextAlign.center,
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 8,
                columnSpacing: 12,
                headingRowColor: WidgetStatePropertyAll(
                  color.withValues(alpha: .08),
                ),
                columns: const [
                  DataColumn(label: Text('N.º')),
                  DataColumn(label: Text('Jugador')),
                  DataColumn(label: Text('TA')),
                  DataColumn(label: Text('TR')),
                  DataColumn(label: Text('Goles')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final j in jugadores)
                    DataRow(
                      key: ValueKey(j['id']),
                      cells: [
                        DataCell(
                          Text(
                            '${j['camiseta'] ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 130,
                            child: Text(
                              nombreCortoVocal(j['nombres'], j['apellidos']),
                            ),
                          ),
                        ),
                        DataCell(
                          DropdownButton<int>(
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
                            width: 54,
                            child: TextFormField(
                              key: ValueKey('goles:${j['id']}'),
                              initialValue: '${_filas[j['id']]!['goles']}',
                              enabled: _editable,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
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
                            tooltip: 'Quitar de la planilla',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: !_editable
                                ? null
                                : () => setState(() {
                                    _filas.remove(j['id']);
                                    _sucio = true;
                                  }),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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
          appBar: AppBar(title: const Text('Planilla del vocal')),
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
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _vocal,
                                  enabled: _editable,
                                  maxLength: 150,
                                  decoration: const InputDecoration(
                                    labelText: 'Vocal',
                                    prefixIcon: Icon(Icons.person_outline),
                                    counterText: '',
                                  ),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Escribe el nombre del vocal.'
                                      : null,
                                  onChanged: (_) =>
                                      setState(() => _sucio = true),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _arbitro,
                                  enabled: _editable,
                                  maxLength: 150,
                                  decoration: const InputDecoration(
                                    labelText: 'Árbitro',
                                    prefixIcon: Icon(Icons.sports),
                                    counterText: '',
                                  ),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Escribe el nombre del árbitro.'
                                      : null,
                                  onChanged: (_) =>
                                      setState(() => _sucio = true),
                                ),
                              ],
                            ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: local),
                                        const SizedBox(width: 16),
                                        Expanded(child: visitante),
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
  const _BuscarCamiseta({required this.jugadores, required this.agregados});
  final List<Map<String, dynamic>> jugadores;
  final Set<String> agregados;
  @override
  State<_BuscarCamiseta> createState() => _BuscarCamisetaState();
}

class _BuscarCamisetaState extends State<_BuscarCamiseta> {
  String _numero = '';
  @override
  Widget build(BuildContext context) {
    final numero = int.tryParse(_numero);
    final coincidencias = buscarCamisetaVocal(widget.jugadores, _numero);
    return Theme(
      data: temaLigaMaster(),
      child: AlertDialog(
        title: const Text('Número de camiseta', textAlign: TextAlign.center),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(labelText: 'Número'),
                  onChanged: (v) => setState(() => _numero = v),
                ),
                const SizedBox(height: 16),
                if (numero != null && coincidencias.isEmpty)
                  const Text(
                    'No hay un jugador inscrito con ese número en este equipo.',
                  ),
                for (final j in coincidencias)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if ((j['foto_url'] ?? '').toString().isNotEmpty)
                            ClipOval(
                              child: Image.network(
                                j['foto_url'],
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) =>
                                    const Icon(Icons.person, size: 70),
                              ),
                            )
                          else
                            const Icon(
                              Icons.person,
                              size: 70,
                              color: Color(0xFF4351BF),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            '${j['nombres']} ${j['apellidos']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (j['habilitado'] != true)
                            const Text(
                              'No está inscrito y calificado para jugar.',
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed:
                                j['habilitado'] != true ||
                                    widget.agregados.contains(
                                      j['id'].toString(),
                                    )
                                ? null
                                : () => Navigator.pop(context, j),
                            child: Text(
                              widget.agregados.contains(j['id'].toString())
                                  ? 'Ya ingresado'
                                  : 'Ingresar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
