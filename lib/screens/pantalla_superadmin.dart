import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSuperadmin extends StatefulWidget {
  const PantallaSuperadmin({super.key});

  @override
  State<PantallaSuperadmin> createState() => _PantallaSuperadminState();
}

class _PantallaSuperadminState extends State<PantallaSuperadmin> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cargando = true;
  List<Map<String, dynamic>> _ligas = [];

  @override
  void initState() {
    super.initState();
    _cargarLigas();
  }

  // 1. Obtener Ligas desde Supabase
  Future<void> _cargarLigas() async {
    setState(() => _cargando = true);
    try {
      final response = await _supabase
          .from('ligas')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _ligas = List<Map<String, dynamic>>.from(response);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al cargar ligas: $e', Colors.red);
      setState(() => _cargando = false);
    }
  }

  // 2. Diálogo para CREAR o EDITAR Liga
  void _mostrarDialogoLiga({Map<String, dynamic>? ligaExistente}) {
    final bool esEdicion = ligaExistente != null;
    final TextEditingController nombreController = TextEditingController(
      text: esEdicion ? ligaExistente['nombre'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esEdicion ? 'Editar Liga' : 'Crear Nueva Liga'),
          content: TextField(
            controller: nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Liga',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sports_soccer),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3160),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) return;

                Navigator.pop(context); // Cerrar diálogo

                try {
                  if (esEdicion) {
                    // Actualizar liga existente
                    await _supabase
                        .from('ligas')
                        .update({'nombre': nombre})
                        .eq('id', ligaExistente['id']);
                    _mostrarMensaje('Liga actualizada con éxito', Colors.green);
                  } else {
                    // Crear nueva liga
                    await _supabase.from('ligas').insert({'nombre': nombre});
                    _mostrarMensaje('Liga creada con éxito', Colors.green);
                  }
                  _cargarLigas(); // Recargar la lista
                } catch (e) {
                  _mostrarMensaje('Error al guardar: $e', Colors.red);
                }
              },
              child: Text(esEdicion ? 'Guardar Cambios' : 'Crear'),
            ),
          ],
        );
      },
    );
  }

  // 3. Confirmar y ELIMINAR Liga
  void _confirmarEliminarLiga(Map<String, dynamic> liga) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar la liga "${liga['nombre']}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _supabase.from('ligas').delete().eq('id', liga['id']);
                  _mostrarMensaje(
                    'Liga eliminada correctamente',
                    Colors.orange,
                  );
                  _cargarLigas();
                } catch (e) {
                  _mostrarMensaje('Error al eliminar: $e', Colors.red);
                }
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cerrarSesion() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Superadministrador'),
        backgroundColor: const Color(0xFF1A3160),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestión Global de Ligas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3160),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _mostrarDialogoLiga(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva Liga'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3160),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _ligas.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay ligas registradas en el sistema.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _ligas.length,
                            itemBuilder: (context, index) {
                              final liga = _ligas[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF1A3160),
                                    child: Icon(
                                      Icons.sports_soccer,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    liga['nombre'] ?? 'Liga sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Botón Editar
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Editar Liga',
                                        onPressed: () => _mostrarDialogoLiga(
                                          ligaExistente: liga,
                                        ),
                                      ),
                                      // Botón Eliminar
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Eliminar Liga',
                                        onPressed: () =>
                                            _confirmarEliminarLiga(liga),
                                      ),
                                    ],
                                  ),
                                ),
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
