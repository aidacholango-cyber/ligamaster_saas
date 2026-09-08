// lib/models/jugador_model.dart

class Jugador {
  final String? id;
  final dynamic equipoId;
  final String? fotoPerfilUrl;
  final String? fotoCedulaUrl;
  final String cedula;
  final int? numeroCamiseta;
  final String nombres;
  final String apellidos;
  final String? fechaNacimiento;
  final String categoria;
  final String? apodoNotas;
  final String estado; // 'Inscrito', 'Revisado', 'Calificado'
  final String? observaciones;
  final String? fechaInscripcion;
  final String? fechaCalificacion;
  final String? calificadoPor;

  Jugador({
    this.id,
    required this.equipoId,
    this.fotoPerfilUrl,
    this.fotoCedulaUrl,
    required this.cedula,
    this.numeroCamiseta,
    required this.nombres,
    required this.apellidos,
    this.fechaNacimiento,
    this.categoria = 'NOVATO',
    this.apodoNotas,
    this.estado = 'Inscrito',
    this.observaciones,
    this.fechaInscripcion,
    this.fechaCalificacion,
    this.calificadoPor,
  });

  factory Jugador.fromJson(Map<String, dynamic> json) {
    return Jugador(
      id: json['id']?.toString(),
      equipoId: json['equipo_id'],
      fotoPerfilUrl: json['foto_perfil_url'],
      fotoCedulaUrl: json['foto_cedula_url'],
      cedula: json['cedula'] ?? '',
      numeroCamiseta: json['numero_camiseta'] != null
          ? int.tryParse(json['numero_camiseta'].toString())
          : null,
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      fechaNacimiento: json['fecha_nacimiento'],
      categoria: json['categoria'] ?? 'NOVATO',
      apodoNotas: json['apodo_notas'],
      estado: json['estado'] ?? 'Inscrito',
      observaciones: json['observaciones'],
      fechaInscripcion: json['fecha_inscripcion'],
      fechaCalificacion: json['fecha_calificacion'],
      calificadoPor: json['calificado_por'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'equipo_id': equipoId,
      'foto_perfil_url': fotoPerfilUrl,
      'foto_cedula_url': fotoCedulaUrl,
      'cedula': cedula,
      'numero_camiseta': numeroCamiseta,
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nacimiento': fechaNacimiento,
      'categoria': categoria,
      'apodo_notas': apodoNotas,
      'estado': estado,
      'observaciones': observaciones,
      'fecha_calificacion': fechaCalificacion,
      'calificado_por': calificadoPor,
    };
  }
}
