class HechoModel {
  final String id;
  final String ciudadanoId;
  final String tipoHecho;
  final double latitud;
  final double longitud;
  final String fotoUrl;
  final String estado;
  final DateTime creadoEn;
  // NUEVO CAMPO Opcional
  final String? descripcion;

  HechoModel({
    required this.id,
    required this.ciudadanoId,
    required this.tipoHecho,
    required this.latitud,
    required this.longitud,
    required this.fotoUrl,
    required this.estado,
    required this.creadoEn,
    this.descripcion, // Nuevo
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
      // Mapeo del nuevo campo
      descripcion: json['descripcion'] as String?,
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
      // Inclusión en el JSON
      'descripcion': descripcion,
    };
  }
}
