import 'package:flutter/material.dart';
import 'pantalla_fixture.dart';
import 'pantalla_posiciones.dart';
import 'pantalla_goleadores.dart';
import 'pantalla_sanciones.dart';
import 'pantalla_consulta_deportiva.dart';

class AccesosCampeonato extends StatelessWidget {
  final Map<String, dynamic> campeonato;
  final bool delegado;
  final bool habilitado;
  const AccesosCampeonato({
    super.key,
    required this.campeonato,
    this.delegado = false,
    this.habilitado = true,
  });

  void _abrir(BuildContext context, String seccion, String titulo) {
    final Widget pantalla;
    if (seccion == 'sanciones') {
      pantalla = PantallaSanciones(campeonato: campeonato);
    } else if (delegado) {
      pantalla = PantallaConsultaDeportiva(
        campeonato: campeonato,
        seccion: seccion,
        titulo: titulo,
      );
    } else if (seccion == 'fixture') {
      pantalla = PantallaFixture(campeonato: campeonato);
    } else if (seccion == 'posiciones') {
      pantalla = PantallaPosiciones(campeonato: campeonato);
    } else {
      pantalla = PantallaGoleadores(campeonato: campeonato);
    }
    final tema = Theme.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(data: tema, child: pantalla),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget boton(String seccion, String titulo, IconData icono, Color color) {
      return ElevatedButton.icon(
        onPressed: habilitado ? () => _abrir(context, seccion, titulo) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(132, 44),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icono, size: 19),
        label: Text(titulo),
      );
    }

    // Conserva la misma fila en móvil mediante desplazamiento horizontal.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              boton(
                'fixture',
                'Fixture',
                Icons.calendar_month_outlined,
                const Color(0xFF166534),
              ),
              const SizedBox(width: 8),
              boton(
                'posiciones',
                'Posiciones',
                Icons.leaderboard_outlined,
                const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 8),
              boton(
                'goleadores',
                'Goleadores',
                Icons.sports_soccer,
                const Color(0xFF925800),
              ),
              const SizedBox(width: 8),
              boton(
                'sanciones',
                'Sanciones',
                Icons.gavel_outlined,
                const Color(0xFFB42318),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
