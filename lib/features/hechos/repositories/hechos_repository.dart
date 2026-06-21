import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hecho_model.dart';
import '../models/comentario_model.dart';

class HechosRepository {
  // Instanciamos la conexión a Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- 1. GUARDAR UN NUEVO REPORTE ---
  Future<void> crearHecho(HechoModel hecho) async {
    try {
      // 1. Obtenemos el ID de autenticación actual
      final currentAuthId = _supabase.auth.currentUser!.id;

      // 2. Buscamos el ID real del ciudadano en nuestra tabla 'usuarios'
      final userResponse = await _supabase
          .from('usuarios')
          .select('id')
          .eq('auth_id', currentAuthId)
          .single(); // Ahora funcionará perfecto porque solo habrá 1 fila

      final String ciudadanoIdReal = userResponse['id'];

      // 3. Modificamos el JSON del hecho para inyectar el ID correcto
      final hechoJson = hecho.toJson();
      hechoJson['ciudadano_id'] = ciudadanoIdReal;

      // 4. Insertamos en la base de datos
      await _supabase.from('hechos').insert(hechoJson);
    } catch (e) {
      // Si algo falla, lanzamos el error para que la UI (el SnackBar rojo) lo muestre
      throw Exception('Error de base de datos: $e');
    }
  }

  // --- DESCARGAR REPORTES POR ESTADO (Usando la Vista SQL) ---
  Future<List<HechoModel>> obtenerHechosPorEstado({
    String estado = 'activo',
  }) async {
    try {
      // ✅ Solución al bloqueo de reportes:
      // Construimos la consulta base sin filtros
      var query = _supabase.from('vista_hechos_comunidad').select();

      // Aplicamos el filtro en la base de datos SOLO si no nos piden 'todos'
      if (estado != 'todos') {
        query = query.eq('estado', estado);
      }

      // Ordenamos y ejecutamos
      final response = await query.order('creado_en', ascending: false);

      // El mapeo se vuelve directo
      return (response as List).map((json) {
        return HechoModel.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener hechos de la vista ($estado): $e');
    }
  }

  // --- 3. (OPCIONAL/FUTURO) OBTENER REPORTES DE UN CIUDADANO ESPECÍFICO ---
  // Ideal para la pestaña "Perfil" o "Actividad"
  Future<List<HechoModel>> obtenerHechosPorCiudadano(String ciudadanoId) async {
    try {
      final response = await _supabase
          .from('hechos')
          .select()
          .eq('ciudadano_id', ciudadanoId)
          .order('creado_en', ascending: false); // Los más recientes primero

      final List<dynamic> datos = response;
      return datos
          .map((json) => HechoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error al descargar el historial del ciudadano: $e');
    }
  }

  // --- NUEVO: Registrar interacción comunitaria ---
  Future<void> registrarInteraccion({
    required String hechoId,
    required String ciudadanoId,
    required String
    tipoInteraccion, // 'upvote', 'sigue_pasando', o 'ya_se_resolvio'
  }) async {
    try {
      await _supabase.from('interacciones_comunidad').insert({
        'hecho_id': hechoId,
        'ciudadano_id': ciudadanoId,
        'tipo_interaccion': tipoInteraccion,
      });
    } catch (e) {
      throw Exception('Error al registrar la interacción: $e');
    }
  }

  // --- NUEVO: Leer las interacciones previas del usuario en un hecho ---
  Future<List<String>> obtenerInteraccionesUsuario(
    String hechoId,
    String ciudadanoId,
  ) async {
    try {
      final response = await _supabase
          .from('interacciones_comunidad')
          .select('tipo_interaccion')
          .eq('hecho_id', hechoId)
          .eq('ciudadano_id', ciudadanoId);

      // Convertimos la respuesta de Supabase a una lista simple de strings
      return (response as List)
          .map((fila) => fila['tipo_interaccion'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error al leer interacciones: $e');
      return [];
    }
  }

  // --- NUEVO: Eliminar interacción con validación estricta ---
  Future<void> eliminarInteraccion(
    String hechoId,
    String ciudadanoId,
    String tipoInteraccion,
  ) async {
    try {
      final response =
          await _supabase.from('interacciones_comunidad').delete().match({
            'hecho_id': hechoId,
            'ciudadano_id': ciudadanoId,
            'tipo_interaccion': tipoInteraccion,
          }).select(); // <-- LA CLAVE: Exigimos que nos devuelva lo que borró

      if (response.isEmpty) {
        throw Exception(
          'La seguridad de la BD bloqueó el borrado o el voto no existía.',
        );
      }
    } catch (e) {
      throw Exception('Error al eliminar la interacción: $e');
    }
  }

  // --- NUEVO: Obtener el conteo total de interacciones de la comunidad ---
  Future<Map<String, int>> obtenerConteoInteracciones(String hechoId) async {
    try {
      // Descargamos solo la columna tipo_interaccion para no gastar datos
      final response = await _supabase
          .from('interacciones_comunidad')
          .select('tipo_interaccion')
          .eq('hecho_id', hechoId);

      final lista = response as List<dynamic>;
      int upvotes = 0;
      int siguePasando = 0;
      int resueltos = 0;

      for (var row in lista) {
        final tipo = row['tipo_interaccion'];
        if (tipo == 'upvote') upvotes++;
        if (tipo == 'sigue_pasando') siguePasando++;
        if (tipo == 'ya_se_resolvio') resueltos++;
      }

      return {
        'upvote': upvotes,
        'sigue_pasando': siguePasando,
        'ya_se_resolvio': resueltos,
      };
    } catch (e) {
      debugPrint('Error al contar interacciones: $e');
      return {'upvote': 0, 'sigue_pasando': 0, 'ya_se_resolvio': 0};
    }
  }

  Future<HechoModel?> obtenerHechoPorId(String id) async {
    try {
      // AHORA USAMOS LA VISTA SQL TAMBIÉN AQUÍ
      final response = await _supabase
          .from('vista_hechos_comunidad')
          .select()
          .eq('id', id)
          .single();

      // Como la vista ya trae nombre_autor, avatar_autor y los conteos,
      // el mapeo manual ya no es necesario.
      return HechoModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error al obtener hecho individual: $e');
      return null;
    }
  }

  Future<List<ComentarioModel>> obtenerComentarios(
    String hechoId,
    String? ciudadanoIdActual,
  ) async {
    try {
      final response = await _supabase
          .from('comentarios')
          // Añadimos comentario_likes(ciudadano_id) al Select para traer la relación
          .select(
            '*, usuarios:ciudadano_id(alias, avatar_url), comentario_likes(ciudadano_id)',
          )
          .eq('hecho_id', hechoId)
          .order('creado_en', ascending: true);

      return (response as List)
          .map((json) => ComentarioModel.fromJson(json, ciudadanoIdActual))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener comentarios: $e');
    }
  }

  Future<void> enviarComentario(
    String hechoId,
    String usuarioId,
    String texto,
  ) async {
    await _supabase.from('comentarios').insert({
      'hecho_id': hechoId,
      'ciudadano_id': usuarioId,
      'contenido': texto,
    });
  }

  // --- HU4.3: Adjuntar evidencia (texto + foto opcional) a un hecho ---
  Future<void> agregarEvidencia(
    String hechoId,
    String ciudadanoId,
    String texto,
    String? fotoUrl,
  ) async {
    await _supabase.from('comentarios').insert({
      'hecho_id': hechoId,
      'ciudadano_id': ciudadanoId,
      'contenido': texto,
      'foto_url': fotoUrl,
    });
  }

  // --- Crear una notificación durable para un usuario ---
  // Usa la función SECURITY DEFINER 'crear_notificacion' (saltea RLS de
  // forma controlada). Permite notificar tanto al usuario actual como a
  // un tercero (p. ej. el autor original de un hecho).
  Future<void> crearNotificacion({
    required String ciudadanoId,
    required String titulo,
    required String mensaje,
    required String
    tipo, // 'consenso' | 'interaccion' | 'sistema' | 'gamificacion'
    String? referenciaId,
  }) async {
    await _supabase.rpc(
      'crear_notificacion',
      params: {
        'p_ciudadano_id': ciudadanoId,
        'p_titulo': titulo,
        'p_mensaje': mensaje,
        'p_tipo': tipo,
        'p_referencia_id': referenciaId,
      },
    );
  }

  // --- HU6.1: deduplicación de avisos de hechos cercanos ---
  Future<Set<String>> obtenerHechosVistos(String ciudadanoId) async {
    final response = await _supabase
        .from('notificaciones_hechos_vistos')
        .select('hecho_id')
        .eq('ciudadano_id', ciudadanoId);
    return (response as List).map((r) => r['hecho_id'] as String).toSet();
  }

  Future<void> marcarHechosVistos(
    String ciudadanoId,
    List<String> hechoIds,
  ) async {
    if (hechoIds.isEmpty) return;
    final filas = hechoIds
        .map((id) => {'ciudadano_id': ciudadanoId, 'hecho_id': id})
        .toList();
    await _supabase.from('notificaciones_hechos_vistos').insert(filas);
  }

  // --- CAPA 5: Reportar un HECHO para moderación ---
  Future<void> reportarHechoModeracion(
    String hechoId,
    String ciudadanoId,
    String motivo,
  ) async {
    await _supabase.from('reportes_moderacion').insert({
      'reportado_por_id': ciudadanoId,
      'hecho_id': hechoId,
      'motivo': motivo,
    });
  }
}
