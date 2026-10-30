import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaRevisionSanciones extends StatefulWidget {
  const PantallaRevisionSanciones({super.key, required this.partidoId});
  final String partidoId;
  @override
  State<PantallaRevisionSanciones> createState() =>
      _PantallaRevisionSancionesState();
}

class _PantallaRevisionSancionesState extends State<PantallaRevisionSanciones> {
  final _observaciones = TextEditingController();
  Map<String, dynamic>? _datos;
  List<Map<String, dynamic>> _jugadores = [];
  String? _error;
  bool _cargando = true, _guardando = false, _sucio = false;
  @override
  void initState() {
    super.initState();
    _leer();
  }

  @override
  void dispose() {
    _observaciones.dispose();
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
          'lm_penas_revision_leer',
          params: {'p_partido_id': widget.partidoId},
        ),
      );
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _observaciones.text = '${datos['observaciones'] ?? ''}';
        _jugadores = [
          for (final j in datos['jugadores']) Map<String, dynamic>.from(j),
        ];
        _sucio = false;
      });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo cargar la revisión.',
        );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar(bool enviar) async {
    if (_guardando || _datos == null) return;
    if (_observaciones.text.trim().isEmpty) {
      setState(
        () => _error = 'Escribe el motivo o las observaciones de la revisión.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'lm_penas_revision_guardar',
        params: {
          'p_partido_id': widget.partidoId,
          'p_revision': _datos!['revision'],
          'p_origen': _datos!['origen'],
          'p_observaciones': _observaciones.text.trim(),
          'p_enviar': enviar,
          'p_correcciones': [
            for (final j in _jugadores)
              if (j['manual'] == true)
                {
                  'id': j['id'],
                  'ta': j['ta'],
                  'tr': j['tr'],
                  'suspension_manual': j['suspension_manual'],
                },
          ],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enviar
                ? 'Revisión enviada a Tesorería, sin importes.'
                : 'Revisión guardada.',
          ),
        ),
      );
      await _leer();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudo guardar. Vuelve a intentar.',
        );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _cambiar(VoidCallback cambio) => setState(() {
    cambio();
    _sucio = true;
  });
  Future<void> _suspension(Map<String, dynamic> j) async {
    final texto = TextEditingController(
      text: '${j['suspension_manual'] ?? ''}',
    );
    final valor = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, cambiar) {
          final numero = int.tryParse(texto.text);
          return AlertDialog(
            title: const Text('Suspensión de este partido'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Indica el total de partidos de suspensión que genera este encuentro para el jugador. Reemplaza el cálculo automático de este encuentro.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: texto,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Partidos de suspensión (0–100)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => cambiar(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, -1),
                child: const Text('Usar automático'),
              ),
              FilledButton(
                onPressed: numero == null || numero < 0 || numero > 100
                    ? null
                    : () => Navigator.pop(ctx, numero),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    // El diálogo termina su animación antes de liberar el controlador.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    texto.dispose();
    if (valor != null && mounted)
      _cambiar(() => j['suspension_manual'] = valor == -1 ? null : valor);
  }

  Widget _jugador(Map<String, dynamic> j) => Card(
    color: const Color(0xFFF1F7F3),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${j['nombre']} · N.º ${j['camiseta'] ?? '—'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF166534),
            ),
          ),
          Text(
            '${j['equipo']} · Hoja original: T.A. ${j['ta_original']} · T.R. ${j['tr_original'] == true ? 'Sí' : 'No'}',
            style: const TextStyle(fontSize: 12),
          ),
          if (j['participo'] != true)
            const Text(
              'No figura como participante en la planilla.',
              style: TextStyle(fontSize: 12),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Corrección manual'),
            value: j['manual'] == true,
            onChanged: _guardando
                ? null
                : (v) => _cambiar(() {
                    j['manual'] = v;
                    if (!v) {
                      j['ta'] = j['ta_original'];
                      j['tr'] = j['tr_original'];
                      j['suspension_manual'] = null;
                    }
                  }),
          ),
          if (j['manual'] == true)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 105,
                  child: DropdownButtonFormField<int>(
                    initialValue: (j['ta'] as num).toInt(),
                    decoration: const InputDecoration(
                      labelText: 'T.A.',
                      filled: true,
                      fillColor: Color(0xFFFFF2CF),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var n = 0; n <= 2; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: _guardando
                        ? null
                        : (v) => _cambiar(() => j['ta'] = v),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('T.R. directa'),
                    value: j['tr'] == true,
                    onChanged: _guardando
                        ? null
                        : (v) => _cambiar(() => j['tr'] = v),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _guardando ? null : () => _suspension(j),
                  icon: const Icon(Icons.gavel, color: Color(0xFFBC1676)),
                  label: Text(
                    j['suspension_manual'] == null
                        ? 'Suspensión automática'
                        : 'Suspensión: ${j['suspension_manual']} partidos',
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sucio && !_guardando,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _guardando) return;
      final salir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text('¿Descartar los cambios de esta revisión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (salir == true && mounted) {
        setState(() => _sucio = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Revisar tarjetas y suspensiones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'La hoja original se conserva. Las correcciones se aplican al resumen de sanciones. Tesorería asigna los valores.',
                        textAlign: TextAlign.center,
                      ),
                      if (_datos?['desactualizada'] == true)
                        const Text(
                          'La hoja cambió después de la revisión anterior. Revisa nuevamente todos los datos.',
                          style: TextStyle(color: Color(0xFFB42318)),
                        ),
                      if (_datos?['envio'] != null)
                        Text(
                          'Último envío a Tesorería: revisión ${_datos!['envio']['revision']}',
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (_datos == null)
                        TextButton(
                          onPressed: _leer,
                          child: const Text('Reintentar'),
                        ),
                      for (final j in _jugadores) _jugador(j),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _observaciones,
                        enabled: !_guardando,
                        maxLength: 4000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo u observaciones',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _cambiar(() {}),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: _guardando || _datos == null
                                ? null
                                : () => _guardar(false),
                            child: const Text('Guardar revisión'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFBC1676),
                            ),
                            onPressed: _guardando || _datos == null
                                ? null
                                : () => _guardar(true),
                            icon: const Icon(Icons.send_outlined),
                            label: Text(
                              _guardando ? 'Guardando…' : 'Enviar a Tesorería',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
