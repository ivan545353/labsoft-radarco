class HechoModel {
  final String id;
  final String ciudadanoId;
  final String tipoHecho;
  final double latitud;
  final double longitud;
  final String? fotoUrl;
  final String estado;
  final DateTime creadoEn;
  final String? descripcion;

  // Capa 2 (transparencia): cómo se obtuvo la foto -> 'en_vivo' | 'adjuntada'
  final String? origenFoto;

  // Punto 8: dirección legible resuelta por geocodificación inversa al crear.
  final String? direccion;

  // Datos del autor (Join)
  final String? nombreAutor;
  final String? avatarAutor;
  final int? reputacionAutor;

  // Contadores
  final int conteoUpvotes;
  final int conteoComentarios;

  HechoModel({
    required this.id,
    required this.ciudadanoId,
    required this.tipoHecho,
    required this.latitud,
    required this.longitud,
    this.fotoUrl,
    required this.estado,
    required this.creadoEn,
    this.descripcion,
    this.origenFoto,
    this.direccion,
    this.nombreAutor,
    this.avatarAutor,
    this.reputacionAutor,
    this.conteoUpvotes = 0,
    this.conteoComentarios = 0,
  });

  factory HechoModel.fromJson(Map<String, dynamic> json) {
    return HechoModel(
      id: json['id'],
      ciudadanoId: json['ciudadano_id'],
      tipoHecho: json['tipo_hecho'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      fotoUrl: json['foto_url'],
      estado: json['estado'],
      creadoEn: DateTime.parse(json['creado_en']),
      descripcion: json['descripcion'],
      origenFoto: json['origen_foto'],
      direccion: json['direccion'],
      nombreAutor: json['nombre_autor'],
      avatarAutor: json['avatar_autor'],
      reputacionAutor: json['reputacion_autor'] != null
          ? (json['reputacion_autor'] as num).toInt()
          : 0,
      conteoUpvotes: json['conteo_upvotes'] != null
          ? (json['conteo_upvotes'] as num).toInt()
          : 0,
      conteoComentarios: json['conteo_comentarios'] != null
          ? (json['conteo_comentarios'] as num).toInt()
          : 0,
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
      'origen_foto': origenFoto,
      'direccion': direccion,
    };
  }
}
