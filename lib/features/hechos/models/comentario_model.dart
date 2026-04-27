class ComentarioModel {
  final String id;
  final String hechoId;
  final String ciudadanoId;
  final String contenido;
  final DateTime creadoEn;
  final String? nombreAutor;
  final String? avatarAutor;
  final String? respuestaAId;
  List<ComentarioModel> respuestas;
  int conteoLikes;
  bool dioLike;

  // NUEVO: Bandera de pertenencia
  final bool esMio;

  ComentarioModel({
    required this.id,
    required this.hechoId,
    required this.ciudadanoId,
    required this.contenido,
    required this.creadoEn,
    this.nombreAutor,
    this.avatarAutor,
    this.respuestaAId,
    this.respuestas = const [],
    this.conteoLikes = 0,
    this.dioLike = false,
    this.esMio = false, // Por defecto falso
  });

  factory ComentarioModel.fromJson(
    Map<String, dynamic> json,
    String? ciudadanoIdActual,
  ) {
    final listaLikes = json['comentario_likes'] as List<dynamic>? ?? [];

    return ComentarioModel(
      id: json['id'],
      hechoId: json['hecho_id'],
      ciudadanoId: json['ciudadano_id'],
      contenido: json['contenido'],
      creadoEn: DateTime.parse(json['creado_en']),
      nombreAutor: json['usuarios'] != null
          ? json['usuarios']['alias']
          : 'Anónimo',
      avatarAutor: json['usuarios'] != null
          ? json['usuarios']['avatar_url']
          : null,
      respuestaAId: json['respuesta_a_id'],
      respuestas: [],
      conteoLikes: listaLikes.length,
      dioLike:
          ciudadanoIdActual != null &&
          listaLikes.any((like) => like['ciudadano_id'] == ciudadanoIdActual),
      // NUEVO: Verificamos si somos los dueños
      esMio:
          ciudadanoIdActual != null &&
          json['ciudadano_id'] == ciudadanoIdActual,
    );
  }
}
