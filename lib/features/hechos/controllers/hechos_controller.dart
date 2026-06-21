import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

  // --- INTERCEPTOR DE DUPLICADOS (interceptor blando) ---
  static const double kRadioDuplicadoMetros = 40;

  // Extrae la etiqueta de categoría ([Bache] - ...) o cae al tipo backend.
  String _extraerCategoriaLabel(HechoModel h) {
    final desc = h.descripcion ?? '';
    final match = RegExp(r'^\[(.*?)\] - ').firstMatch(desc);
    if (match != null) return (match.group(1) ?? '').trim();
    return h.tipoHecho == 'problema' ? 'Problema' : 'Alerta';
  }

  // Devuelve el hecho activo más cercano (misma categoría, < 40 m) o null.
  HechoModel? detectarDuplicado(String categoriaLabel, double lat, double lng) {
    HechoModel? masCercano;
    double distanciaMin = double.infinity;

    for (final h in _hechosActivos) {
      if (h.estado != 'activo') continue;
      if (h.tipoHecho != 'problema' && h.tipoHecho != 'alerta') continue;
      if (_extraerCategoriaLabel(h).toLowerCase() !=
          categoriaLabel.trim().toLowerCase()) {
        continue;
      }

      final d = Geolocator.distanceBetween(lat, lng, h.latitud, h.longitud);
      if (d <= kRadioDuplicadoMetros && d < distanciaMin) {
        distanciaMin = d;
        masCercano = h;
      }
    }
    return masCercano;
  }

  // El usuario confirmó que su reporte es el mismo que [original]:
  // suma su confirmación, adjunta su evidencia y le deja un aviso durable.
  Future<bool> confirmarComoDuplicado({
    required HechoModel original,
    required String ciudadanoId,
    required String textoEvidencia,
    String? fotoUrlEvidencia,
  }) async {
    try {
      // 1. Suma "sigue pasando" (consenso + reputación vía trigger)
      try {
        await _repository.registrarInteraccion(
          hechoId: original.id,
          ciudadanoId: ciudadanoId,
          tipoInteraccion: 'sigue_pasando',
        );
      } catch (e) {
        debugPrint(
          'Aviso: no se pudo sumar sigue_pasando (quizá ya existía): $e',
        );
      }

      // 2. Adjunta su aporte como evidencia (HU4.3)
      final texto = textoEvidencia.trim().isEmpty
          ? 'Reporté lo mismo desde este lugar.'
          : textoEvidencia.trim();
      await _repository.agregarEvidencia(
        original.id,
        ciudadanoId,
        texto,
        fotoUrlEvidencia,
      );

      // 3. Aviso durable para el usuario que reportó el duplicado
      final categoria = _extraerCategoriaLabel(original);
      await _repository.crearNotificacion(
        ciudadanoId: ciudadanoId,
        titulo: 'Tu aporte se sumó a un reporte existente',
        mensaje:
            'Ya había un reporte de "$categoria" muy cerca. Sumamos tu confirmación y tu evidencia al reporte original.',
        tipo: 'interaccion',
        referenciaId: original.id,
      );

      // 3b. Aviso al AUTOR ORIGINAL del hecho (si no es la misma persona)
      if (original.ciudadanoId != ciudadanoId) {
        try {
          await _repository.crearNotificacion(
            ciudadanoId: original.ciudadanoId,
            titulo: 'Confirmaron tu reporte',
            mensaje:
                'Un vecino reportó lo mismo cerca de tu reporte de "$categoria" y sumó evidencia. Ahora tiene más respaldo comunitario.',
            tipo: 'interaccion',
            referenciaId: original.id,
          );
        } catch (e) {
          debugPrint('Aviso: no se pudo notificar al autor original: $e');
        }
      }

      // 4. Refresca el estado en memoria
      await cargarHechos();
      return true;
    } catch (e) {
      _mensajeError = 'No se pudo sumar tu aporte: $e';
      notifyListeners();
      return false;
    }
  }

  // --- HU6.1: resumen de zona al abrir la app ---
  static const double kRadioCercaniaMetros = 500;
  static const int kDiasVentanaCercania = 7;
  bool _yaVerificoCercanos = false;

  Future<void> verificarHechosCercanos() async {
    if (_yaVerificoCercanos) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // anónimo: no aplica
    _yaVerificoCercanos = true; // un solo intento por sesión

    try {
      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      final miId = userData['id'] as String;

      // GPS actual (sin pedir permisos nuevos: si no hay, no avisamos)
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();

      // Qué hechos ya le avisamos
      final vistos = await _repository.obtenerHechosVistos(miId);

      final ahora = DateTime.now();
      final cercanos = _hechosActivos.where((h) {
        if (h.estado != 'activo') return false;
        if (h.tipoHecho != 'problema' && h.tipoHecho != 'alerta') return false;
        if (h.ciudadanoId == miId) return false; // no los míos
        if (ahora.difference(h.creadoEn).inDays > kDiasVentanaCercania) {
          return false;
        }
        if (vistos.contains(h.id)) return false;
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          h.latitud,
          h.longitud,
        );
        return d <= kRadioCercaniaMetros;
      }).toList();

      if (cercanos.isEmpty) return;

      // Desglose por categoría: "2 Bache, 1 Luminaria"
      final Map<String, int> porCategoria = {};
      for (final h in cercanos) {
        final cat = _extraerCategoriaLabel(h);
        porCategoria[cat] = (porCategoria[cat] ?? 0) + 1;
      }
      final desglose = porCategoria.entries
          .map((e) => '${e.value} ${e.key}')
          .join(', ');
      final total = cercanos.length;
      final plural = total == 1 ? 'reporte nuevo' : 'reportes nuevos';

      // Aviso agrupado
      await _repository.crearNotificacion(
        ciudadanoId: miId,
        titulo: 'Reportes nuevos cerca tuyo',
        mensaje: 'Hay $total $plural a menos de 500 m de vos: $desglose.',
        tipo: 'sistema',
        referenciaId: null,
      );

      // Marcamos esos hechos como ya avisados
      await _repository.marcarHechosVistos(
        miId,
        cercanos.map((h) => h.id).toList(),
      );
    } catch (e) {
      debugPrint('Error en verificarHechosCercanos: $e');
    }
  }

  // --- IA: análisis de foto (sugerencia de categoría + plausibilidad) ---
  Future<Map<String, dynamic>?> analizarFotoIA({
    required String imagenBase64,
    required String categoriaElegida,
    required List<String> categoriasValidas,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'analizar-foto',
        body: {
          'imagen_base64': imagenBase64,
          'categoria_elegida': categoriaElegida,
          'categorias_validas': categoriasValidas,
        },
      );
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    } on FunctionException catch (e) {
      debugPrint(
        'FunctionException analizarFotoIA: status=${e.status} details=${e.details}',
      );
      return null;
    } catch (e) {
      debugPrint('Error analizarFotoIA: $e');
      return null;
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
    String? fotoUrl,
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
        'foto_url': fotoUrl,
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

  // --- CAPA 5: Reportar un hecho para moderación ---
  Future<bool> reportarHecho(String hechoId, String motivo) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      await _repository.reportarHechoModeracion(
        hechoId,
        userData['id'],
        motivo,
      );
      return true;
    } catch (e) {
      debugPrint('Error al reportar hecho: $e');
      return false;
    }
  }
}
