import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaSuperadmin extends StatefulWidget {
  const PantallaSuperadmin({super.key});

  @override
  State<PantallaSuperadmin> createState() => _PantallaSuperadminState();
}

class _PantallaSuperadminState extends State<PantallaSuperadmin> {
  // Controladores para la creación de Admin de Liga + Liga
  final TextEditingController _nombreAdminController = TextEditingController();
  final TextEditingController _correoAdminController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _nombreLigaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;

  // Registrar una Liga con su Administrador asignado
  Future<void> _crearLigaConAdmin() async {
    if (_nombreAdminController.text.trim().isEmpty ||
        _correoAdminController.text.trim().isEmpty ||
        _nombreLigaController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos obligatorios.'),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear usuario en Supabase Auth
      final resAuth = await Supabase.instance.client.auth.signUp(
        email: _correoAdminController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final nuevoUser = resAuth.user;

      if (nuevoUser != null) {
        // 2. Insertar perfil con rol 'admin_liga'
        await Supabase.instance.client.from('perfiles').insert({
          'id': nuevoUser.id,
          'nombre': _nombreAdminController.text.trim(),
          'email': _correoAdminController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'rol': 'admin_liga',
        });

        // 3. Crear la liga vinculada a este Admin
        await Supabase.instance.client.from('ligas').insert({
          'nombre': _nombreLigaController.text.trim(),
          'admin_id': nuevoUser.id,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liga y Administrador registrados con éxito.'),
          ),
        );

        _limpiarFormulario();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
        title: const Text('Registrar Liga y Administrador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreLigaController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Liga',
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
                  labelText: 'Contraseña Acceso Admin',
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
          title: const Text('Panel Superadministrador (Dueños LigaMaster)'),
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
            // --- PESTAÑA 1: LIGAS Y SUS ADMINS ---
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
                                title: Text(liga['nombre'] ?? 'Sin nombre'),
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
                                    if (admin == null)
                                      return const Text(
                                        'Sin Administrador asignado',
                                      );
                                    return Text(
                                      'Admin: ${admin['nombre'] ?? 'N/A'} | Correo: ${admin['email']} | Tel: ${admin['telefono'] ?? 'N/A'}',
                                    );
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

            // --- PESTAÑA 2: VISUALIZACIÓN DE DELEGADOS ---
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
