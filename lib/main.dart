import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/pantalla_login.dart';
import 'screens/pantalla_superadmin.dart';
import 'screens/pantalla_admin_liga.dart';
import 'screens/pantalla_ligas.dart';

void main() async {
  // 1. Necesario para ejecutar operaciones asíncronas antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar Supabase con tus credenciales
  await Supabase.initialize(
    url: 'https://eexcwuztcbqgstmhxnqe.supabase.co',
    anonKey:
        'sb_publishable_jDpRDlsZ8JsSYWXOeq6YQg__OEprfXN', // <-- Reemplaza por tu llave anon de Supabase
  );

  runApp(const MiAppWebLigas());
}

class MiAppWebLigas extends StatelessWidget {
  const MiAppWebLigas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LigaMaster SaaS Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const PantallaLogin(),
        '/superadmin': (context) => const PantallaSuperAdmin(),
        '/admin_liga': (context) => const PantallaAdminLiga(),
        '/ligas': (context) => const PantallaLigas(),
      },
    );
  }
}
