import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_equipos_liga.dart';

class PantallaLigas extends StatefulWidget {
  const PantallaLigas({super.key});

  @override
  State<PantallaLigas> createState() => _PantallaLigasState();
}

class _PantallaLigasState extends State<PantallaLigas> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cargando = true;
  List<Map<String, dynamic>> _ligas = [];

  @override
  void initState() {
    super.initState();
    _cargarLigas();
  }

  Future<void> _cargarLigas() async {
    setState(() => _cargando = true);
    try {
      final response = await _supabase
          .from('ligas')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _ligas = List<Map<String, dynamic>>.from(response as List);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al cargar ligas: $e', Colors.red);
      setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoNuevaLiga() {
    final TextEditingController nombreLigaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar Nueva Liga'),
          content: TextField(
            controller: nombreLigaController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Liga',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emoji_events),
            ),
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
                final nombre = nombreLigaController.text.trim().toUpperCase();
                if (nombre.isEmpty) {
                  _mostrarMensaje('El nombre es obligatorio', Colors.orange);
                  return;
                }

                try {
                  await _supabase.from('ligas').insert({'nombre': nombre});
                  if (!mounted) return;
                  Navigator.pop(context);
                  _mostrarMensaje('Liga creada exitosamente', Colors.green);
                  _cargarLigas();
                } catch (e) {
                  _mostrarMensaje('Error al crear la liga: $e', Colors.red);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
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
        title: const Text('Mis Ligas Barriales'),
        backgroundColor: const Color(0xFF1A3160),
        foregroundColor: Colors.white,
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
                      Text(
                        'Ligas Disponibles (${_ligas.length})',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3160),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _mostrarDialogoNuevaLiga,
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
                            child: Text('No hay ligas registradas aún.'),
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
                                      Icons.emoji_events,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    liga['nombre'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Haz clic para gestionar equipos',
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    // Navega hacia la pantalla de administración de la liga seleccionada
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PantallaEquiposLiga(
                                              ligaId: liga['id'],
                                              nombreLiga:
                                                  liga['nombre'] ??
                                                  'LIGA BARRIAL',
                                            ),
                                      ),
                                    );
                                  },
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
