import 'package:flutter/material.dart';

typedef TrazosFirma = List<List<Offset>>;

TrazosFirma leerFirma(dynamic datos) {
  if (datos is! List) return [];
  return [
    for (final trazo in datos)
      if (trazo is List)
        [
          for (final p in trazo)
            if (p is List && p.length == 2 && p[0] is num && p[1] is num)
              Offset(
                (p[0] as num).toDouble().clamp(0, 1),
                (p[1] as num).toDouble().clamp(0, 1),
              ),
        ],
  ].where((trazo) => trazo.isNotEmpty).toList();
}

List<List<List<double>>> guardarFirma(TrazosFirma trazos) => [
  for (final trazo in trazos)
    [
      for (final p in trazo) [p.dx, p.dy],
    ],
];

class FirmaDedo extends StatefulWidget {
  const FirmaDedo({
    super.key,
    required this.titulo,
    required this.trazos,
    required this.onChanged,
    this.alDibujar,
  });
  final String titulo;
  final TrazosFirma trazos;
  final ValueChanged<TrazosFirma>? onChanged;
  final ValueChanged<bool>? alDibujar;
  @override
  State<FirmaDedo> createState() => _FirmaDedoState();
}

class _FirmaDedoState extends State<FirmaDedo> {
  List<Offset> _trazo = [];
  Offset _punto(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
  void _terminar() {
    if (_trazo.isNotEmpty) {
      widget.onChanged?.call([...widget.trazos, List<Offset>.from(_trazo)]);
    }
    setState(() => _trazo = []);
    widget.alDibujar?.call(false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF166534),
          ),
        ),
      ),
      Container(
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF7DB393)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final editable = widget.onChanged != null;
            return Semantics(
              label: 'Área de ${widget.titulo}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: !editable
                    ? null
                    : (_) => widget.alDibujar?.call(true),
                onPanStart: !editable
                    ? null
                    : (d) => setState(
                        () => _trazo = [_punto(d.localPosition, size)],
                      ),
                onPanUpdate: !editable
                    ? null
                    : (d) => setState(() {
                        if (_trazo.length < 2000) {
                          _trazo = [..._trazo, _punto(d.localPosition, size)];
                        }
                      }),
                onPanEnd: !editable ? null : (_) => _terminar(),
                onPanCancel: !editable
                    ? null
                    : () {
                        setState(() => _trazo = []);
                        widget.alDibujar?.call(false);
                      },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _FirmaPainter([
                        ...widget.trazos,
                        if (_trazo.isNotEmpty) _trazo,
                      ]),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: widget.onChanged == null || widget.trazos.isEmpty
              ? null
              : () => widget.onChanged!([]),
          icon: const Icon(Icons.cleaning_services_outlined, size: 16),
          label: const Text('Limpiar firma'),
        ),
      ),
    ],
  );
}

class _FirmaPainter extends CustomPainter {
  _FirmaPainter(this.trazos);
  final TrazosFirma trazos;
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final trazo in trazos) {
      if (trazo.isEmpty) continue;
      final path = Path()
        ..moveTo(trazo.first.dx * size.width, trazo.first.dy * size.height);
      for (final punto in trazo.skip(1)) {
        path.lineTo(punto.dx * size.width, punto.dy * size.height);
      }
      if (trazo.length == 1) {
        canvas.drawCircle(
          Offset(trazo.first.dx * size.width, trazo.first.dy * size.height),
          1.1,
          Paint()..color = Colors.black,
        );
      } else {
        canvas.drawPath(path, pintura);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter oldDelegate) => true;
}
