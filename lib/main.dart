import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Rutas de pantallas
import 'screens/pantalla_login.dart';
import 'screens/pantalla_superadmin.dart';
import 'screens/seccion_inicio.dart';
import 'screens/seccion_posiciones.dart';
import 'screens/seccion_resultados.dart';
import 'screens/seccion_fixture.dart';
import 'screens/seccion_sanciones.dart';

Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase
  await Supabase.initialize(
    url: 'https://eexcwuztcbqgstmhxnqe.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVleGN3dXp0Y2JxZ3N0bWh4bnFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyNDQ4NTIsImV4cCI6MjA5OTgyMDg1Mn0.sb8TQAAMnE6Sa3xSXabNFLCQxFrq6WGAVoelxv5NDpE',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LigaMaster SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3160),
          primary: const Color(0xFF1A3160),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PantallaLogin(),
        '/superadmin': (context) => const PantallaSuperadmin(),
        '/club-home': (context) => const PantallaPrincipal(),
      },
    );
  }
}

// ==========================================
// 📋 MODELO Y DATOS DE PRUEBA (EQUIPOS)
// ==========================================
class Equipo {
  final String nombre;
  final int partidosJugados;
  final int partidosGanados;
  final int partidosEmpatados;
  final int partidosPerdidos;
  final int puntos;

  const Equipo({
    required this.nombre,
    required this.partidosJugados,
    required this.partidosGanados,
    required this.partidosEmpatados,
    required this.partidosPerdidos,
    required this.puntos,
  });
}

const List<Equipo> listaDeEquipos = [
  Equipo(
    nombre: 'Club Social El Rosario',
    partidosJugados: 5,
    partidosGanados: 4,
    partidosEmpatados: 0,
    partidosPerdidos: 1,
    puntos: 12,
  ),
  Equipo(
    nombre: 'Atlético San Pedro',
    partidosJugados: 5,
    partidosGanados: 3,
    partidosEmpatados: 1,
    partidosPerdidos: 1,
    puntos: 10,
  ),
  Equipo(
    nombre: 'Deportivo Central',
    partidosJugados: 5,
    partidosGanados: 2,
    partidosEmpatados: 1,
    partidosPerdidos: 2,
    puntos: 7,
  ),
  Equipo(
    nombre: 'Real Juventud',
    partidosJugados: 5,
    partidosGanados: 1,
    partidosEmpatados: 1,
    partidosPerdidos: 3,
    puntos: 4,
  ),
  Equipo(
    nombre: 'F.C. Milán (Nuevo)',
    partidosJugados: 0,
    partidosGanados: 0,
    partidosEmpatados: 0,
    partidosPerdidos: 0,
    puntos: 0,
  ),
];

// ==========================================
// PANTALLA PRINCIPAL (PARA ROLES NORMALES / CLUBES)
// ==========================================
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _seccionActual = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  final List<Widget> _pantallas = [
    const SeccionInicio(),
    const SeccionResultados(),
    const SeccionPosiciones(),
    const SeccionSanciones(),
    const SeccionFixture(),
  ];

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  // Comprueba que exista sesión activa al entrar por URL directa
  void _verificarSesion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicia sesión para ingresar al portal del club'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3160),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Cerrar Sesión',
          onPressed: _cerrarSesion,
        ),
        title: const Text(
          'LIGA INDEPENDIENTE EL ROSARIO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.sports_soccer, color: Colors.amber, size: 28),
          ),
        ],
      ),
      body: _pantallas[_seccionActual],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF0F2F5),
        selectedItemColor: const Color(0xFF1A3160),
        unselectedItemColor: Colors.grey,
        currentIndex: _seccionActual,
        onTap: (index) {
          setState(() {
            _seccionActual = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Resultados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Posiciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Sanciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Fixture',
          ),
        ],
      ),
    );
  }
}
