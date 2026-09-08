import 'package:supabase_flutter/supabase_flutter.dart';

class LigaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- 1. LEER (GET /equipos) ---
  Future<List<Map<String, dynamic>>> obtenerEquiposPorLiga(
    String ligaId,
  ) async {
    final response = await _supabase
        .from('equipos')
        .select('*, perfiles(nombre, email)')
        .eq('liga_id', ligaId);
    return List<Map<String, dynamic>>.from(response);
  }

  // --- 2. CREAR (POST /equipos) ---
  Future<void> crearEquipo({
    required String nombre,
    required String categoria,
    required String ligaId,
    required String delegadoId,
  }) async {
    await _supabase.from('equipos').insert({
      'nombre': nombre,
      'categoria': categoria,
      'liga_id': ligaId,
      'delegado_id': delegadoId,
    });
  }

  // --- 3. ACTUALIZAR (PUT /equipos/:id) ---
  Future<void> actualizarEquipo({
    required String equipoId,
    required String nuevoNombre,
    required String nuevaCategoria,
  }) async {
    await _supabase
        .from('equipos')
        .update({'nombre': nuevoNombre, 'categoria': nuevaCategoria})
        .eq('id', equipoId);
  }

  // --- 4. ELIMINAR (DELETE /equipos/:id) ---
  Future<void> eliminarEquipo(String equipoId) async {
    await _supabase.from('equipos').delete().eq('id', equipoId);
  }
}
