import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSuperadmin extends StatefulWidget {
  const PantallaSuperadmin({super.key});

  @override
  State<PantallaSuperadmin> createState() => _PantallaSuperadminState();
}

class _PantallaSuperadminState extends State<PantallaSuperadmin> {
  final TextEditingController _nombreAdminController = TextEditingController();
  final TextEditingController _correoAdminController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _nombreLigaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;

  // Registrar nueva Liga (en MAYÚSCULAS) + Nuevo Admin con validaciones
  Future<void> _crearLigaConAdmin() async {
    final nombreLigaMayus = _nombreLigaController.text.trim().toUpperCase();
    final correo = _correoAdminController.text.trim().toLowerCase();
    final nombreAdmin = _nombreAdminController.text.trim();
    final password = _passwordController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (nombreAdmin.isEmpty ||
        correo.isEmpty ||
        nombreLigaMayus.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos obligatorios.'),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Validar si la liga ya existe
      final ligaExistente = await Supabase.instance.client
          .from('ligas')
          .select('id')
          .eq('nombre', nombreLigaMayus)
          .maybeSingle();

      if (ligaExistente != null) {
        throw 'Ya existe una liga registrada con el nombre "$nombreLigaMayus".';
      }

      // 2. Validar si el correo ya está registrado en perfiles
      final perfilExistente = await Supabase.instance.client
          .from('perfiles')
          .select('id')
          .eq('email', correo)
          .maybeSingle();

      if (perfilExistente != null) {
        throw 'El correo "$correo" ya se encuentra registrado.';
      }

      // 3. Crear usuario en Auth
      final resAuth = await Supabase.instance.client.auth.signUp(
        email: correo,
        password: password,
      );

      final nuevoUser = resAuth.user;

      if (nuevoUser != null) {
        await Supabase.instance.client.from('perfiles').insert({
          'id': nuevoUser.id,
          'nombre': nombreAdmin,
          'email': correo,
          'telefono': telefono,
          'rol': 'admin_liga',
        });

        await Supabase.instance.client.from('ligas').insert({
          'nombre': nombreLigaMayus, // Guarda en MAYÚSCULAS
          'admin_id': nuevoUser.id,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Liga y Administrador registrados con éxito.'),
            ),
          );
          _limpiarFormulario();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Editar Nombre de la Liga
  Future<void> _editarLiga(String ligaId, String nombreActual) async {
    final controller = TextEditingController(text: nombreActual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nombre de Liga'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre de la Liga',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoNombre = controller.text.trim().toUpperCase();
              if (nuevoNombre.isNotEmpty) {
                await Supabase.instance.client
                    .from('ligas')
                    .update({'nombre': nuevoNombre})
                    .eq('id', ligaId);

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Liga actualizada correctamente.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Eliminar Liga
  Future<void> _eliminarLiga(String ligaId, String nombreLiga) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Está seguro de que desea eliminar la liga "$nombreLiga"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Supabase.instance.client.from('ligas').delete().eq('id', ligaId);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liga eliminada correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Asignar o Cambiar Admin existente
  Future<void> _mostrarDialogoAsignarAdmin(
    String ligaId,
    String nombreLiga,
  ) async {
    String? adminSeleccionadoId;

    final respuestaAdmins = await Supabase.instance.client
        .from('perfiles')
        .select('id, nombre, email')
        .eq('rol', 'admin_liga');

    List<Map<String, dynamic>> admins = List<Map<String, dynamic>>.from(
      respuestaAdmins,
    );

    if (admins.isEmpty) {
      final todos = await Supabase.instance.client
          .from('perfiles')
          .select('id, nombre, email');
      admins = List<Map<String, dynamic>>.from(todos);
    }

    if (admins.isNotEmpty) {
      adminSeleccionadoId = admins.first['id'].toString();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Asignar Admin a: $nombreLiga'),
              content: admins.isEmpty
                  ? const Text('No hay administradores disponibles.')
                  : DropdownButtonFormField<String>(
                      value: adminSeleccionadoId,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Administrador',
                        border: OutlineInputBorder(),
                      ),
                      items: admins.map((admin) {
                        final label =
                            admin['nombre'] ?? admin['email'] ?? 'Sin nombre';
                        return DropdownMenuItem<String>(
                          value: admin['id'].toString(),
                          child: Text('$label (${admin['email']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          adminSeleccionadoId = val;
                        });
                      },
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: adminSeleccionadoId == null
                      ? null
                      : () async {
                          await Supabase.instance.client
                              .from('ligas')
                              .update({'admin_id': adminSeleccionadoId})
                              .eq('id', ligaId);

                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Administrador asignado correctamente.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _limpiarFormulario() {
    _nombreAdminController.clear();
    _correoAdminController.clear();
    _telefonoController.clear();
    _nombreLigaController.clear();
    _passwordController.clear();
  }

  void _mostrarDiologoCrearLiga() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Nueva Liga y Administrador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreLigaController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Liga (Se guardará en MAYÚSCULAS)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreAdminController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Administrador',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correoAdminController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico Único',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número de Teléfono',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña de Acceso',
                  border: OutlineInputBorder(),
                ),
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
            onPressed: _cargando ? null : _crearLigaConAdmin,
            child: _cargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Superadministrador (LigaMaster)'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.sports), text: 'Ligas y Administradores'),
              Tab(icon: Icon(Icons.badge), text: 'Delegados de Equipos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PESTAÑA 1: LIGAS Y ADMINISTRADORES
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ligas Registradas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _mostrarDiologoCrearLiga,
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva Liga / Admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('ligas')
                          .stream(primaryKey: ['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final ligas = snapshot.data ?? [];
                        if (ligas.isEmpty) {
                          return const Center(
                            child: Text('No hay ligas registradas.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: ligas.length,
                          itemBuilder: (context, index) {
                            final liga = ligas[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.indigo,
                                ),
                                title: Text(
                                  liga['nombre']?.toString().toUpperCase() ??
                                      'SIN NOMBRE',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: FutureBuilder<Map<String, dynamic>?>(
                                  future: liga['admin_id'] != null
                                      ? Supabase.instance.client
                                            .from('perfiles')
                                            .select('nombre, email, telefono')
                                            .eq('id', liga['admin_id'])
                                            .maybeSingle()
                                      : Future.value(null),
                                  builder: (context, adminSnapshot) {
                                    final admin = adminSnapshot.data;
                                    if (admin == null) {
                                      return const Text(
                                        'Sin Administrador asignado',
                                      );
                                    }
                                    return Text(
                                      'Admin: ${admin['nombre'] ?? 'N/A'} | Correo: ${admin['email']} | Tel: ${admin['telefono'] ?? 'N/A'}',
                                    );
                                  },
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _mostrarDialogoAsignarAdmin(
                                            liga['id'],
                                            liga['nombre'] ?? 'Liga',
                                          ),
                                      icon: const Icon(
                                        Icons.person_add,
                                        size: 16,
                                      ),
                                      label: const Text('Admin'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.orange,
                                      ),
                                      onPressed: () => _editarLiga(
                                        liga['id'],
                                        liga['nombre'] ?? '',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _eliminarLiga(
                                        liga['id'],
                                        liga['nombre'] ?? 'Liga',
                                      ),
                                    ),
                                  ],
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

            // PESTAÑA 2: DELEGADOS
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('perfiles')
                    .stream(primaryKey: ['id'])
                    .eq('rol', 'delegado'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final delegados = snapshot.data ?? [];
                  if (delegados.isEmpty) {
                    return const Center(
                      child: Text('No hay delegados registrados aún.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: delegados.length,
                    itemBuilder: (context, index) {
                      final del = delegados[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.person,
                            color: Colors.blueAccent,
                          ),
                          title: Text(del['nombre'] ?? 'Delegado Sin Nombre'),
                          subtitle: Text(
                            'Correo: ${del['email']} | Teléfono: ${del['telefono'] ?? 'N/A'}',
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
