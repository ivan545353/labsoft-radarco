class UsuarioModel {
  final String id;
  final String authId;
  final String rol;
  final String alias;
  final int reputacion;
  final String? nombre;
  final String? avatarUrl;

  // 🔥 NUEVOS CAMPOS DE PERSONALIZACIÓN
  final String marcoEquipado;
  final String bannerEquipado;
  final String? tituloDestacado;
  final String colorTema;

  UsuarioModel({
    required this.id,
    required this.authId,
    required this.rol,
    required this.alias,
    required this.reputacion,
    this.nombre,
    this.avatarUrl,
    this.marcoEquipado = 'ninguno',
    this.bannerEquipado = 'clasico_azul',
    this.tituloDestacado,
    this.colorTema = 'azul_primario',
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'],
      authId: json['auth_id'],
      rol: json['rol'],
      alias: json['alias'],
      reputacion: json['reputacion'] ?? 0,
      nombre: json['nombre'],
      avatarUrl: json['avatar_url'],
      marcoEquipado: json['marco_equipado'] ?? 'ninguno',
      bannerEquipado: json['banner_equipado'] ?? 'clasico_azul',
      tituloDestacado: json['titulo_destacado'],
      colorTema: json['color_tema'] ?? 'azul_primario',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // id no se envía porque lo autogenera la base de datos
      'auth_id':
          authId, // 🔥 CRUCIAL: Necesario para que el onConflict funcione
      'rol': rol,
      'alias': alias, // Aquí viaja el alias correcto ingresado en el formulario
      'reputacion': reputacion,
      'nombre': nombre,
      'avatar_url': avatarUrl,
      'marco_equipado': marcoEquipado,
      'banner_equipado': bannerEquipado,
      'titulo_destacado': tituloDestacado,
      'color_tema': colorTema,
    };
  }
}
