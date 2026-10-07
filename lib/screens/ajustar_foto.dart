import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Recorta la imagen con el mismo encuadre que se muestra al usuario.
Future<Uint8List?> ajustarFoto(
  BuildContext context,
  Uint8List bytes,
  String titulo,
) async {
  // En web, ImageDescriptor.encoded no permite consultar width/height.
  // El codec decodifica primero; ui.Image sí dispone de ambas dimensiones.
  final codec = await ui.instantiateImageCodec(bytes);
  late final ui.FrameInfo frame;
  try {
    frame = await codec.getNextFrame();
  } finally {
    codec.dispose();
  }
  try {
    if (!context.mounted) return null;
    final ruta = DialogRoute<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Encuadre(imagen: frame.image, titulo: titulo),
    );
    final resultado = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(ruta);
    await ruta.completed;
    return resultado;
  } finally {
    frame.image.dispose();
  }
}

class _Encuadre extends StatefulWidget {
  final ui.Image imagen;
  final String titulo;
  const _Encuadre({required this.imagen, required this.titulo});
  @override
  State<_Encuadre> createState() => _EncuadreState();
}

class _EncuadreState extends State<_Encuadre> {
  double _zoom = 1, _inicioZoom = 1;
  Offset? _centro;
  Offset _ancla = Offset.zero;
  bool _guardando = false;
  String? _error;
  static const _aspecto = 1.8;

  Rect _recorte() {
    final imagen = widget.imagen;
    final ancho =
        math.max(imagen.width.toDouble(), imagen.height * _aspecto) / _zoom;
    final alto = ancho / _aspecto;
    final centro = _centro ?? Offset(imagen.width / 2, imagen.height / 2);
    final x = centro.dx
        .clamp(
          math.min(ancho / 2, imagen.width - ancho / 2),
          math.max(ancho / 2, imagen.width - ancho / 2),
        )
        .toDouble();
    final y = centro.dy
        .clamp(
          math.min(alto / 2, imagen.height - alto / 2),
          math.max(alto / 2, imagen.height - alto / 2),
        )
        .toDouble();
    return Rect.fromCenter(center: Offset(x, y), width: ancho, height: alto);
  }

  Future<void> _aplicar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _FotoPainter(
        widget.imagen,
        _recorte(),
      ).paint(canvas, const Size(1080, 600));
      final picture = recorder.endRecording();
      final imagen = await picture.toImage(1080, 600);
      picture.dispose();
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (datos == null) throw StateError('No se pudo preparar la imagen.');
      final bytes = datos.buffer.asUint8List(
        datos.offsetInBytes,
        datos.lengthInBytes,
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted)
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar el encuadre. Intenta nuevamente.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: Text('Ajustar ${widget.titulo.toLowerCase()}'),
      content: SizedBox(
        width: 560,
        height: math.min(500.0, MediaQuery.sizeOf(context).height * 0.60),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.titulo.startsWith('Cédula')
                    ? 'Ajusta el tamaño y mueve la imagen para que se vea toda la cédula.'
                    : 'Ajusta el tamaño y mueve la foto para mostrar desde la frente hasta el cuello.',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, medidas) => AspectRatio(
                  aspectRatio: _aspecto,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onScaleStart: _guardando
                          ? null
                          : (d) {
                              _inicioZoom = _zoom;
                              final r = _recorte();
                              _ancla =
                                  r.topLeft +
                                  d.localFocalPoint *
                                      (r.width / medidas.maxWidth);
                            },
                      onScaleUpdate: _guardando
                          ? null
                          : (d) => setState(() {
                              _zoom = (_inicioZoom * d.scale)
                                  .clamp(0.25, 4.0)
                                  .toDouble();
                              final r = _recorte();
                              _centro =
                                  _ancla -
                                  d.localFocalPoint *
                                      (r.width / medidas.maxWidth) +
                                  Offset(r.width / 2, r.height / 2);
                              _centro = _recorte().center;
                            }),
                      child: CustomPaint(
                        painter: _FotoPainter(widget.imagen, _recorte()),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.zoom_out),
                  Expanded(
                    child: Slider(
                      value: ((math.log(_zoom) / math.log(4) + 1) / 2).clamp(
                        0.0,
                        1.0,
                      ),
                      min: 0,
                      max: 1,
                      label: '${_zoom.toStringAsFixed(1)}×',
                      onChanged: _guardando
                          ? null
                          : (v) => setState(() {
                              _centro = _recorte().center;
                              _zoom = math.pow(4, 2 * v - 1).toDouble();
                              _centro = _recorte().center;
                            }),
                    ),
                  ),
                  const Icon(Icons.zoom_in),
                ],
              ),
              TextButton(
                onPressed: _guardando
                    ? null
                    : () => setState(() {
                        _zoom = 1;
                        _centro = null;
                      }),
                child: const Text('Centrar imagen'),
              ),
              if (widget.titulo.startsWith('Cédula'))
                const Text(
                  'Comprueba que los datos de la cédula queden visibles antes de aplicar.',
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _aplicar,
          child: Text(_guardando ? 'Preparando…' : 'Aplicar'),
        ),
      ],
    ),
  );
}

class _FotoPainter extends CustomPainter {
  final ui.Image imagen;
  final Rect recorte;
  _FotoPainter(this.imagen, this.recorte);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final escala = size.width / recorte.width;
    canvas.scale(escala);
    canvas.translate(-recorte.left, -recorte.top);
    canvas.drawImage(
      imagen,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FotoPainter oldDelegate) =>
      oldDelegate.imagen != imagen || oldDelegate.recorte != recorte;
}
