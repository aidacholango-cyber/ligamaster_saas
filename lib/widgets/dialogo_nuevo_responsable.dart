import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DialogoNuevoResponsable extends StatefulWidget {
  final String tipo;
  final String? ligaId;
  const DialogoNuevoResponsable({super.key, required this.tipo, this.ligaId});
  @override
  State<DialogoNuevoResponsable> createState() =>
      _DialogoNuevoResponsableState();
}

class _DialogoNuevoResponsableState extends State<DialogoNuevoResponsable> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _responsable = TextEditingController();
  final _cedula = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  Uint8List? _logo;
  String _extension = 'png';
  bool _ocupado = false;
  late bool _existente = !_liga;
  String? _error;
  bool get _liga => widget.tipo == 'liga';
  @override
  void dispose() {
    for (final c in [
      _nombre,
      _responsable,
      _cedula,
      _telefono,
      _correo,
      _clave,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _imagen() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      final ext = f.name.split('.').last.toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(ext))
        throw StateError('Selecciona PNG, JPG o WEBP.');
      final b = await f.readAsBytes();
      if (b.length > 5242880)
        throw StateError('El logo debe pesar como máximo 5 MB.');
      if (mounted)
        setState(() {
          _logo = b;
          _extension = ext == 'jpeg' ? 'jpg' : ext;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'No se pudo cargar la imagen.',
        );
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      String? logoUrl;
      if (_logo != null) {
        final bucket = _liga ? 'escudos_ligas' : 'escudos';
        final path =
            '${db.auth.currentUser!.id}/nuevo_${DateTime.now().microsecondsSinceEpoch}.$_extension';
        await db.storage
            .from(bucket)
            .uploadBinary(
              path,
              _logo!,
              fileOptions: FileOptions(
                contentType:
                    'image/${_extension == 'jpg' ? 'jpeg' : _extension}',
              ),
            );
        logoUrl = db.storage.from(bucket).getPublicUrl(path);
      }
      final datos = {
        'tipo': widget.tipo,
        'liga_id': widget.ligaId,
        'nombre': _nombre.text.trim().toUpperCase(),
        'responsable': _responsable.text.trim().toUpperCase(),
        'cedula': _cedula.text.trim(),
        'telefono': _telefono.text.trim(),
        'correo': _correo.text.trim().toLowerCase(),
        'logo_url': logoUrl,
      };
      dynamic resultado;
      if (_existente && !_liga) {
        resultado = await db.rpc(
          'lm_crear_equipo_cuenta_existente',
          params: {'p_datos': datos},
        );
      } else {
        final response = await db.functions.invoke(
          'lm-crear-responsable',
          body: {...datos, 'clave': _clave.text},
        );
        resultado = response.data;
      }
      if (resultado is! Map || resultado['ok'] != true) {
        throw StateError(
          'No se confirmó el registro. Actualiza la lista antes de reintentar.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          if (e is FunctionException) {
            final d = e.details;
            _error = d is Map
                ? (d['error']?.toString() ?? 'No se pudo crear la cuenta.')
                : 'No se pudo ejecutar el registro. Comprueba que lm-crear-responsable esté desplegada.';
          } else if (e is PostgrestException) {
            _error = e.message;
          } else if (e is StateError) {
            _error = e.message.toString();
          } else {
            _error =
                'No se pudo completar el registro. Comprueba tu conexión y actualiza la lista antes de reintentar.';
          }
        });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _campo(
    TextEditingController c,
    String texto, {
    bool clave = false,
    TextInputType? teclado,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !_ocupado,
      obscureText: clave,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText: texto,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Completa este campo.';
        if (clave && v.length < 12) return 'Usa al menos 12 caracteres.';
        if (c == _correo &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
          return 'Ingresa un correo válido.';
        if (c == _cedula && !RegExp(r'^\d{10}$').hasMatch(v.trim()))
          return 'La cédula debe tener 10 dígitos.';
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      backgroundColor: const Color(0xFFF8F6FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF4351BF),
                child: Icon(Icons.sports_soccer, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LigaMaster SaaS',
                  style: TextStyle(
                    color: Color(0xFF4351BF),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(_liga ? 'Registrar Nueva Liga' : 'Registrar Nuevo Equipo'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF4351BF),
                  backgroundImage: _logo == null ? null : MemoryImage(_logo!),
                  child: _logo == null
                      ? const Icon(Icons.sports_soccer, color: Colors.white)
                      : null,
                ),
                TextButton(
                  onPressed: _ocupado ? null : _imagen,
                  child: const Text('Seleccionar logo'),
                ),
                _campo(
                  _nombre,
                  _liga ? 'Nombre de la liga' : 'Nombre del equipo',
                ),
                _campo(
                  _responsable,
                  _liga
                      ? 'Nombre del nuevo administrador'
                      : 'Nombre del nuevo delegado / presidente',
                ),
                _campo(_cedula, 'Cédula', teclado: TextInputType.number),
                _campo(_telefono, 'Teléfono', teclado: TextInputType.phone),
                _campo(
                  _correo,
                  _existente
                      ? 'Correo electronico'
                      : 'Correo de la nueva cuenta',
                  teclado: TextInputType.emailAddress,
                ),
                if (!_existente)
                  _campo(_clave, 'Contraseña de la nueva cuenta', clave: true)
                else
                  const Padding(padding: EdgeInsets.only(bottom: 12)),
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
        ElevatedButton(
          onPressed: _ocupado ? null : _guardar,
          child: Text(
            _ocupado
                ? 'Creando…'
                : _liga
                ? 'Crear liga y administrador'
                : 'Crear equipo',
          ),
        ),
      ],
    ),
  );
}
