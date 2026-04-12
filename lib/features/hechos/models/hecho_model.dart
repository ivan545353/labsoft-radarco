class HechoModel {
  final String id;
  final String ciudadanoId;
  final String tipoHecho; // 'problema', 'positivo', 'alerta', 'comunitario'
  final double latitud;
  final double longitud;
  final String fotoUrl;
  final String estado; // 'activo', 'resuelto', 'oculto'
  final DateTime creadoEn;

  HechoModel({
    required this.id,
    required this.ciudadanoId,
    required this.tipoHecho,
    required this.latitud,
    required this.longitud,
    required this.fotoUrl,
    required this.estado,
    required this.creadoEn,
  });

  // --- MAPPER: De Supabase (JSON) a Flutter (Dart) ---
  factory HechoModel.fromJson(Map<String, dynamic> json) {
    return HechoModel(
      id: json['id'] as String,
      ciudadanoId: json['ciudadano_id'] as String,
      tipoHecho: json['tipo_hecho'] as String,
      // Supabase a veces devuelve los NUMERIC como num o dynamic,
      // convertimos a double para evitar errores en el mapa
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      fotoUrl: json['foto_url'] as String,
      estado: json['estado'] as String,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }

  // --- MAPPER: De Flutter (Dart) a Supabase (JSON) ---
  Map<String, dynamic> toJson() {
    return {
      // Nota: 'id' y 'creado_en' suelen ser omitidos en la creación
      // porque la base de datos (PostgreSQL) los genera por defecto con uuid_generate_v4() y now()
      'ciudadano_id': ciudadanoId,
      'tipo_hecho': tipoHecho,
      'latitud': latitud,
      'longitud': longitud,
      'foto_url': fotoUrl,
      'estado': estado,
    };
  }
}
