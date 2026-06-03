class NotificacionModel {
  final String id;
  final String ciudadanoId;
  final String titulo;
  final String mensaje;
  final String tipo; // 'consenso', 'interaccion', 'sistema', 'gamificacion'
  final String? referenciaId; // ID del hecho o comentario relacionado
  bool leida;
  final DateTime creadoEn;

  NotificacionModel({
    required this.id,
    required this.ciudadanoId,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    this.referenciaId,
    this.leida = false,
    required this.creadoEn,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id: json['id'],
      ciudadanoId: json['ciudadano_id'],
      titulo: json['titulo'],
      mensaje: json['mensaje'],
      tipo: json['tipo'] ?? 'sistema',
      referenciaId: json['referencia_id'],
      leida: json['leida'] ?? false,
      creadoEn: DateTime.parse(json['creado_en']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ciudadano_id': ciudadanoId,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'referencia_id': referenciaId,
      'leida': leida,
    };
  }
}
