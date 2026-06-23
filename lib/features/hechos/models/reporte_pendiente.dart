import 'dart:convert';

/// Un reporte creado sin conexión, a la espera de publicarse.
class ReportePendiente {
  final String id; // id local (no es el de la BD)
  final String categoriaNombre;
  final String tipoBackend;
  final String descripcionFinal; // ya viene como "[Categoría] - texto"
  final double latitud;
  final double longitud;
  final String origenFoto; // 'en_vivo' | 'adjuntada'
  final String imagenPath; // copia local persistente de la foto
  final DateTime capturadoEn; // timestamp de captura (regla de 24 h)
  final DateTime encoladoEn; // cuándo se guardó offline

  String estado; // 'pendiente' | 'retenido'
  String? motivoRetencion; // por qué quedó retenido (ej. IA lo rechazó)

  ReportePendiente({
    required this.id,
    required this.categoriaNombre,
    required this.tipoBackend,
    required this.descripcionFinal,
    required this.latitud,
    required this.longitud,
    required this.origenFoto,
    required this.imagenPath,
    required this.capturadoEn,
    required this.encoladoEn,
    this.estado = 'pendiente',
    this.motivoRetencion,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'categoriaNombre': categoriaNombre,
    'tipoBackend': tipoBackend,
    'descripcionFinal': descripcionFinal,
    'latitud': latitud,
    'longitud': longitud,
    'origenFoto': origenFoto,
    'imagenPath': imagenPath,
    'capturadoEn': capturadoEn.toIso8601String(),
    'encoladoEn': encoladoEn.toIso8601String(),
    'estado': estado,
    'motivoRetencion': motivoRetencion,
  };

  factory ReportePendiente.fromMap(Map<String, dynamic> m) => ReportePendiente(
    id: m['id'] as String,
    categoriaNombre: m['categoriaNombre'] as String,
    tipoBackend: m['tipoBackend'] as String,
    descripcionFinal: m['descripcionFinal'] as String,
    latitud: (m['latitud'] as num).toDouble(),
    longitud: (m['longitud'] as num).toDouble(),
    origenFoto: m['origenFoto'] as String,
    imagenPath: m['imagenPath'] as String,
    capturadoEn: DateTime.parse(m['capturadoEn'] as String),
    encoladoEn: DateTime.parse(m['encoladoEn'] as String),
    estado: (m['estado'] as String?) ?? 'pendiente',
    motivoRetencion: m['motivoRetencion'] as String?,
  );

  String toJsonString() => jsonEncode(toMap());

  factory ReportePendiente.fromJsonString(String s) =>
      ReportePendiente.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
