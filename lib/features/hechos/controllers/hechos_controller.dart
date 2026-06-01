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

  // ❌ Se eliminó _filtroEstadoActual porque ahora la UI filtra todo dinámicamente

  List<HechoModel> _hechosActivos = [];
  List<HechoModel> get hechosActivos => _hechosActivos;

  Set<Marker> _marcadores = {};
  Set<Marker> get marcadores => _marcadores;

  Function(HechoModel)? _abrirDetalleCallback;

  void setAbrirDetalleCallback(Function(HechoModel) callback) {
    _abrirDetalleCallback = callback;
  }

  Future<void> cargarHechos() async {
    _estaCargando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      // ✅ Solicitamos el historial completo.
      // Pasamos 'todos' para indicarle al repositorio que no filtre nada.
      _hechosActivos = await _repository.obtenerHechosPorEstado(
        estado: 'todos',
      );
      await _generarMarcadoresPersonalizados();
    } catch (e) {
      _mensajeError = 'No se pudieron cargar los reportes: $e';
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  // 🚀 LÓGICA DE UX PREMIUM: Marcadores Inteligentes en el Mapa
  Future<void> _generarMarcadoresPersonalizados() async {
    _marcadores.clear();

    for (var hecho in _hechosActivos) {
      if (hecho.tipoHecho == 'positivo') continue;

      IconData iconMarker;
      Color colorMarker;

      if (hecho.estado == 'resuelto') {
        iconMarker = Icons.verified_rounded;
        colorMarker = Colors.green[600]!; // Verde para casos resueltos
      } else {
        // Inteligencia de Parseo para pintar el mapa
        final match = RegExp(
          r'^\[(.*?)\] - ',
        ).firstMatch(hecho.descripcion ?? '');
        final categoria = match != null ? match.group(1) : null;

        switch (categoria) {
          case 'Bache':
            iconMarker = Icons.terrain_rounded;
            colorMarker = Colors.red[500]!;
            break;
          case 'Basura':
            iconMarker = Icons.delete_outline_rounded;
            colorMarker = Colors.brown[400]!;
            break;
          case 'Luminaria':
            iconMarker = Icons.lightbulb_outline_rounded;
            colorMarker = Colors.amber[600]!;
            break;
          case 'Agua / Caño':
            iconMarker = Icons.water_drop_outlined;
            colorMarker = Colors.blue[500]!;
            break;
          case 'Accidente':
            iconMarker = Icons.car_crash_outlined;
            colorMarker = Colors.deepOrange[500]!;
            break;
          case 'Obstrucción':
            iconMarker = Icons.block_flipped;
            colorMarker = Colors.orange[500]!;
            break;
          case 'Inseguridad':
            iconMarker = Icons.security_outlined;
            colorMarker = Colors.purple[400]!;
            break;
          default:
            iconMarker = hecho.tipoHecho == 'alerta'
                ? Icons.warning_rounded
                : Icons.report_problem_rounded;
            colorMarker = hecho.tipoHecho == 'alerta'
                ? Colors.orange[500]!
                : Colors.blueGrey[500]!;
        }
      }

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

      await _repository.registrarInteraccion(
        hechoId: hechoId,
        ciudadanoId: usuarioData['id'],
        tipoInteraccion: tipoInteraccion,
      );
      return true;
    } catch (e) {
      _mensajeError = 'Error al registrar tu voto.';
      debugPrint('Error CRÍTICO en Interacción: $e');
      return false;
    }
  }

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
      return false;
    }
  }

  Future<Map<String, int>> obtenerConteoInteracciones(String hechoId) async {
    return await _repository.obtenerConteoInteracciones(hechoId);
  }

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
      return false;
    }
  }

  Future<bool> alternarLikeComentario(String comentarioId, bool darLike) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      if (darLike) {
        await Supabase.instance.client.from('comentario_likes').insert({
          'comentario_id': comentarioId,
          'ciudadano_id': userData['id'],
        });
      } else {
        await Supabase.instance.client.from('comentario_likes').delete().match({
          'comentario_id': comentarioId,
          'ciudadano_id': userData['id'],
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

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
      return false;
    }
  }

  Future<bool> eliminarComentario(String comentarioId) async {
    try {
      await Supabase.instance.client
          .from('comentarios')
          .delete()
          .eq('id', comentarioId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
