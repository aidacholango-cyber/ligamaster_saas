import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cobro_manual.dart';
import 'revision_sanciones_tesoreria.dart';

String _errorCobro(Object e) {
  if (e is PostgrestException) {
    if (e.code == 'PGRST202' || e.code == '42883') {
      return 'Falta instalar el módulo de tesorería en Supabase.';
    }
    return e.message;
  }
  return 'No se pudo consultar o guardar el cobro. Intenta nuevamente.';
}

class TesoreriaEquipo extends StatefulWidget {
  const TesoreriaEquipo({
    super.key,
    required this.partidoId,
    required this.equipoId,
    this.alCambiar,
  });
  final String partidoId, equipoId;
  final VoidCallback? alCambiar;
  @override
  State<TesoreriaEquipo> createState() => _TesoreriaEquipoState();
}

class _TesoreriaEquipoState extends State<TesoreriaEquipo> {
  late Future<Map<String, dynamic>> _carga;
  @override
  void initState() {
    super.initState();
    _carga = _leer();
  }

  @override
  void didUpdateWidget(covariant TesoreriaEquipo old) {
    super.didUpdateWidget(old);
    if (old.partidoId != widget.partidoId || old.equipoId != widget.equipoId) {
      _carga = _leer();
    }
  }

  Future<Map<String, dynamic>> _leer() async => Map<String, dynamic>.from(
    await Supabase.instance.client.rpc(
      'lm_tesoreria_leer',
      params: {
        'p_partido_id': widget.partidoId,
        'p_equipo_id': int.parse(widget.equipoId),
      },
    ),
  );
  Future<void> _abrir(Map<String, dynamic> datos) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _DetalleTesoreria(
        partidoId: widget.partidoId,
        equipoId: widget.equipoId,
        datos: datos,
      ),
    );
    if (mounted) {
      setState(() { _carga = _leer(); });
      widget.alCambiar?.call();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _carga,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(() { _carga = _leer(); }),
          icon: const Icon(Icons.refresh),
          label: Text(_errorCobro(snapshot.error!)),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Cargando tesorería…'),
        );
      }
      final datos = snapshot.data!;
      final publicado = datos['publicado'] as Map?;
      final items = List<Map<String, dynamic>>.from(
        publicado?['items'] as List? ?? [],
      );
      final texto = publicado == null
          ? datos['puede_editar'] == true
                ? 'Tesorería · Ingresar cobros'
                : 'Tesorería · Cobro pendiente'
          : 'Total a pagar: ${publicado['moneda']} ${importeCentavos(totalCobro(items))}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF166534),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _abrir(datos),
          icon: const Icon(Icons.receipt_long),
          label: Text(texto),
        ),
      );
    },
  );
}

class _DetalleTesoreria extends StatefulWidget {
  const _DetalleTesoreria({
    required this.partidoId,
    required this.equipoId,
    required this.datos,
  });
  final String partidoId, equipoId;
  final Map<String, dynamic> datos;
  @override
  State<_DetalleTesoreria> createState() => _DetalleState();
}

class _DetalleState extends State<_DetalleTesoreria> {
  bool _cambio = false;
  Future<void> _editar() async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarTesoreria(
        partidoId: widget.partidoId,
        equipoId: widget.equipoId,
        datos: widget.datos,
      ),
    );
    if (guardado == true && mounted) {
      _cambio = true;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicado = widget.datos['publicado'] as Map?;
    final items = List<Map<String, dynamic>>.from(
      publicado?['items'] as List? ?? [],
    );
    final moneda = publicado?['moneda'] ?? '';
    return AlertDialog(
      title: Text('Tesorería · ${widget.datos['equipo']}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.datos['puede_editar'] == true)
                RevisionSancionesTesoreria(partidoId: widget.partidoId, equipoId: widget.equipoId),
              if (publicado == null)
                const Text(
                  'El administrador todavía no ha publicado los cobros de este partido.',
                ),
              if (widget.datos['puede_editar'] == true &&
                  widget.datos['borrador'] != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Hay un borrador. El delegado solo ve la versión publicada.',
                  ),
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(detalleCobro(item))),
                      const SizedBox(width: 12),
                      Text(
                        '$moneda ${importeCentavos((item['centavos'] as num).toInt())}',
                      ),
                    ],
                  ),
                ),
              if (publicado != null) ...[
                const Divider(),
                Text(
                  'Total a pagar: $moneda ${importeCentavos(totalCobro(items))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _cambio),
          child: const Text('Cerrar'),
        ),
        if (widget.datos['puede_editar'] == true)
          FilledButton(
            onPressed: _editar,
            child: const Text('Ingresar / editar cobros'),
          ),
      ],
    );
  }
}

class _LineaCobro {
  _LineaCobro({
    this.tipo = 'otro',
    String monto = '',
    String camiseta = '',
    String concepto = '',
  }) : monto = TextEditingController(text: monto),
       camiseta = TextEditingController(text: camiseta),
       concepto = TextEditingController(text: concepto);
  factory _LineaCobro.desde(Map<String, dynamic> item) => _LineaCobro(
    tipo: item['tipo'],
    monto: importeCentavos((item['centavos'] as num).toInt()),
    camiseta: item['camiseta']?.toString() ?? '',
    concepto: item['concepto']?.toString() ?? '',
  );
  String tipo;
  final TextEditingController monto, camiseta, concepto;
  void dispose() {
    monto.dispose();
    camiseta.dispose();
    concepto.dispose();
  }

  Map<String, dynamic> get item => {
    'tipo': tipo,
    'centavos': leerCentavos(monto.text)!,
    if (tipo == 'ta' || tipo == 'tr') 'camiseta': camiseta.text.trim(),
    if (tipo == 'otro') 'concepto': concepto.text.trim(),
  };
}

class _EditarTesoreria extends StatefulWidget {
  const _EditarTesoreria({
    required this.partidoId,
    required this.equipoId,
    required this.datos,
  });
  final String partidoId, equipoId;
  final Map<String, dynamic> datos;
  @override
  State<_EditarTesoreria> createState() => _EditorState();
}

class _EditorState extends State<_EditarTesoreria> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _moneda = TextEditingController();
  final List<_LineaCobro> _lineas = [];
  final List<_LineaCobro> _retiradas = [];
  bool _ocupado = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final anterior =
        (widget.datos['borrador'] ?? widget.datos['publicado']) as Map?;
    _moneda.text = anterior?['moneda']?.toString() ?? '';
    for (final item in anterior?['items'] as List? ?? []) {
      _lineas.add(_LineaCobro.desde(Map<String, dynamic>.from(item)));
    }
    if (_lineas.isEmpty) {
      _lineas.addAll([
        _LineaCobro(tipo: 'arbitraje'),
        _LineaCobro(tipo: 'mantenimiento'),
      ]);
    }
  }

  @override
  void dispose() {
    _moneda.dispose();
    _scroll.dispose();
    for (final l in [..._lineas, ..._retiradas]) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar(bool publicar) async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Revisa los campos marcados antes de guardar.');
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_lineas.isEmpty) {
      setState(
        () =>
            _error = 'Añade al menos un concepto, incluso si su monto es cero.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_tesoreria_guardar',
        params: {
          'p_partido_id': widget.partidoId,
          'p_equipo_id': int.parse(widget.equipoId),
          'p_revision': widget.datos['revision'] ?? 0,
          'p_publicar': publicar,
          'p_cobro': {
            'moneda': _moneda.text.trim().toUpperCase(),
            'items': _lineas.map((l) => l.item).toList(),
          },
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorCobro(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lineas.fold<int>(
      0,
      (n, l) => n + (leerCentavos(l.monto.text) ?? 0),
    );
    return PopScope(
      canPop: !_ocupado,
      child: AlertDialog(
        title: Text('Cobros manuales · ${widget.datos['equipo']}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            controller: _scroll,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ingresa los valores que corresponden a este equipo y partido. Las tarjetas no generan cobros automáticos.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _moneda,
                    enabled: !_ocupado,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Moneda (USD o \$)',
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => monedaCobroValida(v ?? '')
                        ? null
                        : 'Escribe USD, otra moneda de tres letras o \$, € o £.',
                    onChanged: (_) => setState(() {}),
                  ),
                  for (final l in _lineas)
                    Card(
                      key: ObjectKey(l),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: l.tipo,
                                    isExpanded: true,
                                    items: [
                                      for (final c in conceptosCobro.entries)
                                        DropdownMenuItem(
                                          value: c.key,
                                          child: Text(c.value),
                                        ),
                                    ],
                                    onChanged: _ocupado
                                        ? null
                                        : (v) => setState(() => l.tipo = v!),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Quitar concepto',
                                  onPressed: _ocupado
                                      ? null
                                      : () => setState(() {
                                          _lineas.remove(l);
                                          _retiradas.add(l);
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (l.tipo == 'ta' || l.tipo == 'tr')
                              TextFormField(
                                controller: l.camiseta,
                                enabled: !_ocupado,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Número del jugador sancionado',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                ),
                                validator: (v) =>
                                    RegExp(
                                      r'^\d{1,3}$',
                                    ).hasMatch((v ?? '').trim())
                                    ? null
                                    : 'Escribe el número de camiseta.',
                              ),
                            if (l.tipo == 'otro')
                              TextFormField(
                                controller: l.concepto,
                                enabled: !_ocupado,
                                maxLength: 150,
                                decoration: const InputDecoration(
                                  labelText: 'Concepto',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                ),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Describe el cobro.'
                                    : null,
                              ),
                            if (l.tipo == 'ta' ||
                                l.tipo == 'tr' ||
                                l.tipo == 'otro')
                              const SizedBox(height: 16),
                            TextFormField(
                              controller: l.monto,
                              enabled: !_ocupado,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Monto',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                hintText: '0.00',
                              ),
                              validator: (v) => leerCentavos(v ?? '') == null
                                  ? 'Ingresa un monto positivo o cero, con hasta 2 decimales.'
                                  : null,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _ocupado || _lineas.length >= 100
                        ? null
                        : () => setState(() => _lineas.add(_LineaCobro())),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir sanción u otro cobro'),
                  ),
                  Text(
                    'Total: ${_moneda.text.toUpperCase()} ${importeCentavos(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Guardar borrador conserva el detalle publicado anterior. Publicar hace visible este desglose al delegado.',
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
          OutlinedButton(
            onPressed: _ocupado ? null : () => _guardar(false),
            child: const Text('Guardar borrador'),
          ),
          FilledButton(
            onPressed: _ocupado ? null : () => _guardar(true),
            child: Text(_ocupado ? 'Guardando…' : 'Publicar cobro'),
          ),
        ],
      ),
    );
  }
}

class TesoreriaCampeonatoDelegado extends StatefulWidget {
  const TesoreriaCampeonatoDelegado({
    super.key,
    required this.campeonatoId,
    required this.equipoId,
  });
  final String campeonatoId, equipoId;
  @override
  State<TesoreriaCampeonatoDelegado> createState() => _ListaTesoreriaState();
}

class _ListaTesoreriaState extends State<TesoreriaCampeonatoDelegado> {
  late Future<List<Map<String, dynamic>>> _carga;
  Future<List<Map<String, dynamic>>> _leer() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client.rpc(
          'lm_tesoreria_partidos_equipo',
          params: {
            'p_campeonato_id': widget.campeonatoId,
            'p_equipo_id': int.parse(widget.equipoId),
          },
        ),
      );
  @override
  void initState() {
    super.initState();
    _carga = _leer();
  }

  @override
  void didUpdateWidget(covariant TesoreriaCampeonatoDelegado old) {
    super.didUpdateWidget(old);
    if (old.campeonatoId != widget.campeonatoId ||
        old.equipoId != widget.equipoId) {
      _carga = _leer();
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Tesorería · Cobros por partido'),
    leading: const Icon(Icons.receipt_long),
    children: [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _carga,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(() => _carga = _leer()),
              child: Text(_errorCobro(snapshot.error!)),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return const Text('Todavía no hay partidos para este equipo.');
          }
          return Column(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _carga = _leer()),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar cobros'),
              ),
              for (final p in snapshot.data!)
                ListTile(
                  title: Text(
                    'Jornada ${p['jornada']} · ${p['local']} vs ${p['visitante']}',
                  ),
                  subtitle: TesoreriaEquipo(
                    key: ValueKey('${p['id']}:${snapshot.data.hashCode}'),
                    partidoId: p['id'].toString(),
                    equipoId: widget.equipoId,
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
