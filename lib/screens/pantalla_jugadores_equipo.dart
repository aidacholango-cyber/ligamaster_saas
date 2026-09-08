// lib/screens/pantalla_jugadores_equipo.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/dialogo_agregar_jugador.dart';

class PantallaJugadoresEquipo extends StatefulWidget {
  final dynamic equipoId;
  final String nombreEquipo;

  const PantallaJugadoresEquipo({
    super.key,
    required this.equipoId,
    required this.nombreEquipo,
  });

  @override
  State<PantallaJugadoresEquipo> createState() =>
      _PantallaJugadoresEquipoState();
}

class _PantallaJugadoresEquipoState extends State<PantallaJugadoresEquipo> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cargando = true;
  List<Map<String, dynamic>> _jugadores = [];

  @override
  void initState() {
    super.initState();
    _cargarJugadores();
  }

  Future<void> _cargarJugadores() async {
    setState(() => _cargando = true);
    try {
      final response = await _supabase
          .from('jugadores')
          .select()
          .eq('equipo_id', widget.equipoId)
          .order('dorsal', ascending: true);

      if (!mounted) return;

      setState(() {
        _jugadores = List<Map<String, dynamic>>.from(response);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar jugadores: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _cargando = false);
    }
  }

  void _abrirDialogoAgregar() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoAgregarJugador(
        equipoId: widget.equipoId,
        onGuardar: (_) => _cargarJugadores(),
      ),
    );

    if (resultado == true) {
      _cargarJugadores();
    }
  }

  // --- MÉTODOS DE VER, EDITAR Y ELIMINAR ---

  void _verDetalleJugador(Map<String, dynamic> jugador) {
    final fotoUrl = jugador['foto_url'];
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${jugador['nombres'] ?? ''} ${jugador['apellidos'] ?? ''}',
            style: const TextStyle(color: Color(0xFF1A3160)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF1A3160),
                  backgroundImage: fotoUrl != null
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: fotoUrl == null
                      ? Text(
                          '#${jugador['dorsal'] ?? '0'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge),
                  title: const Text('Cédula'),
                  subtitle: Text(jugador['cedula'] ?? 'N/A'),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.numbers),
                  title: const Text('Dorsal'),
                  subtitle: Text('#${jugador['dorsal'] ?? '-'}'),
                ),
                if (jugador['posicion'] != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sports_soccer),
                    title: const Text('Posición'),
                    subtitle: Text(jugador['posicion']),
                  ),
                if (jugador['telefono'] != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.phone),
                    title: const Text('Teléfono'),
                    subtitle: Text(jugador['telefono']),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _editarJugador(Map<String, dynamic> jugador) {
    final nombresCtrl = TextEditingController(
      text: jugador['nombres']?.toString() ?? '',
    );
    final apellidosCtrl = TextEditingController(
      text: jugador['apellidos']?.toString() ?? '',
    );
    final cedulaCtrl = TextEditingController(
      text: jugador['cedula']?.toString() ?? '',
    );
    final dorsalCtrl = TextEditingController(
      text: jugador['dorsal']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar Jugador'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombresCtrl,
                  decoration: const InputDecoration(labelText: 'Nombres'),
                ),
                TextField(
                  controller: apellidosCtrl,
                  decoration: const InputDecoration(labelText: 'Apellidos'),
                ),
                TextField(
                  controller: cedulaCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Cédula (10 dígitos)',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: dorsalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Dorsal'),
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
                final cedula = cedulaCtrl.text.trim();

                // Validación estricta de cédula de 10 dígitos
                if (cedula.length != 10 || int.tryParse(cedula) == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La cédula debe contener exactamente 10 dígitos numéricos.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final int? dorsalNum = int.tryParse(dorsalCtrl.text.trim());

                try {
                  await _supabase
                      .from('jugadores')
                      .update({
                        'nombres': nombresCtrl.text.trim().toUpperCase(),
                        'apellidos': apellidosCtrl.text.trim().toUpperCase(),
                        'cedula': cedula,
                        'dorsal': dorsalNum,
                      })
                      .eq('id', jugador['id']);

                  if (!mounted) return;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jugador actualizado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _cargarJugadores();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminarJugador(Map<String, dynamic> jugador) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Deseas eliminar a "${jugador['nombres']} ${jugador['apellidos']}"?',
          ),
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
                      .from('jugadores')
                      .delete()
                      .eq('id', jugador['id']);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jugador eliminado'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _cargarJugadores();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jugadores - ${widget.nombreEquipo}'),
        backgroundColor: const Color(0xFF1A3160),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plantilla (${_jugadores.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3160),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _abrirDialogoAgregar,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Agregar Jugador'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3160),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _jugadores.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay jugadores registrados en este equipo.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _jugadores.length,
                            itemBuilder: (context, index) {
                              final jugador = _jugadores[index];
                              final fotoUrl = jugador['foto_url'];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF1A3160),
                                    backgroundImage: fotoUrl != null
                                        ? NetworkImage(fotoUrl)
                                        : null,
                                    child: fotoUrl == null
                                        ? Text(
                                            '#${jugador['dorsal'] ?? '0'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    '${jugador['nombres'] ?? ''} ${jugador['apellidos'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cédula: ${jugador['cedula'] ?? "N/A"}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '#${jugador['dorsal'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A3160),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        tooltip: 'Ver Detalle',
                                        onPressed: () =>
                                            _verDetalleJugador(jugador),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Editar Jugador',
                                        onPressed: () =>
                                            _editarJugador(jugador),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Eliminar Jugador',
                                        onPressed: () =>
                                            _confirmarEliminarJugador(jugador),
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
