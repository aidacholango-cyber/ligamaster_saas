import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_superadmin.dart';
import 'pantalla_admin_liga.dart';
import 'pantalla_ligas.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _rolSeleccionado = 'Superadministrador';
  bool _cargando = false;

  final List<String> _roles = [
    'Superadministrador',
    'Administrador de Liga',
    'Delegado / Usuario',
  ];

  // Mapeo entre el texto del Dropdown y el valor del rol en la BD de Supabase
  String _obtenerRolBD(String rolUI) {
    switch (rolUI) {
      case 'Superadministrador':
        return 'superadmin';
      case 'Administrador de Liga':
        return 'admin_liga';
      case 'Delegado / Usuario':
        return 'delegado';
      default:
        return '';
    }
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese correo y contraseña')),
      );
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      // 1. Autenticación contra Supabase Auth
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Usuario no encontrado');
      }

      // 2. Consulta del rol en la tabla perfiles
      final perfil = await Supabase.instance.client
          .from('perfiles')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();

      if (perfil == null) {
        throw Exception('El usuario no tiene un perfil registrado.');
      }

      final String rolBD = perfil['rol'] ?? '';
      final String rolEsperado = _obtenerRolBD(_rolSeleccionado);

      if (!mounted) return;

      // 3. Validación de que el rol seleccionado coincida con el correo asignado
      if (rolBD != rolEsperado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Acceso denegado: Este correo no tiene el rol de "$_rolSeleccionado".',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      // 4. Redirección según el rol verificado
      if (_rolSeleccionado == 'Superadministrador') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PantallaSuperAdmin()),
        );
      } else if (_rolSeleccionado == 'Administrador de Liga') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PantallaAdminLiga()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PantallaLigas()),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de autenticación: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SizedBox(
          width: 450, // Diseño centrado adaptado para pantalla WEB
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_soccer,
                    size: 64,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LigaMaster SaaS',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Text(
                    'Gestión e Inscripción Web',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  DropdownButtonFormField<String>(
                    value: _rolSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Rol de usuario',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_pin),
                    ),
                    items: _roles.map((String rol) {
                      return DropdownMenuItem<String>(
                        value: rol,
                        child: Text(rol),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _rolSeleccionado = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _iniciarSesion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _cargando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
