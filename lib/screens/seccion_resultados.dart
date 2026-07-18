import 'package:flutter/material.dart';

class SeccionResultados extends StatelessWidget {
  const SeccionResultados({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista simulada de resultados de la liga
    final List<Map<String, dynamic>> partidosJugados = [
      {
        'equipoLocal': 'Rosario Central',
        'golesLocal': 3,
        'equipoVisita': 'San Lorenzo',
        'golesVisita': 1,
        'fecha': 'Fecha 1 - Sábado',
        'estado': 'Finalizado',
      },
      {
        'equipoLocal': 'Boca Juniors',
        'golesLocal': 2,
        'equipoVisita': 'River Plate',
        'golesVisita': 2,
        'fecha': 'Fecha 1 - Domingo',
        'estado': 'Finalizado',
      },
      {
        'equipoLocal': 'La Masía FC',
        'golesLocal': 0,
        'equipoVisita': 'Deportivo Cali',
        'golesVisita': 1,
        'fecha': 'Fecha 1 - Domingo',
        'estado': 'Finalizado',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Un fondo gris claro moderno
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: partidosJugados.length,
        itemBuilder: (context, index) {
          final partido = partidosJugados[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // Diseño de la fila del partido
              child: Column(
                children: [
                  Text(
                    partido['fecha'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Equipo Local
                      Expanded(
                        child: Text(
                          partido['equipoLocal'],
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Marcador central
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3160), // Color corporativo
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${partido['golesLocal']} - ${partido['golesVisita']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // Equipo Visita
                      Expanded(
                        child: Text(
                          partido['equipoVisita'],
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      partido['estado'].toUpperCase(),
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
