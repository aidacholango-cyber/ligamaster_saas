import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './pantalla_superadmin.dart';
import 'pantalla_admin_liga.dart';
import 'pantalla_delegado.dart';

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

  // Lista de roles actualizada con Delegado
  final List<String> _roles = [
    'Superadministrador',
    'Administrador de Liga',
    'Delegado del equipo',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_cargando) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final rolElegido = _rolSeleccionado;
    const roles = {
      'Superadministrador': 'superadmin',
      'Administrador de Liga': 'admin',
      'Delegado del equipo': 'club',
    };
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }
    setState(() => _cargando = true);
    final db = Supabase.instance.client;
    String? error;
    try {
      final respuesta = await db.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final usuario = respuesta.user;
      if (usuario == null) throw StateError('No se pudo iniciar sesión.');
      final perfil = await db
          .from('perfiles')
          .select('rol')
          .eq('id', usuario.id)
          .maybeSingle();
      final rol = perfil?['rol']?.toString();
      if (rol == null || !roles.values.contains(rol)) {
        throw StateError(
          'Tu cuenta no tiene un rol asignado. Contacta al superadministrador.',
        );
      }
      if (rol != roles[rolElegido]) {
        throw StateError(
          'Este correo no tiene acceso como $rolElegido. Selecciona el rol que corresponde a tu cuenta.',
        );
      }
      Widget destino;
      if (rol == 'superadmin') {
        destino = PantallaSuperAdmin();
      } else if (rol == 'admin') {
        final ligas = await db
            .from('ligas')
            .select('id')
            .eq('admin_id', usuario.id)
            .limit(1);
        if (ligas.isEmpty)
          throw StateError('Tu cuenta no tiene una liga asignada.');
        destino = const PantallaAdminLiga();
      } else {
        final equipos = await db
            .from('equipos')
            .select('id')
            .eq('delegado_id', usuario.id)
            .limit(1);
        if (equipos.isEmpty)
          throw StateError(
            'Tu cuenta no tiene un equipo asignado. Contacta al superadministrador.',
          );
        destino = const PantallaDelegado();
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destino),
        (_) => false,
      );
    } on AuthException {
      error = 'No se pudo iniciar sesión. Comprueba el correo y la contraseña.';
    } on StateError catch (e) {
      error = e.message.toString();
    } catch (_) {
      error =
          'No se pudo verificar tu acceso. Comprueba tu conexión e inténtalo de nuevo.';
    } finally {
      if (error != null) {
        try {
          await db.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              color: const Color(0xFFF7F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 36.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3F51B5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'LigaMaster SaaS',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F51B5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gestión e Inscripción Web',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 28),
                    DropdownButtonFormField<String>(
                      value: _rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Rol de usuario',
                        prefixIcon: Icon(
                          Icons.account_circle_outlined,
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: _roles.map((rol) {
                        return DropdownMenuItem(
                          value: rol,
                          child: Text(
                            rol,
                            style: const TextStyle(fontSize: 15),
                          ),
                        );
                      }).toList(),
                      onChanged: _cargando
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _rolSeleccionado = val;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _cargando
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
