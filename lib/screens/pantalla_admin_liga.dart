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

  // Categorías predefinidas
  final List<String> _categorias = [
    'Fútbol Masculino',
    'Fútbol Femenino',
    'Sub 12',
    'Sub 40',
  ];
  String? _categoriaSeleccionada;

  // Manejo de Delegados
  List<Map<String, dynamic>> _delegados = [];
  String? _delegadoSeleccionadoId;

  String? _ligaId;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada = _categorias.first;
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      // 1. Obtener ID de la liga
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

      // 2. Cargar lista de delegados desde la tabla perfiles
      final respuestaPerfiles = await Supabase.instance.client
          .from('perfiles')
          .select('id, nombre, email')
          .eq('rol', 'delegado');

      _delegados = List<Map<String, dynamic>>.from(respuestaPerfiles);

      // Si no hay usuarios con rol delegado, carga todos los perfiles como alternativa
      if (_delegados.isEmpty) {
        final todosPerfiles = await Supabase.instance.client
            .from('perfiles')
            .select('id, nombre, email');
        _delegados = List<Map<String, dynamic>>.from(todosPerfiles);
      }

      if (_delegados.isNotEmpty) {
        _delegadoSeleccionadoId = _delegados.first['id'].toString();
      }
    } catch (e) {
      print('Error al cargar datos iniciales: $e');
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
              content: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _delegadoSeleccionadoId,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Delegado',
                        border: OutlineInputBorder(),
                      ),
                      items: _delegados.map((delegado) {
                        final nombre =
                            delegado['nombre'] ??
                            delegado['email'] ??
                            'Sin nombre';
                        return DropdownMenuItem<String>(
                          value: delegado['id'].toString(),
                          child: Text(nombre),
                        );
                      }).toList(),
                      onChanged: (String? nuevoDelegadoId) {
                        setDialogState(() {
                          _delegadoSeleccionadoId = nuevoDelegadoId;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nombre = _nombreEquipoController.text.trim();
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Por favor ingrese el nombre del equipo.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (_delegadoSeleccionadoId == null ||
                        _delegadoSeleccionadoId!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor seleccione un delegado.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await _ligaService.crearEquipo(
                        nombre: nombre,
                        categoria: _categoriaSeleccionada ?? 'Fútbol Masculino',
                        ligaId: _ligaId ?? '',
                        delegadoId: _delegadoSeleccionadoId!,
                      );
                      _nombreEquipoController.clear();
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    } catch (e) {
                      print('Error al crear equipo: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al guardar: $e')),
                        );
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
