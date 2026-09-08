// lib/screens/pantalla_superadmin.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSuperAdmin extends StatefulWidget {
  const PantallaSuperAdmin({super.key});

  @override
  State<PantallaSuperAdmin> createState() => _PantallaSuperAdminState();
}

class _PantallaSuperAdminState extends State<PantallaSuperAdmin> {
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
      final response = await _supabase.from('ligas').select('''
            id,
            nombre,
            categoria,
            admin_id,
            perfiles:admin_id (
              nombre,
              email
            )
          ''');

      if (!mounted) return;

      setState(() {
        _ligas = List<Map<String, dynamic>>.from(response);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar ligas: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _cargando = false);
    }
  }

  Future<void> _abrirDialogoAsignarAdmin(Map<String, dynamic> liga) async {
    String? adminSeleccionadoId = liga['admin_id']?.toString();

    // Obtener usuarios con rol 'admin_liga' desde la tabla perfiles
    List<Map<String, dynamic>> administradores = [];
    try {
      final res = await _supabase
          .from('perfiles')
          .select('id, nombre, email')
          .eq('rol', 'admin_liga');
      administradores = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener administradores: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Asignar Admin a ${liga['nombre']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3160),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccione el usuario que administrará esta liga:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: adminSeleccionadoId,
                    isExpanded: true,
                    hint: const Text('Seleccionar Administrador'),
                    items: administradores.map((admin) {
                      return DropdownMenuItem<String>(
                        value: admin['id'].toString(),
                        child: Text(
                          '${admin['nombre']} (${admin['email']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        adminSeleccionadoId = val;
                      });
                    },
                  ),
                ],
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
                    if (adminSeleccionadoId == null) return;

                    try {
                      await _supabase
                          .from('ligas')
                          .update({'admin_id': adminSeleccionadoId})
                          .eq('id', liga['id']);

                      if (!mounted) return;
                      if (dialogContext.mounted) Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Administrador asignado correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _cargarLigas();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al asignar admin: $e'),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Superadministrador'),
        backgroundColor: const Color(0xFF1A3160),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ligas Registradas y Asignaciones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A3160),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _ligas.isEmpty
                        ? const Center(child: Text('No hay ligas registradas.'))
                        : ListView.builder(
                            itemCount: _ligas.length,
                            itemBuilder: (context, index) {
                              final liga = _ligas[index];
                              final perfil = liga['perfiles'];
                              final adminNombre = perfil != null
                                  ? perfil['nombre']
                                  : 'Sin asignar';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF1A3160),
                                    child: Icon(
                                      Icons.sports_soccer,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    liga['nombre'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Categoría: ${liga['categoria'] ?? "General"} | Admin: $adminNombre',
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () =>
                                        _abrirDialogoAsignarAdmin(liga),
                                    icon: const Icon(
                                      Icons.person_add,
                                      size: 18,
                                    ),
                                    label: Text(
                                      liga['admin_id'] == null
                                          ? 'Asignar Admin'
                                          : 'Reasignar Admin',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A3160),
                                      foregroundColor: Colors.white,
                                    ),
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
