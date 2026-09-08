// lib/models/equipo_model.dart

class Equipo {
  final dynamic id; // Soporta int o String según Supabase
  final String? ligaId;
  final String nombre;
  final int partidosJugados;
  final int partidosGanados;
  final int partidosEmpatados;
  final int partidosPerdidos;
  final int puntos;
  final String? presidenteNombre;
  final String? presidenteCedula;
  final String? presidenteTelefono;
  final String? presidenteEmail;

  const Equipo({
    this.id,
    this.ligaId,
    required this.nombre,
    this.partidosJugados = 0,
    this.partidosGanados = 0,
    this.partidosEmpatados = 0,
    this.partidosPerdidos = 0,
    this.puntos = 0,
    this.presidenteNombre,
    this.presidenteCedula,
    this.presidenteTelefono,
    this.presidenteEmail,
  });

  // Convierte la respuesta JSON de Supabase en una instancia de Equipo
  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'],
      ligaId: json['liga_id']?.toString(),
      nombre: json['nombre'] ?? '',
      puntos: json['puntos'] ?? 0,
      presidenteNombre: json['presidente_nombre'],
      presidenteCedula: json['presidente_cedula'],
      presidenteTelefono: json['presidente_telefono'],
      presidenteEmail: json['presidente_email'],
      partidosJugados: json['partidos_jugados'] ?? 0,
      partidosGanados: json['partidos_ganados'] ?? 0,
      partidosEmpatados: json['partidos_empatados'] ?? 0,
      partidosPerdidos: json['partidos_perdidos'] ?? 0,
    );
  }

  // Convierte el objeto a JSON para Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ligaId != null) 'liga_id': ligaId,
      'nombre': nombre,
      'puntos': puntos,
      'presidente_nombre': presidenteNombre,
      'presidente_cedula': presidenteCedula,
      'presidente_telefono': presidenteTelefono,
      'presidente_email': presidenteEmail,
    };
  }
}
