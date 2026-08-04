import 'package:flutter/material.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeccionPosiciones extends StatelessWidget {
  const SeccionPosiciones({super.key});

  // 👇 Consulta los equipos en internet
  Future<List<Map<String, dynamic>>> obtenerEquipos() async {
    try {
      final response = await Supabase.instance.client
          .from('equipos')
          .select()
          .order('puntos', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error al traer los equipos: $error');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: obtenerEquipos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(child: Text('No se encontraron equipos.'));
              }

              final listaDeEquipos = snapshot.data!;

              return DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1A3160),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'EQUIPO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'PTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: listaDeEquipos.map((equipo) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          equipo['nombre'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(equipo['puntos'].toString())),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}
