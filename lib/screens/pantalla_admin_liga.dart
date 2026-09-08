import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/liga_service.dart';

class PantallaAdminLiga extends StatefulWidget {
  const PantallaAdminLiga({super.key});

  @override
  State<PantallaAdminLiga> createState() => _PantallaAdminLigaState();
}

class _PantallaAdminLigaState extends State<PantallaAdminLiga> {
  final LigaService _ligaService = LigaService();
  final TextEditingController _nombreEquipoController = TextEditingController();

  // Lista de categorías requeridas
  final List<String> _categorias = [
    'Fútbol Masculino',
    'Fútbol Femenino',
    'Sub 12',
    'Sub 40',
  ];
  String? _categoriaSeleccionada;

  String? _ligaId;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada = _categorias.first;
    _cargarLigaAdmin();
  }

  Future<void> _cargarLigaAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      if (user != null) {
        final ligaData = await Supabase.instance.client
            .from('ligas')
            .select('id')
            .eq('admin_id', user.id)
            .maybeSingle();

        if (ligaData != null) {
          _ligaId = ligaData['id'] as String?;
        }
      }

      if (_ligaId == null) {
        final primeraLiga = await Supabase.instance.client
            .from('ligas')
            .select('id')
            .limit(1)
            .maybeSingle();

        if (primeraLiga != null) {
          _ligaId = primeraLiga['id'] as String?;
        }
      }
    } catch (e) {
      print('Error al identificar liga: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerEquiposBackend() async {
    if (_ligaId != null) {
      final equipos = await _ligaService.obtenerEquiposPorLiga(_ligaId!);
      if (equipos.isNotEmpty) return equipos;
    }

    final todosLosEquipos = await Supabase.instance.client
        .from('equipos')
        .select('*');
    return List<Map<String, dynamic>>.from(todosLosEquipos);
  }

  void _mostrarDialogoCrearEquipo() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar Nuevo Equipo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nombreEquipoController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Equipo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _categorias.map((String categoria) {
                      return DropdownMenuItem<String>(
                        value: categoria,
                        child: Text(categoria),
                      );
                    }).toList(),
                    onChanged: (String? nuevoValor) {
                      setDialogState(() {
                        _categoriaSeleccionada = nuevoValor;
                      });
                    },
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
                    if (_nombreEquipoController.text.trim().isNotEmpty) {
                      final user = Supabase.instance.client.auth.currentUser;
                      await _ligaService.crearEquipo(
                        nombre: _nombreEquipoController.text.trim(),
                        categoria: _categoriaSeleccionada ?? 'Fútbol Masculino',
                        ligaId: _ligaId ?? '',
                        delegadoId: user?.id ?? '',
                      );
                      _nombreEquipoController.clear();
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
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
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Equipos de la Liga',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _mostrarDialogoCrearEquipo,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo Equipo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _obtenerEquiposBackend(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar equipos: ${snapshot.error}',
                            ),
                          );
                        }
                        final equipos = snapshot.data ?? [];
                        if (equipos.isEmpty) {
                          return const Center(
                            child: Text('No hay equipos registrados.'),
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
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await _ligaService.eliminarEquipo(
                                      equipo['id'],
                                    );
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
