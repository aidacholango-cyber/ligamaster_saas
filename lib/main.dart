import 'package:flutter/material.dart';
import 'screens/seccion_inicio.dart';
import 'screens/seccion_posiciones.dart';
import 'screens/seccion_resultados.dart';
import 'screens/seccion_fixture.dart';
import 'package:liga_el_rosario/screens/seccion_sanciones.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos para arrancar servicios externos
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase con los datos de tu proyecto LigaMaster SaaS

  await Supabase.initialize(
    url: 'https://eexcwuztcbqgstmhxnqe.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'sb_publishable_jDpRd1sZ8JsSYWXOeq6YQg__OEprfXN',
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
        primaryColor: const Color(0xFF1A3160),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(), // Abre directamente tu menú y pantallas
    );
  }
}

// ==========================================
// 📋 AQUÍ INGRESAS TUS EQUIPOS INSCRITOS
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

// Puedes cambiar los nombres o los números aquí mismo cuando quieras:
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

class MiAppTorneo extends StatelessWidget {
  const MiAppTorneo({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liga El Rosario',
      home: PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _seccionActual = 0;

  final List<Widget> _pantallas = [
    const SeccionInicio(), // 0. Inicio
    const SeccionResultados(), // 1. Resultados
    const SeccionPosiciones(), // 2. Posiciones (¡Tu nueva pantalla aquí!)
    const SeccionSanciones(), // 3. Sanciones
    const SeccionFixture(), // 4. Fixture
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3160),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {},
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
