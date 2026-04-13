class HechoModel {
  final String id;
  final String ciudadanoId;
  final String tipoHecho;
  final double latitud;
  final double longitud;
  final String fotoUrl;
  final String estado;
  final DateTime creadoEn;
  final String? descripcion;

  // NUEVOS CAMPOS: Datos del Autor (provenientes de la tabla 'usuarios')
  final String? nombreAutor;
  final String? avatarAutor;
  final int? reputacionAutor;

  HechoModel({
    required this.id,
    required this.ciudadanoId,
    required this.tipoHecho,
    required this.latitud,
    required this.longitud,
    required this.fotoUrl,
    required this.estado,
    required this.creadoEn,
    this.descripcion,
    this.nombreAutor,
    this.avatarAutor,
    this.reputacionAutor,
  });

  factory HechoModel.fromJson(Map<String, dynamic> json) {
    return HechoModel(
      id: json['id'] as String,
      ciudadanoId: json['ciudadano_id'] as String,
      tipoHecho: json['tipo_hecho'] as String,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      fotoUrl: json['foto_url'] as String,
      estado: json['estado'] as String,
      creadoEn: DateTime.parse(json['creado_en'] as String),
      descripcion: json['descripcion'] as String?,
      // Mapeo de los datos del join (si existen)
      nombreAutor: json['nombre_autor'] as String?,
      avatarAutor: json['avatar_autor'] as String?,
      reputacionAutor: json['reputacion_autor'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ciudadano_id': ciudadanoId,
      'tipo_hecho': tipoHecho,
      'latitud': latitud,
      'longitud': longitud,
      'foto_url': fotoUrl,
      'estado': estado,
      'descripcion': descripcion,
    };
  }
}
