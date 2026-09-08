import 'package:flutter/material.dart';
import '../services/liga_service.dart';

class PantallaAdminLiga extends StatefulWidget {
  const PantallaAdminLiga({super.key});

  @override
  State<PantallaAdminLiga> createState() => _PantallaAdminLigaState();
}

class _PantallaAdminLigaState extends State<PantallaAdminLiga> {
  final LigaService _ligaService = LigaService();
  final TextEditingController _nombreEquipoController = TextEditingController();
  final TextEditingController _categoriaController = TextEditingController();

  // ID de liga de prueba (reemplazar dinámicamente según la liga asignada al admin)
  final String _ligaIdActual = 'b281a64d-a57a-49f0-8b61-9abbeea9';

  void _mostrarDiologoCrearEquipo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Nuevo Equipo (POST)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreEquipoController,
              decoration: const InputDecoration(labelText: 'Nombre del Equipo'),
            ),
            TextField(
              controller: _categoriaController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nombreEquipoController.text.isNotEmpty) {
                await _ligaService.crearEquipo(
                  nombre: _nombreEquipoController.text.trim(),
                  categoria: _categoriaController.text.trim(),
                  ligaId: _ligaIdActual,
                  delegadoId: 'aqui_id_delegado_opcional',
                );
                _nombreEquipoController.clear();
                _categoriaController.clear();
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador de Liga'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Equipos de la Liga',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _mostrarDiologoCrearEquipo,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Equipo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _ligaService.obtenerEquiposPorLiga(_ligaIdActual),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final equipos = snapshot.data ?? [];
                  if (equipos.isEmpty) {
                    return const Center(
                      child: Text('No hay equipos registrados en esta liga.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: equipos.length,
                    itemBuilder: (context, index) {
                      final equipo = equipos[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.shield,
                            color: Colors.indigo,
                          ),
                          title: Text(equipo['nombre'] ?? 'Sin nombre'),
                          subtitle: Text(
                            'Categoría: ${equipo['categoria'] ?? 'N/A'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _ligaService.eliminarEquipo(equipo['id']);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
