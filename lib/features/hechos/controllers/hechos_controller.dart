import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hecho_model.dart';
import '../repositories/hechos_repository.dart';
import '../../../core/utils/map_marker_utils.dart';
import '../models/comentario_model.dart';

class HechosController extends ChangeNotifier {
  final HechosRepository _repository = HechosRepository();

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  String _filtroEstadoActual = 'activo';
  String get filtroEstadoActual => _filtroEstadoActual;

  List<HechoModel> _hechosActivos = [];
  List<HechoModel> get hechosActivos => _hechosActivos;

  Set<Marker> _marcadores = {};
  Set<Marker> get marcadores => _marcadores;

  // Variable para guardar la función de navegación
  Function(HechoModel)? _abrirDetalleCallback;
  // Método para registrar la función desde la pantalla
  void setAbrirDetalleCallback(Function(HechoModel) callback) {
    _abrirDetalleCallback = callback;
  }

  Future<void> cargarHechos() async {
    _estaCargando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      // Disparamos la limpieza automática en la base de datos silenciosamente
      await Supabase.instance.client.rpc('archivar_hechos_caducados');

      // Luego descargamos los hechos
      _hechosActivos = await _repository.obtenerHechosPorEstado(
        estado: _filtroEstadoActual,
      );
      await _generarMarcadoresPersonalizados();
    } catch (e) {
      _mensajeError = 'No se pudieron cargar los reportes: $e';
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  // Método para alternar entre Activos e Historial
  Future<void> cambiarFiltro(String nuevoEstado) async {
    if (_filtroEstadoActual == nuevoEstado) return;

    _filtroEstadoActual = nuevoEstado;
    await cargarHechos();
  }

  // LÓGICA DE UX: Marcadores limpios (Sin hechos positivos para el MVP)
  Future<void> _generarMarcadoresPersonalizados() async {
    _marcadores.clear();

    for (var hecho in _hechosActivos) {
      // INTERCEPTOR VISUAL: Ignoramos por completo los hechos positivos
      // Esto cumple con la decisión del MVP sin alterar la BD.
      if (hecho.tipoHecho == 'positivo') continue;

      IconData iconMarker;
      Color colorMarker;

      if (hecho.estado == 'resuelto') {
        iconMarker = Icons.verified_rounded;
        colorMarker = Colors.blueGrey;
      } else {
        // Mapeo normal de iconos (eliminada la opción 'positivo')
        if (hecho.tipoHecho == 'problema') {
          iconMarker = Icons.warning_rounded;
          colorMarker = Colors.red;
        } else if (hecho.tipoHecho == 'alerta') {
          iconMarker = Icons.error_outline_rounded;
          colorMarker = Colors.orange;
        } else {
          // comunitario / defecto
          iconMarker = Icons.group_work_rounded;
          colorMarker = Colors.blue;
        }
      }

      // Descargamos el ícono personalizado asincrónicamente
      final iconDescriptor = await MapMarkerUtils.getBytesFromIcon(
        icon: iconMarker,
        color: colorMarker,
        size: 130,
      );

      _marcadores.add(
        Marker(
          markerId: MarkerId(hecho.id),
          position: LatLng(hecho.latitud, hecho.longitud),
          icon: iconDescriptor,
          onTap: () {
            _abrirDetalleCallback?.call(hecho);
          },
        ),
      );
    }
  }

  Future<bool> publicarNuevoHecho(HechoModel nuevoHecho) async {
    _estaCargando = true;
    notifyListeners();

    try {
      await _repository.crearHecho(nuevoHecho);
      await cargarHechos();
      return true;
    } catch (e) {
      _mensajeError = 'Error al publicar: $e';
      _estaCargando = false;
      notifyListeners();
      return false;
    }
  }

  // Método para enviar validaciones desde la UI
  Future<bool> enviarInteraccion(String hechoId, String tipoInteraccion) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _mensajeError = 'Debes iniciar sesión para participar.';
      notifyListeners();
      return false;
    }

    try {
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final ciudadanoIdReal = usuarioData['id'];

      await _repository.registrarInteraccion(
        hechoId: hechoId,
        ciudadanoId: ciudadanoIdReal,
        tipoInteraccion: tipoInteraccion,
      );
      return true;
    } catch (e) {
      _mensajeError = 'Error al registrar tu voto.';
      debugPrint('Error CRÍTICO en Interacción: $e');
      return false;
    }
  }

  // Verificar qué botones deben estar encendidos al abrir la pantalla
  Future<List<String>> cargarMisInteracciones(String hechoId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      return await _repository.obtenerInteraccionesUsuario(
        hechoId,
        usuarioData['id'],
      );
    } catch (e) {
      return [];
    }
  }

  // Quitar el Upvote
  Future<bool> quitarInteraccion(String hechoId, String tipoInteraccion) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      await _repository.eliminarInteraccion(
        hechoId,
        usuarioData['id'],
        tipoInteraccion,
      );
      return true;
    } catch (e) {
      debugPrint('Error al quitar interacción: $e');
      return false;
    }
  }

  // Puente para obtener los conteos
  Future<Map<String, int>> obtenerConteoInteracciones(String hechoId) async {
    return await _repository.obtenerConteoInteracciones(hechoId);
  }

  // Puente para obtener un único hecho actualizado
  Future<HechoModel?> obtenerHechoPorId(String id) async {
    try {
      return await _repository.obtenerHechoPorId(id);
    } catch (e) {
      _mensajeError = 'Error al refrescar el reporte: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<ComentarioModel>> obtenerComentarios(String hechoId) async {
    final user = Supabase.instance.client.auth.currentUser;
    String? ciudadanoIdActual;

    if (user != null) {
      try {
        final userData = await Supabase.instance.client
            .from('usuarios')
            .select('id')
            .eq('auth_id', user.id)
            .single();
        ciudadanoIdActual = userData['id'];
      } catch (e) {
        debugPrint('Usuario anónimo leyendo comentarios');
      }
    }

    return await _repository.obtenerComentarios(hechoId, ciudadanoIdActual);
  }

  Future<bool> publicarComentario(
    String hechoId,
    String texto, {
    String? respuestaAId,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user!.id)
          .single();

      await Supabase.instance.client.from('comentarios').insert({
        'hecho_id': hechoId,
        'ciudadano_id': userData['id'],
        'contenido': texto,
        'respuesta_a_id': respuestaAId,
      });
      return true;
    } catch (e) {
      debugPrint('Error al comentar: $e');
      return false;
    }
  }

  // Gestión de Likes en Comentarios
  Future<bool> alternarLikeComentario(String comentarioId, bool darLike) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      final ciudadanoId = userData['id'];

      if (darLike) {
        await Supabase.instance.client.from('comentario_likes').insert({
          'comentario_id': comentarioId,
          'ciudadano_id': ciudadanoId,
        });
      } else {
        await Supabase.instance.client.from('comentario_likes').delete().match({
          'comentario_id': comentarioId,
          'ciudadano_id': ciudadanoId,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error al procesar el like: $e');
      return false;
    }
  }

  // Gestión de Denuncias
  Future<bool> reportarComentario(String comentarioId, String motivo) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      await Supabase.instance.client.from('reportes_moderacion').insert({
        'reportado_por_id': userData['id'],
        'comentario_id': comentarioId,
        'motivo': motivo,
      });
      return true;
    } catch (e) {
      debugPrint('Error al reportar comentario: $e');
      return false;
    }
  }

  // ELIMINAR COMENTARIO
  Future<bool> eliminarComentario(String comentarioId) async {
    try {
      await Supabase.instance.client
          .from('comentarios')
          .delete()
          .eq('id', comentarioId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar comentario: $e');
      return false;
    }
  }
}
