import '../widgets/movimiento_tesoreria_dialog.dart';
import '../widgets/tesoreria_equipo.dart';
import '../widgets/revision_sanciones_tesoreria.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cobro_manual.dart';
import '../models/estado_cuenta.dart';
import '../services/imprimir_tesoreria.dart';

class PantallaTesoreria extends StatefulWidget {
  const PantallaTesoreria({super.key, required this.ligaId});
  final String ligaId;
  @override
  State<PantallaTesoreria> createState() => _PantallaTesoreriaState();
}

class _PantallaTesoreriaState extends State<PantallaTesoreria> {
  final _db = Supabase.instance.client;
  late Future<Map<String, dynamic>> _catalogo;
  Future<Map<String, dynamic>>? _estado;
  String? _campeonato;
  String? _grupoCampeonato;
  int? _equipo;
  DateTime? _desde, _hasta;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _catalogo = _leerCatalogo();
  }

  Future<Map<String, dynamic>> _leerCatalogo() async {
    final datos = Map<String, dynamic>.from(
      await _db.rpc(
        'lm_tesoreria_catalogo',
        params: {'p_liga_id': widget.ligaId},
      ),
    );
    final grupos = await _db
        .from('campeonatos')
        .select('id,grupo_campeonato_id')
        .eq('liga_id', widget.ligaId);
    final porId = {
      for (final c in grupos) '${c['id']}': c['grupo_campeonato_id'],
    };
    datos['campeonatos'] = [
      for (final c in datos['campeonatos'] as List)
        {
          ...Map<String, dynamic>.from(c),
          'grupo_campeonato_id': porId['${c['id']}'] ?? c['id'],
        },
    ];
    return datos;
  }

  InputDecoration _decoracionFiltro(
    String etiqueta,
    Color color,
    IconData icono,
  ) => InputDecoration(
    labelText: etiqueta,
    filled: true,
    fillColor: color.withValues(alpha: 0.08),
    labelStyle: TextStyle(color: color),
    prefixIcon: Icon(icono, color: color, size: 20),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color.withValues(alpha: 0.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 2),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  void _cargar() {
    setState(() {
      _estado = _campeonato == null || _equipo == null
          ? null
          : _db
                .rpc(
                  'lm_tesoreria_estado_cuenta',
                  params: {
                    'p_campeonato_id': _campeonato,
                    'p_equipo_id': _equipo,
                  },
                )
                .then((valor) => Map<String, dynamic>.from(valor));
    });
  }

  void _mensaje(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is PostgrestException
              ? error.message
              : error is UnsupportedError
              ? error.message ?? 'Impresión no disponible.'
              : 'No se pudo completar la operación. Intenta nuevamente.',
        ),
      ),
    );
  }

  Future<void> _fecha(bool inicio) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: (inicio ? _desde : _hasta) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha == null || !mounted) return;
    setState(() {
      if (inicio)
        _desde = fecha;
      else
        _hasta = fecha;
      if (_desde != null && _hasta != null && _desde!.isAfter(_hasta!)) {
        if (inicio)
          _hasta = fecha;
        else
          _desde = fecha;
      }
    });
  }

  Future<void> _registrar(Map<String, dynamic> partido) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MovimientoTesoreriaDialog(
        ligaId: widget.ligaId,
        equipoId: _equipo!,
        partido: partido,
      ),
    );
    if (guardado == true && mounted) _cargar();
  }

  Future<void> _comprobante(String ruta) async {
    try {
      final bytes = await _db.storage
          .from('tesoreria_comprobantes')
          .download(ruta);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Comprobante'),
          content: SizedBox(
            width: 600,
            height: 500,
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
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
    } catch (e) {
      _mensaje(e);
    }
  }

  Future<void> _anular(Map<String, dynamic> movimiento) async {
    final motivo = TextEditingController();
    final ruta = DialogRoute<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular movimiento'),
        content: TextField(
          controller: motivo,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Motivo de la anulación',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (motivo.text.trim().isNotEmpty)
                Navigator.pop(ctx, motivo.text.trim());
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    final texto = await Navigator.of(context).push(ruta);
    await ruta.completed;
    motivo.dispose();
    if (texto == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _db.rpc(
        'lm_tesoreria_anular_movimiento',
        params: {'p_id': movimiento['id'], 'p_motivo': texto},
      );
      if (mounted) _cargar();
    } catch (e) {
      _mensaje(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _importe(String titulo, int monto, String moneda, Color color) =>
      Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(color: color)),
            const SizedBox(height: 6),
            Text(
              '$moneda ${dineroTesoreria(monto)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ],
        ),
      );

  Widget _partido(Map<String, dynamic> partido, bool editable) {
    final cobro = partido['cobro'] as Map?;
    final movimientos = List<Map<String, dynamic>>.from(
      partido['movimientos'] as List? ?? [],
    );
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${partido['local']} vs ${partido['visitante']}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF166534),
              ),
            ),
            Text(
              '${fechaTesoreria(partido['fecha'])} · Jornada ${partido['jornada']} · Partido ${partido['numero_partido']}',
            ),
            const Divider(),
            if (editable) RevisionSancionesTesoreria(partidoId: '${partido['partido_id']}', equipoId: '$_equipo'),
            if (cobro == null) ...[
              const Text(
                'Cobro de este equipo pendiente de publicar. No suma al total.',
                style: TextStyle(
                  color: Color(0xFF925900),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (editable)
                TesoreriaEquipo(
                  partidoId: '${partido['partido_id']}',
                  equipoId: '$_equipo',
                  alCambiar: _cargar,
                ),
            ],
            for (final item in List<Map<String, dynamic>>.from(
              cobro?['items'] as List? ?? [],
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(detalleCobro(item))),
                    Text(
                      '${cobro?['moneda']} ${dineroTesoreria((item['centavos'] as num).toInt())}',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (cobro != null)
              Text(
                'Total de este equipo: ${cobro['moneda']} ${dineroTesoreria(totalCobro(List<Map<String, dynamic>>.from(cobro['items'] as List)))}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (editable && cobro != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: FilledButton.icon(
                  onPressed: _ocupado ? null : () => _registrar(partido),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar pago / entrega al árbitro'),
                ),
              ),
            for (final m in movimientos)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: m['anulado_en'] != null
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m['tipo'] == 'aporte_equipo' ? 'Pago recibido del equipo' : 'Entregado al árbitro'}'
                      '${m['anulado_en'] == null ? '' : ' · ANULADO'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${fechaTesoreria(m['fecha'])} · ${m['moneda']} ${dineroTesoreria((m['centavos'] as num).toInt())}',
                    ),
                    if ('${m['referencia'] ?? ''}'.isNotEmpty)
                      Text('Referencia: ${m['referencia']}'),
                    if ('${m['beneficiario'] ?? ''}'.isNotEmpty)
                      Text('Árbitro: ${m['beneficiario']}'),
                    if (m['anulado_en'] != null)
                      Text('Motivo: ${m['motivo_anulacion']}'),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (m['comprobante'] != null)
                          TextButton.icon(
                            onPressed: _ocupado
                                ? null
                                : () => _comprobante('${m['comprobante']}'),
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Ver comprobante'),
                          ),
                        if (editable && m['anulado_en'] == null)
                          TextButton(
                            onPressed: _ocupado ? null : () => _anular(m),
                            child: const Text('Anular con motivo'),
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

  Widget _informe(Map<String, dynamic> datos) {
    final partidos = partidosEnPeriodo(
      List<Map<String, dynamic>>.from(datos['cobros'] as List),
      _desde,
      _hasta,
    );
    final balances = balancesTesoreria(partidos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estado de cuenta de ${datos['equipo']}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF166534),
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${partidos.length} partidos · ${partidos.where((p) => p['cobro'] != null).length} cobros publicados. '
          'Los totales suman únicamente los importes de este equipo en esos partidos.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _fecha(true),
              child: Text(
                _desde == null
                    ? 'Partidos desde…'
                    : fechaTesoreria(_desde!.toIso8601String()),
              ),
            ),
            OutlinedButton(
              onPressed: () => _fecha(false),
              child: Text(
                _hasta == null
                    ? 'Partidos hasta…'
                    : fechaTesoreria(_hasta!.toIso8601String()),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _desde = null;
                _hasta = null;
              }),
              child: const Text('Todo el historial'),
            ),
            FilledButton.icon(
              onPressed: partidos.isEmpty
                  ? null
                  : () async {
                      try {
                        await imprimirTesoreria(
                          htmlEstadoCuenta(
                            datos,
                            partidos,
                            desde: _desde,
                            hasta: _hasta,
                          ),
                        );
                      } catch (e) {
                        _mensaje(e);
                      }
                    },
              icon: const Icon(Icons.print),
              label: const Text('Imprimir estado de cuenta'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final b in balances.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _importe(
                  'Cobros publicados',
                  b.value.cobrado,
                  b.key,
                  const Color(0xFF1D4DE2),
                ),
                _importe(
                  'Recibido del equipo',
                  b.value.recibido,
                  b.key,
                  const Color(0xFF166534),
                ),
                _importe(
                  'Saldo pendiente',
                  b.value.saldo,
                  b.key,
                  const Color(0xFFBE1176),
                ),
                _importe(
                  'Entregado al árbitro',
                  b.value.arbitros,
                  b.key,
                  const Color(0xFF925900),
                ),
              ],
            ),
          ),
        const Text(
          'El saldo incluye todos los pagos de los partidos seleccionados. Un saldo negativo es crédito a favor. Las entregas al árbitro se registran aparte y no reducen nuevamente la deuda del equipo.',
        ),
        const SizedBox(height: 14),
        if (partidos.isEmpty)
          const Text(
            'No hay cobros publicados para esta selección. Se publican desde Planilla → Tesorería de cada equipo.',
          ),
        for (final p in partidos) _partido(p, datos['puede_editar'] == true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tesorería · Estados de cuenta'),
      actions: [
        IconButton(
          onPressed: _ocupado
              ? null
              : () {
                  _cargar();
                  setState(() {
                    _catalogo = _leerCatalogo();
                  });
                },
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _catalogo,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo abrir tesorería. Verifica que su módulo esté instalado en Supabase.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _catalogo = _leerCatalogo();
                  }),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        final catalogo = snapshot.data!;
        final grupos = <String, List<Map<String, dynamic>>>{};
        for (final c in List<Map<String, dynamic>>.from(
          catalogo['campeonatos'] as List,
        )) {
          grupos.putIfAbsent('${c['grupo_campeonato_id']}', () => []).add(c);
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'LigaMaster SaaS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4351BF),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('tesoreria-campeonato'),
                        initialValue: _grupoCampeonato,
                        isExpanded: true,
                        decoration: _decoracionFiltro(
                          'Campeonato',
                          const Color(0xFF166534),
                          Icons.emoji_events_outlined,
                        ),
                        items: [
                          for (final grupo in grupos.entries)
                            DropdownMenuItem(
                              value: grupo.key,
                              child: Text(
                                '${grupo.value.first['nombre']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _ocupado
                            ? null
                            : (valor) {
                                _grupoCampeonato = valor;
                                _campeonato = null;
                                _cargar();
                              },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('tesoreria-categoria-$_grupoCampeonato'),
                        initialValue: _campeonato,
                        isExpanded: true,
                        decoration: _decoracionFiltro(
                          'Categoría',
                          const Color(0xFFBE1176),
                          Icons.category_outlined,
                        ),
                        items: [
                          for (final c
                              in grupos[_grupoCampeonato] ??
                                  <Map<String, dynamic>>[])
                            DropdownMenuItem(
                              value: '${c['id']}',
                              child: Text(
                                '${c['categoria']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _ocupado || _grupoCampeonato == null
                            ? null
                            : (valor) {
                                _campeonato = valor;
                                _cargar();
                              },
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<int>(
                        initialValue: _equipo,
                        isExpanded: true,
                        decoration: _decoracionFiltro(
                          'Equipo',
                          const Color(0xFF1D4DE2),
                          Icons.groups_outlined,
                        ),
                        items: [
                          for (final e in catalogo['equipos'] as List)
                            DropdownMenuItem(
                              value: (e['id'] as num).toInt(),
                              child: Text('${e['nombre']}'),
                            ),
                        ],
                        onChanged: _ocupado
                            ? null
                            : (valor) {
                                _equipo = valor;
                                _cargar();
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_estado == null)
                  const Text(
                    'Selecciona campeonato, categoría y equipo para consultar sus aportes.',
                  ),
                if (_estado != null)
                  FutureBuilder<Map<String, dynamic>>(
                    future: _estado,
                    builder: (context, estado) {
                      if (estado.connectionState != ConnectionState.done)
                        return const Center(child: CircularProgressIndicator());
                      if (estado.hasError)
                        return Text(
                          estado.error is PostgrestException
                              ? (estado.error as PostgrestException).message
                              : 'No se pudo cargar el estado de cuenta. Pulsa Actualizar.',
                        );
                      return _informe(estado.data!);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
