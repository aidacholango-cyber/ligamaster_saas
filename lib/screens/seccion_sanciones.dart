import 'package:flutter/material.dart';

class SeccionSanciones extends StatelessWidget {
  const SeccionSanciones({super.key});

  @override
  Widget build(BuildContext context) {
    // Listado simulado del reporte disciplinario de la liga
    final List<Map<String, dynamic>> reporteSanciones = [
      {
        'jugador': 'Carlos Mendoza',
        'equipo': 'Rosario Central',
        'tarjetasAmarillas': 3,
        'tarjetasRojas': 0,
        'estado': 'Amonestado',
        'detalle': 'Acumulación de 3 amarillas (Próxima genera suspensión).',
      },
      {
        'jugador': 'Luis Fernando Ruiz',
        'equipo': 'La Masía FC',
        'tarjetasAmarillas': 1,
        'tarjetasRojas': 1,
        'estado': 'Suspendido',
        'detalle':
            'Expulsión directa por juego brusco grave. 1 Fecha de suspensión.',
      },
      {
        'jugador': 'Andrés Villa',
        'equipo': 'San Lorenzo',
        'tarjetasAmarillas': 0,
        'tarjetasRojas': 1,
        'estado': 'Suspendido',
        'detalle':
            'Doble amonestación en el último encuentro. Suspende esta fecha.',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: reporteSanciones.length,
        itemBuilder: (context, index) {
          final sancion = reporteSanciones[index];
          final bool esSuspendido = sancion['estado'] == 'Suspendido';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: esSuspendido
                    ? Colors.red[100]
                    : Colors.amber[100],
                child: Icon(
                  Icons.gavel_rounded,
                  color: esSuspendido ? Colors.red[800] : Colors.amber[800],
                  size: 20,
                ),
              ),
              title: Text(
                sancion['jugador'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                sancion['equipo'],
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: esSuspendido ? Colors.red[800] : Colors.amber[700],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sancion['estado'].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              // Detalles extras que aparecen al presionar la tarjeta
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildBadgeTarjeta(
                            Colors.amber,
                            '${sancion['tarjetasAmarillas']} Amarillas',
                          ),
                          const SizedBox(width: 8),
                          _buildBadgeTarjeta(
                            Colors.red,
                            '${sancion['tarjetasRojas']} Rojas',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        sancion['detalle'],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget auxiliar corregido para crear las etiquetas de las tarjetas dentro del detalle
  Widget _buildBadgeTarjeta(Color colorBase, String texto) {
    // Definimos un color de texto oscuro según el color base para que contraste bien
    final Color colorTexto = colorBase == Colors.amber
        ? const Color(0xFF7F5F00)
        : const Color(0xFFB71C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorBase.withAlpha(
          38,
        ), // Reemplaza con éxito withOpacity sin dar advertencias
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorBase, width: 1),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: colorTexto,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
