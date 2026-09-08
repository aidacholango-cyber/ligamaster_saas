// lib/models/liga_model.dart

class Liga {
  final String id;
  final String nombre;
  final String? adminId;
  final DateTime? createdAt;

  const Liga({
    required this.id,
    required this.nombre,
    this.adminId,
    this.createdAt,
  });

  factory Liga.fromJson(Map<String, dynamic> json) {
    return Liga(
      id: json['id'] as String,
      nombre: json['nombre'] ?? '',
      adminId: json['admin_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nombre': nombre, 'admin_id': adminId};
  }
}
