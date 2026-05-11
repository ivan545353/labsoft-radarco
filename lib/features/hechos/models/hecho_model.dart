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

  // NUEVO: Fecha límite de vida dinámica
  final DateTime caducaEn;

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
    required this.caducaEn, // <--- REQUERIDO AQUÍ
    this.descripcion,
    this.nombreAutor,
    this.avatarAutor,
    this.reputacionAutor,
    this.conteoUpvotes = 0,
    this.conteoComentarios = 0,
  });

  // --- GETTER INTELIGENTE DE UX (ENFOQUE DE VISIBILIDAD) ---
  String get tiempoRestanteVida {
    final diferencia = caducaEn.difference(DateTime.now());

    if (diferencia.isNegative) return 'Archivando...';

    // 1. Caso reporte super validado por los vecinos (Lejos de morir)
    if (diferencia.inDays > 15) {
      return 'Alta relevancia';
    }

    // 2. Caso intermedio: Aclaramos que se trata de la VISIBILIDAD en la app
    if (diferencia.inDays > 3) {
      return 'Visible ${diferencia.inDays} días más';
    }

    // 3. Caso crítico (72hs o menos): Llamado a la acción sutil para que voten
    if (diferencia.inHours > 24) {
      return 'Perdiendo visibilidad (${diferencia.inDays}d)';
    }

    if (diferencia.inHours > 0) {
      return 'Por expirar (${diferencia.inHours}h)';
    }

    return 'Por expirar (${diferencia.inMinutes}m)';
  }

  factory HechoModel.fromJson(Map<String, dynamic> json) {
    final fechaCreacion = DateTime.parse(json['creado_en']);

    return HechoModel(
      id: json['id'],
      ciudadanoId: json['ciudadano_id'],
      tipoHecho: json['tipo_hecho'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      fotoUrl: json['foto_url'],
      estado: json['estado'],
      creadoEn: fechaCreacion,
      // PARSEO BLINDADO: Si por algún motivo de caché la fecha viene nula,
      // le calculamos las 72 horas por defecto para evitar crashes.
      caducaEn: json['caduca_en'] != null
          ? DateTime.parse(json['caduca_en'])
          : fechaCreacion.add(const Duration(days: 3)),
      descripcion: json['descripcion'],
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
    };
  }
}
