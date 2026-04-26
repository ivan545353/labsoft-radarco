import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hecho_model.dart';
import '../repositories/hechos_repository.dart';
import '../../../core/utils/map_marker_utils.dart';

class HechosController extends ChangeNotifier {
  final HechosRepository _repository = HechosRepository();

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

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
      _hechosActivos = await _repository.obtenerHechosActivos();
      // CAMBIO: Ahora la generación es asincrónica
      await _generarMarcadoresPersonalizados();
    } catch (e) {
      _mensajeError = 'No se pudieron cargar los reportes: $e';
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  // NUEVA LÓGICA DE UX: Marcadores con íconos de Stitch
  Future<void> _generarMarcadoresPersonalizados() async {
    _marcadores.clear();

    for (var hecho in _hechosActivos) {
      IconData iconMarker;
      Color colorMarker;

      // Mapeo preciso según el Stitch UI
      if (hecho.tipoHecho == 'problema') {
        iconMarker = Icons.warning_rounded; // Ícono de Problem
        colorMarker = Colors.red;
      } else if (hecho.tipoHecho == 'alerta') {
        iconMarker = Icons.error_outline_rounded; // Ícono de Alert
        colorMarker = Colors.orange;
      } else if (hecho.tipoHecho == 'positivo') {
        iconMarker = Icons.thumb_up_alt_rounded; // Ícono de Positive
        colorMarker = Colors.green;
      } else {
        // comunitario/defecto
        iconMarker = Icons.group_work_rounded;
        colorMarker = Colors.blue;
      }

      // CAMBIO UX CLAVE: Descargamos el ícono personalizado asincrónicamente
      final iconDescriptor = await MapMarkerUtils.getBytesFromIcon(
        icon: iconMarker,
        color: colorMarker,
        size: 130, // Un poco más grande para mejor UX
      );

      _marcadores.add(
        Marker(
          markerId: MarkerId(hecho.id),
          position: LatLng(hecho.latitud, hecho.longitud),
          icon: iconDescriptor,
          // 1. ELIMINAMOS la propiedad 'infoWindow' por completo.

          // 2. Le pasamos la acción directamente al Pin.
          onTap: () {
            // Ahora, al tocar el pin (un solo toque), notificamos a la pantalla
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

  // --- NUEVO: Método para enviar validaciones desde la UI ---
  Future<bool> enviarInteraccion(String hechoId, String tipoInteraccion) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _mensajeError = 'Debes iniciar sesión para participar.';
      notifyListeners();
      return false;
    }

    try {
      // 1. TRADUCCIÓN DE ID: Buscamos el ID público del ciudadano usando su Auth ID
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final ciudadanoIdReal = usuarioData['id'];

      // 2. ENVIAR A LA BD: Ahora usamos el ID correcto que la llave foránea espera
      await _repository.registrarInteraccion(
        hechoId: hechoId,
        ciudadanoId: ciudadanoIdReal,
        tipoInteraccion: tipoInteraccion,
      );
      return true;
    } catch (e) {
      _mensajeError = 'Error al registrar tu voto.';
      // Esto imprimirá el error real en la consola azul por si vuelve a fallar
      debugPrint('Error CRÍTICO en Interacción: $e');
      return false;
    }
  }

  // --- NUEVO: Verificar qué botones deben estar encendidos al abrir la pantalla ---
  Future<List<String>> cargarMisInteracciones(String hechoId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return []; // Si es anónimo, no tiene interacciones

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

  // --- NUEVO: Quitar el Upvote ---
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

  // --- NUEVO: Puente para obtener los conteos ---
  Future<Map<String, int>> obtenerConteoInteracciones(String hechoId) async {
    return await _repository.obtenerConteoInteracciones(hechoId);
  }

  // --- NUEVO: Puente para obtener un único hecho actualizado ---
  Future<HechoModel?> obtenerHechoPorId(String id) async {
    try {
      // Llamamos al repositorio que ya tiene la lógica del JOIN con usuarios
      return await _repository.obtenerHechoPorId(id);
    } catch (e) {
      _mensajeError = 'Error al refrescar el reporte: $e';
      notifyListeners();
      return null;
    }
  }
}
