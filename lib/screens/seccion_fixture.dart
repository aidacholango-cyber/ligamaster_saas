import 'package:flutter/material.dart';

class SeccionFixture extends StatelessWidget {
  const SeccionFixture({super.key});

  @override
  Widget build(BuildContext context) {
    // Listado estructurado con la programación de los próximos encuentros
    final List<Map<String, dynamic>> proximosPartidos = [
      {
        'jornada': 'JORNADA 2',
        'fecha': 'Sábado, 18 de Julio',
        'hora': '14:00 PM',
        'cancha': 'Cancha Principal - El Rosario',
        'equipoA': 'San Lorenzo',
        'equipoB': 'Boca Juniors',
      },
      {
        'jornada': 'JORNADA 2',
        'fecha': 'Sábado, 18 de Julio',
        'hora': '16:00 PM',
        'cancha': 'Cancha Alterna N° 1',
        'equipoA': 'River Plate',
        'equipoB': 'La Masía FC',
      },
      {
        'jornada': 'JORNADA 2',
        'fecha': 'Domingo, 19 de Julio',
        'hora': '10:00 AM',
        'cancha': 'Cancha Principal - El Rosario',
        'equipoA': 'Deportivo Cali',
        'equipoB': 'Rosario Central',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: proximosPartidos.length,
        itemBuilder: (context, index) {
          final partido = proximosPartidos[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera de la tarjeta: Jornada y Fecha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1A3160),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          partido['jornada'],
                          style: const TextStyle(
                            color: Color(0xFF1A3160),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        partido['fecha'],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1),

                  // Cuerpo central: Enfrentamiento de equipos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          partido['equipoA'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          partido['equipoB'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1),

                  // Pie de la tarjeta: Hora y Ubicación
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        partido['hora'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          partido['cancha'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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
