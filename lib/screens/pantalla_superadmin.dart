import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Formateador personalizado para convertir todo el texto a Mayúsculas en tiempo real
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PantallaSuperadmin extends StatefulWidget {
  const PantallaSuperadmin({super.key});

  @override
  State<PantallaSuperadmin> createState() => _PantallaSuperadminState();
}

class _PantallaSuperadminState extends State<PantallaSuperadmin> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cargando = true;
  List<Map<String, dynamic>> _ligas = [];

  @override
  void initState() {
    super.initState();
    _cargarLigas();
  }

  // Cargar Ligas desde Supabase
  Future<void> _cargarLigas() async {
    setState(() => _cargando = true);
    try {
      final response = await _supabase
          .from('ligas')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _ligas = List<Map<String, dynamic>>.from(response);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al cargar ligas: $e', Colors.red);
      setState(() => _cargando = false);
    }
  }

  // Diálogo para CREAR o EDITAR Liga con validaciones estrictas
  void _mostrarDialogoLiga({Map<String, dynamic>? ligaExistente}) {
    final bool esEdicion = ligaExistente != null;

    final TextEditingController nombreLigaController = TextEditingController(
      text: esEdicion ? ligaExistente['nombre'] : '',
    );
    final TextEditingController presidenteNombreController =
        TextEditingController(
          text: esEdicion ? ligaExistente['presidente_nombre'] ?? '' : '',
        );
    final TextEditingController presidenteCedulaController =
        TextEditingController(
          text: esEdicion ? ligaExistente['presidente_cedula'] ?? '' : '',
        );
    final TextEditingController presidenteTelefonoController =
        TextEditingController(
          text: esEdicion ? ligaExistente['presidente_telefono'] ?? '' : '',
        );
    final TextEditingController presidenteEmailController =
        TextEditingController(
          text: esEdicion ? ligaExistente['presidente_email'] ?? '' : '',
        );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esEdicion ? 'Editar Liga' : 'Registrar Nueva Liga'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos de la Liga',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3160),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreLigaController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ], // <-- Fuerza MAYÚSCULAS al escribir
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Liga',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports_soccer),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Datos del Presidente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3160),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: presidenteNombreController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ], // <-- Fuerza MAYÚSCULAS al escribir
                  decoration: const InputDecoration(
                    labelText: 'Nombres y Apellidos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presidenteCedulaController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Cédula de Identidad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presidenteTelefonoController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Número de Teléfono',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presidenteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3160),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nombreLiga = nombreLigaController.text
                    .trim()
                    .toUpperCase();
                final presNombre = presidenteNombreController.text
                    .trim()
                    .toUpperCase();
                final presCedula = presidenteCedulaController.text.trim();
                final presTelefono = presidenteTelefonoController.text.trim();
                final presEmail = presidenteEmailController.text.trim();

                // 1. Validar Nombre de la Liga
                if (nombreLiga.isEmpty) {
                  _mostrarMensaje(
                    'El nombre de la liga es obligatorio',
                    Colors.orange,
                  );
                  return;
                }

                // 2. Validar Nombres y Apellidos Completos (Mínimo 4 palabras)
                final palabrasNombre = presNombre
                    .split(RegExp(r'\s+'))
                    .where((p) => p.isNotEmpty)
                    .toList();
                if (palabrasNombre.length < 4) {
                  _mostrarMensaje(
                    'Debe ingresar los dos nombres y dos apellidos completos del Presidente',
                    Colors.orange,
                  );
                  return;
                }

                // 3. Validar Cédula (Exactamente 10 dígitos numéricos)
                final esCedulaValida = RegExp(r'^\d{10}$').hasMatch(presCedula);
                if (!esCedulaValida) {
                  _mostrarMensaje(
                    'La cédula de identidad debe tener exactamente 10 dígitos',
                    Colors.orange,
                  );
                  return;
                }

                // 4. Validar Teléfono (Exactamente 10 dígitos numéricos)
                final esTelefonoValido = RegExp(
                  r'^\d{10}$',
                ).hasMatch(presTelefono);
                if (!esTelefonoValido) {
                  _mostrarMensaje(
                    'El número de teléfono debe tener exactamente 10 dígitos',
                    Colors.orange,
                  );
                  return;
                }

                // 5. Validar Correo Electrónico
                final esEmailValido = RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(presEmail);
                if (!esEmailValido) {
                  _mostrarMensaje(
                    'Ingrese un correo electrónico válido (ejemplo@dominio.com)',
                    Colors.orange,
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  final datos = {
                    'nombre': nombreLiga,
                    'presidente_nombre': presNombre,
                    'presidente_cedula': presCedula,
                    'presidente_telefono': presTelefono,
                    'presidente_email': presEmail,
                  };

                  if (esEdicion) {
                    await _supabase
                        .from('ligas')
                        .update(datos)
                        .eq('id', ligaExistente['id']);
                    _mostrarMensaje(
                      'Liga actualizada correctamente',
                      Colors.green,
                    );
                  } else {
                    await _supabase.from('ligas').insert(datos);
                    _mostrarMensaje(
                      'Liga registrada correctamente',
                      Colors.green,
                    );
                  }
                  _cargarLigas();
                } catch (e) {
                  _mostrarMensaje('Error al guardar: $e', Colors.red);
                }
              },
              child: Text(esEdicion ? 'Guardar Cambios' : 'Registrar Liga'),
            ),
          ],
        );
      },
    );
  }

  // Confirmar y ELIMINAR Liga
  void _confirmarEliminarLiga(Map<String, dynamic> liga) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Deseas eliminar la liga "${liga['nombre']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _supabase.from('ligas').delete().eq('id', liga['id']);
                  _mostrarMensaje('Liga eliminada', Colors.orange);
                  _cargarLigas();
                } catch (e) {
                  _mostrarMensaje('Error al eliminar: $e', Colors.red);
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

  Future<void> _cerrarSesion() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Superadministrador'),
        backgroundColor: const Color(0xFF1A3160),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ligas Registradas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3160),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _mostrarDialogoLiga(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva Liga'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3160),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _ligas.isEmpty
                        ? const Center(
                            child: Text('No hay ligas registradas aún.'),
                          )
                        : ListView.builder(
                            itemCount: _ligas.length,
                            itemBuilder: (context, index) {
                              final liga = _ligas[index];
                              final presNombre =
                                  liga['presidente_nombre'] ?? 'Sin asignar';
                              final presTel =
                                  liga['presidente_telefono'] ?? 'N/A';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF1A3160),
                                    child: Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    liga['nombre'] ?? 'Liga sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Presidente: $presNombre | Tel: $presTel',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip:
                                            'Editar Liga / Ver Información',
                                        onPressed: () => _mostrarDialogoLiga(
                                          ligaExistente: liga,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Eliminar Liga',
                                        onPressed: () =>
                                            _confirmarEliminarLiga(liga),
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
