import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/pantalla_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Se pasan al compilar con --dart-define (en Vercel vienen de las Environment Variables).
  // Si no se definen (o llegan vacías), se usan los valores por defecto para que
  // `flutter run` siga funcionando sin parámetros.
  const envUrl = String.fromEnvironment('SUPABASE_URL');
  const envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const supabaseUrl = envUrl != ''
      ? envUrl
      : 'https://eexcwuztcbqgstmhxnqe.supabase.co';
  const supabaseKey = envKey != ''
      ? envKey
      : 'sb_publishable_jDpRDlsZ8JsSYWXOeq6YQg__OEprfXN';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LigaMaster SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PantallaLogin(),
        '/superadmin': (context) => const PantallaLogin(),
      },
    );
  }
}
