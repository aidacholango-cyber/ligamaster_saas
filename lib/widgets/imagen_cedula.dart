import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/ruta_cedula.dart';

/// Lee documentos con la sesión autenticada. Nunca utiliza enlaces públicos
/// para descargar cédulas, incluso si se omiten parámetros al iniciar Flutter.
class ImagenCedula extends StatefulWidget {
  final String referencia;
  final BoxFit fit;
  const ImagenCedula({
    super.key,
    required this.referencia,
    this.fit = BoxFit.contain,
  });

  @override
  State<ImagenCedula> createState() => _ImagenCedulaState();
}

class _ImagenCedulaState extends State<ImagenCedula> {
  StreamSubscription<AuthState>? _sesion;
  Future<Uint8List>? _descarga;
  String? _usuario;
  Uint8List? _bytes;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    _sesion = Supabase.instance.client.auth.onAuthStateChange.listen((estado) {
      if (!mounted) return;
      if (_usuario != estado.session?.user.id) setState(_cargar);
    });
  }

  void _cargar() {
    _descartarImagen();
    _revision++;
    _descarga = null;
    final db = Supabase.instance.client;
    _usuario = db.auth.currentSession?.user.id;
    if (_usuario == null) return;
    try {
      final bucket = db.storage.from('cedulas_jugadores');
      final ruta = rutaCedula(widget.referencia, bucket.getPublicUrl(''));
      final revision = _revision;
      _descarga = bucket
          .download(ruta)
          .timeout(const Duration(seconds: 20))
          .then((bytes) {
            if (mounted && revision == _revision) _bytes = bytes;
            return bytes;
          });
    } on FormatException {
      // No mostrar URL, datos del documento ni detalles internos.
    }
  }

  @override
  void didUpdateWidget(covariant ImagenCedula oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referencia != widget.referencia) _cargar();
  }

  @override
  void dispose() {
    _sesion?.cancel();
    _descartarImagen();
    super.dispose();
  }

  void _descartarImagen() {
    final bytes = _bytes;
    _bytes = null;
    if (bytes != null) unawaited(MemoryImage(bytes).evict());
  }

  Widget _error() =>
      const Center(child: Text('Documento no disponible. Verifica tu acceso.'));

  @override
  Widget build(BuildContext context) {
    if (_usuario == null) return _error();
    if (_descarga == null) return _error();
    return FutureBuilder<Uint8List>(
      key: ValueKey(_revision),
      future: _descarga,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error();
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _error(),
        );
      },
    );
  }
}
