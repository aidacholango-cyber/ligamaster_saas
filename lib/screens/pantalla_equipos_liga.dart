// lib/screens/pantalla_equipos_liga.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_jugadores_equipo.dart';

class PantallaEquiposLiga extends StatefulWidget {
  final String ligaId;
  final String nombreLiga;

  const PantallaEquiposLiga({
    super.key,
    required this.ligaId,
    required this.nombreLiga,
  });

  @override
  State<PantallaEquiposLiga> createState() => _PantallaEquiposLigaState();
}

class _PantallaEquiposLigaState extends State<PantallaEquiposLiga> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cargando = true;
  List<Map<String, dynamic>> _equipos = [];

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
  }

  Future<void> _cargarEquipos() async {
    setState(() => _cargando = true);
    try {
      // --- LÍNEA DE DIAGNÓSTICO (revisa la consola de Flutter) ---
      print('*** DIAGNÓSTICO LIGA_ID RECIBIDO: "${widget.ligaId}" ***');

      // Usamos .ilike para evitar problemas si 'CUTUGLAGUA' viene en minúsculas
      final response = await _supabase
          .from('equipos')
          .select()
          .ilike('liga_id', widget.ligaId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _equipos = List<Map<String, dynamic>>.from(response);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al cargar equipos: $e', Colors.red);
      setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoEquipo({Map<String, dynamic>? equipoExistente}) {
    final bool esEdicion = equipoExistente != null;

    final nombreEquipoController = TextEditingController(
      text: esEdicion ? equipoExistente['nombre'] : '',
    );
    final presNombreController = TextEditingController(
      text: esEdicion ? equipoExistente['presidente_nombre'] ?? '' : '',
    );
    final presCedulaController = TextEditingController(
      text: esEdicion ? equipoExistente['presidente_cedula'] ?? '' : '',
    );
    final presTelefonoController = TextEditingController(
      text: esEdicion ? equipoExistente['presidente_telefono'] ?? '' : '',
    );
    final presEmailController = TextEditingController(
      text: esEdicion ? equipoExistente['presidente_email'] ?? '' : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(esEdicion ? 'Editar Equipo' : 'Nuevo Equipo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos del Equipo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3160),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreEquipoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Equipo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shield),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Datos del Presidente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3160),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: presNombreController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nombres y Apellidos Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presCedulaController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Cédula de Identidad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presTelefonoController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Número de Teléfono',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3160),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nombre = nombreEquipoController.text.trim().toUpperCase();
                final presNombre = presNombreController.text
                    .trim()
                    .toUpperCase();
                final presCedula = presCedulaController.text.trim();
                final presTelefono = presTelefonoController.text.trim();
                final presEmail = presEmailController.text.trim();

                if (nombre.isEmpty) {
                  _mostrarMensaje(
                    'El nombre del equipo es obligatorio',
                    Colors.orange,
                  );
                  return;
                }

                if (dialogContext.mounted) Navigator.pop(dialogContext);

                try {
                  final datos = {
                    'nombre': nombre,
                    'presidente_nombre': presNombre,
                    'presidente_cedula': presCedula,
                    'presidente_telefono': presTelefono,
                    'presidente_email': presEmail,
                    'liga_id': widget.ligaId,
                  };

                  if (esEdicion) {
                    await _supabase
                        .from('equipos')
                        .update(datos)
                        .eq('id', equipoExistente['id']);
                    _mostrarMensaje(
                      'Equipo actualizado correctamente',
                      Colors.green,
                    );
                  } else {
                    await _supabase.from('equipos').insert(datos);
                    _mostrarMensaje(
                      'Equipo registrado correctamente',
                      Colors.green,
                    );
                  }
                  _cargarEquipos();
                } catch (e) {
                  _mostrarMensaje('Error al guardar el equipo: $e', Colors.red);
                }
              },
              child: Text(esEdicion ? 'Guardar Cambios' : 'Registrar Equipo'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminarEquipo(Map<String, dynamic> equipo) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Deseas eliminar el equipo "${equipo['nombre']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                try {
                  await _supabase
                      .from('equipos')
                      .delete()
                      .eq('id', equipo['id']);
                  _mostrarMensaje('Equipo eliminado', Colors.orange);
                  _cargarEquipos();
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
        title: Text('Gestión de Equipos - ${widget.nombreLiga}'),
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
                        'Equipos Registrados (${_equipos.length})',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3160),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _mostrarDialogoEquipo(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo Equipo'),
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
                    child: _equipos.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay equipos registrados en esta liga aún.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _equipos.length,
                            itemBuilder: (context, index) {
                              final equipo = _equipos[index];
                              final presNombre =
                                  equipo['presidente_nombre'] ?? 'No asignado';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF1A3160),
                                    child: Text(
                                      (equipo['nombre'] ?? 'E')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    equipo['nombre'] ?? 'Equipo sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text('Presidente: $presNombre'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1A3160,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PantallaJugadoresEquipo(
                                                    equipoId: equipo['id']
                                                        .toString(),
                                                    nombreEquipo:
                                                        equipo['nombre'] ??
                                                        'EQUIPO',
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.people,
                                          size: 18,
                                        ),
                                        label: const Text('Jugadores'),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Editar Equipo',
                                        onPressed: () => _mostrarDialogoEquipo(
                                          equipoExistente: equipo,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Eliminar Equipo',
                                        onPressed: () =>
                                            _confirmarEliminarEquipo(equipo),
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
