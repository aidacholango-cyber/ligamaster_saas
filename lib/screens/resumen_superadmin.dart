import '../models/resumen_ligas.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only owner summary. RLS remains authoritative for every query.
class ResumenSuperadmin extends StatefulWidget {
  const ResumenSuperadmin({super.key});
  @override
  State<ResumenSuperadmin> createState() => _ResumenSuperadminState();
}

class _ResumenSuperadminState extends State<ResumenSuperadmin> {
  late Future<List<Map<String, dynamic>>> _datos = _leer();

  Future<List<Map<String, dynamic>>> _tabla(String tabla, String campos) async {
    final filas = <Map<String, dynamic>>[];
    var inicio = 0;
    // Also works when the server caps pages below 500 rows.
    while (true) {
      final pagina = await Supabase.instance.client
          .from(tabla)
          .select(campos)
          .order('id')
          .range(inicio, inicio + 499);
      if (pagina.isEmpty) return filas;
      filas.addAll(pagina);
      inicio += pagina.length;
    }
  }

  Future<List<Map<String, dynamic>>> _leer() async {
    final db = Supabase.instance.client;
    if (await db.rpc('lm_es_superadmin') != true) {
      throw StateError('Esta consulta es exclusiva del superadministrador.');
    }
    final ligas = await _tabla('ligas', 'id,nombre');
    final equipos = await _tabla('equipos', 'id,liga_id');
    final jugadores = await _tabla(
      'jugadores',
      'id,equipo_id,cedula,categoria',
    );
    return resumirLigas(ligas, equipos, jugadores);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Jugadores por liga'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => setState(() => _datos = _leer()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _datos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo cargar el resumen. Comprueba tu sesión y conexión.',
                ),
                TextButton(
                  onPressed: () => setState(() => _datos = _leer()),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final filas = snapshot.data ?? [];
        final total = filas.fold<int>(
          0,
          (suma, fila) => suma + (fila['jugadores'] as int),
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Total de jugadores por ligas: $total',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Una misma cédula se cuenta una vez por liga, aunque figure en varias categorías. El detalle por categoría muestra sus fichas registradas. Las fichas sin cédula se cuentan individualmente.',
                ),
                const SizedBox(height: 16),
                if (filas.isEmpty) const Text('No hay ligas registradas.'),
                for (final fila in filas)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fila['nombre']}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${fila['jugadores']} jugadores registrados',
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final categoria
                                  in (fila['categorias'] as Map<String, int>)
                                      .entries)
                                Chip(
                                  label: Text(
                                    '${categoria.key}: ${categoria.value} fichas',
                                  ),
                                ),
                            ],
                          ),
                        ],
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
