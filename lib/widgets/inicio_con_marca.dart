import 'package:flutter/material.dart';
import 'fondo_vidrio_inicio.dart';

/// Mantiene el formulario y adapta la ilustración al ancho disponible.
class InicioConMarca extends StatelessWidget {
  const InicioConMarca({super.key, required this.child});
  final Widget child;

  Widget _imagen(double ancho) => SizedBox(
    width: ancho,
    child: Opacity(
      opacity: .86,
      child: Image.asset(
        'assets/images/ligamaster_inicio_vidrio.png',
        fit: BoxFit.contain,
        semanticLabel:
            'LigaMaster SaaS, jugador de fútbol con efecto de vidrio roto',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, espacio) {
      final horizontal = espacio.maxWidth >= 900;
      return Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: FondoVidrioInicio()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: horizontal
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(
                                -((espacio.maxWidth - 900) / 4).clamp(
                                  0.0,
                                  60.0,
                                ),
                                0,
                              ),
                              child: _imagen(480),
                            ),
                          ),
                          const SizedBox(width: 40),
                          SizedBox(width: 420, child: child),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _imagen(240),
                          const SizedBox(height: 16),
                          child,
                        ],
                      ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
