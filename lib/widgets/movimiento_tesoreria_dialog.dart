import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cobro_manual.dart';
import '../models/estado_cuenta.dart';

String _nuevoId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class MovimientoTesoreriaDialog extends StatefulWidget {
  const MovimientoTesoreriaDialog({
    super.key,
    required this.ligaId,
    required this.equipoId,
    required this.partido,
    this.tipoInicial = 'aporte_equipo',
  });
  final String ligaId;
  final int equipoId;
  final Map<String, dynamic> partido;
  final String tipoInicial;
  @override
  State<MovimientoTesoreriaDialog> createState() =>
      MovimientoTesoreriaDialogState();
}

class MovimientoTesoreriaDialogState extends State<MovimientoTesoreriaDialog> {
  final _form = GlobalKey<FormState>();
  final _monto = TextEditingController(),
      _referencia = TextEditingController(),
      _arbitro = TextEditingController();
  final _id = _nuevoId();
  late String _tipo;
  DateTime _fecha = DateTime.now();
  Uint8List? _imagen;
  String? _mime, _extension, _ruta, _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
  }

  @override
  void dispose() {
    _monto.dispose();
    _referencia.dispose();
    _arbitro.dispose();
    super.dispose();
  }

  Future<void> _adjuntar() async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024)
        throw StateError('El comprobante debe pesar como máximo 5 MB.');
      String? mime, extension;
      if (bytes.length > 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        mime = 'image/png';
        extension = 'png';
      } else if (bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        mime = 'image/jpeg';
        extension = 'jpg';
      } else if (bytes.length > 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        mime = 'image/webp';
        extension = 'webp';
      }
      if (mime == null)
        throw StateError('Selecciona una imagen PNG, JPG o WebP.');
      if (mounted)
        setState(() {
          _imagen = bytes;
          _mime = mime;
          _extension = extension;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is StateError
              ? '${e.message}'
              : 'No se pudo abrir la imagen.',
        );
    }
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      if (_imagen != null && _ruta == null) {
        final ruta =
            '${widget.ligaId}/${widget.partido['partido_id']}/${widget.equipoId}/$_id/comprobante.$_extension';
        try {
          await db.storage
              .from('tesoreria_comprobantes')
              .uploadBinary(
                ruta,
                _imagen!,
                fileOptions: FileOptions(contentType: _mime),
              );
        } on StorageException catch (e) {
          if (e.statusCode != '409') rethrow;
        }
        _ruta = ruta;
      }
      await db.rpc(
        'lm_tesoreria_registrar_movimiento',
        params: {
          'p_id': _id,
          'p_partido_id': widget.partido['partido_id'],
          'p_equipo_id': widget.equipoId,
          'p_tipo': _tipo,
          'p_moneda': (widget.partido['cobro'] as Map)['moneda'],
          'p_centavos': leerCentavos(_monto.text),
          'p_fecha':
              '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
          'p_referencia': _referencia.text.trim(),
          'p_beneficiario': _tipo == 'pago_arbitro' ? _arbitro.text.trim() : '',
          'p_comprobante': _ruta,
        },
      );
      if (mounted) {
        setState(() => _guardando = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _guardando = false;
          _error = e is PostgrestException
              ? e.message
              : 'No se pudo guardar. Puedes reintentar; no se duplicará el pago.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: const Text('Registrar movimiento'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Movimiento'),
                  items: const [
                    DropdownMenuItem(
                      value: 'aporte_equipo',
                      child: Text('Pago recibido del equipo'),
                    ),
                    DropdownMenuItem(
                      value: 'pago_arbitro',
                      child: Text('Dinero entregado al árbitro'),
                    ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (v) => setState(() => _tipo = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _monto,
                  enabled: !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Monto · ${(widget.partido['cobro'] as Map)['moneda']}',
                  ),
                  validator: (v) => (leerCentavos(v ?? '') ?? 0) > 0
                      ? null
                      : 'Ingresa un monto mayor que cero, con hasta dos decimales.',
                ),
                const SizedBox(height: 16),
                if (_tipo == 'pago_arbitro') ...[
                  TextFormField(
                    controller: _arbitro,
                    enabled: !_guardando,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del árbitro',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Indica quién recibió el dinero.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _referencia,
                  enabled: !_guardando,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Referencia / número de recibo (opcional)',
                  ),
                ),
                TextButton.icon(
                  onPressed: _guardando
                      ? null
                      : () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fecha,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (fecha != null && mounted)
                            setState(() => _fecha = fecha);
                        },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(fechaTesoreria(_fecha.toIso8601String())),
                ),
                OutlinedButton.icon(
                  onPressed: _guardando || _ruta != null ? null : _adjuntar,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _imagen == null
                        ? 'Adjuntar comprobante (opcional)'
                        : 'Comprobante seleccionado',
                  ),
                ),
                if (_imagen != null)
                  SizedBox(
                    height: 100,
                    child: Image.memory(_imagen!, fit: BoxFit.contain),
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
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar movimiento'),
        ),
      ],
    ),
  );
}
