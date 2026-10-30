import 'package:flutter/material.dart';

/// Vidrio decorativo: ocupa el fondo sin interceptar los controles del acceso.
class FondoVidrioInicio extends StatelessWidget {
  const FondoVidrioInicio({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(child: CustomPaint(painter: _VidrioPainter())),
    ),
  );
}

class _VidrioPainter extends CustomPainter {
  const _VidrioPainter();

  static const _azul = Color(0xFF4351BF);
  static const _verde = Color(0xFF166534);
  static const _magenta = Color(0xFFBC1676);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    Offset punto(double x, double y) => Offset(x * size.width, y * size.height);

    // Las facetas llegan a los bordes; el panel opaco se dibuja por encima.
    final puntos = <Offset>[
      punto(0, 0),
      punto(.26, 0),
      punto(.65, 0),
      punto(1, 0),
      punto(0, .34),
      punto(.18, .22),
      punto(.48, .12),
      punto(.79, .28),
      punto(1, .42),
      punto(0, .75),
      punto(.23, .61),
      punto(.54, .52),
      punto(.86, .68),
      punto(1, .83),
      punto(0, 1),
      punto(.36, 1),
      punto(.72, 1),
      punto(1, 1),
    ];
    const facetas = <List<int>>[
      [0, 1, 5],
      [0, 5, 4],
      [1, 6, 5],
      [1, 2, 6],
      [2, 7, 6],
      [2, 3, 7],
      [3, 8, 7],
      [4, 5, 10],
      [4, 10, 9],
      [5, 6, 11],
      [5, 11, 10],
      [6, 7, 11],
      [7, 12, 11],
      [7, 8, 12],
      [8, 13, 12],
      [9, 10, 14],
      [10, 15, 14],
      [10, 11, 15],
      [11, 16, 15],
      [11, 12, 16],
      [12, 17, 16],
      [12, 13, 17],
    ];
    const colores = [_azul, _verde, _magenta];
    for (var i = 0; i < facetas.length; i++) {
      final vertices = facetas[i].map((j) => puntos[j]).toList();
      final forma = Path()..addPolygon(vertices, true);
      final color = colores[i % colores.length];
      canvas.drawPath(
        forma,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .48),
              color.withValues(alpha: .035),
              color.withValues(alpha: .09),
            ],
          ).createShader(forma.getBounds()),
      );
    }

    // Bordes dobles finos dan reflejo y profundidad sin oscurecer la pantalla.
    final aristas = <String>{};
    for (final faceta in facetas) {
      for (var n = 0; n < 3; n++) {
        final a = faceta[n], b = faceta[(n + 1) % 3];
        final clave = a < b ? '$a:$b' : '$b:$a';
        if (!aristas.add(clave)) continue;
        canvas.drawLine(
          puntos[a],
          puntos[b],
          Paint()
            ..color = _azul.withValues(alpha: .16)
            ..strokeWidth = 1.1,
        );
        canvas.drawLine(
          puntos[a] + const Offset(1.2, 1.2),
          puntos[b] + const Offset(1.2, 1.2),
          Paint()
            ..color = Colors.white.withValues(alpha: .9)
            ..strokeWidth = 1.6,
        );
      }
    }

    // Algunas grietas quebradas y destellos mantienen el aspecto de vidrio roto.
    final grietas = <List<Offset>>[
      [punto(0, .1), punto(.06, .15), punto(.1, .13), puntos[5]],
      [puntos[7], punto(.88, .17), punto(.9, .08), punto(.97, 0)],
      [punto(0, .91), punto(.08, .86), punto(.11, .88), puntos[10]],
      [puntos[12], punto(.93, .72), punto(.95, .69), punto(1, .73)],
    ];
    for (var i = 0; i < grietas.length; i++) {
      final linea = Path()..addPolygon(grietas[i], false);
      canvas.drawPath(
        linea,
        Paint()
          ..color = colores[i % 3].withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
    for (final indice in [5, 7, 10, 12]) {
      final centro = puntos[indice];
      final brillo = Paint()
        ..color = Colors.white.withValues(alpha: .95)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        centro - const Offset(7, 0),
        centro + const Offset(7, 0),
        brillo,
      );
      canvas.drawLine(
        centro - const Offset(0, 7),
        centro + const Offset(0, 7),
        brillo,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VidrioPainter oldDelegate) => false;
}
