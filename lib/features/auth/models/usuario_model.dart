class UsuarioModel {
  final String id;
  final String authId;
  final String rol;
  final String alias;
  final int reputacion;
  final DateTime creadoEn;

  UsuarioModel({
    required this.id,
    required this.authId,
    required this.rol,
    required this.alias,
    this.reputacion = 0,
    required this.creadoEn,
  });

  // Este método (Equivalente a un "Mapper") convierte el JSON de Supabase en un Objeto Dart
  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      rol: json['rol'] as String,
      alias: json['alias'] as String,
      reputacion: json['reputacion'] as int? ?? 0,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }

  // Este método hace lo inverso: convierte el Objeto Dart a JSON para mandarlo a la BD
  Map<String, dynamic> toJson() {
    return {
      // Nota: No enviamos 'id' ni 'creado_en' porque la base de datos los genera automáticamente
      'auth_id': authId,
      'rol': rol,
      'alias': alias,
      'reputacion': reputacion,
    };
  }
}
