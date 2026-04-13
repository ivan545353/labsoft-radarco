import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
}
