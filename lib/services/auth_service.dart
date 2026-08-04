import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Iniciar sesión y obtener el rol guardado en la tabla 'perfiles'
  Future<String?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Consultamos la tabla 'perfiles' que acabamos de crear en Supabase
        final profile = await _supabase
            .from('perfiles')
            .select('rol')
            .eq('id', response.user!.id)
            .maybeSingle();

        return profile?['rol'] as String? ?? 'club';
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
