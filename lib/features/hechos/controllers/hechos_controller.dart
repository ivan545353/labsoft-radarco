import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hecho_model.dart';
import '../repositories/hechos_repository.dart';

class HechosController extends ChangeNotifier {
  final HechosRepository _repository = HechosRepository();

  // --- ESTADOS ---
  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  List<HechoModel> _hechosActivos = [];
  List<HechoModel> get hechosActivos => _hechosActivos;

  // Esta es la colección de pines que Google Maps necesita
  Set<Marker> _marcadores = {};
  Set<Marker> get marcadores => _marcadores;

  // --- ACCIONES ---

  // 1. Descargar reportes y convertirlos en marcadores
  Future<void> cargarHechos() async {
    _estaCargando = true;
    _mensajeError = null;
    notifyListeners(); // Avisa a la pantalla que muestre un indicador de carga

    try {
      _hechosActivos = await _repository.obtenerHechosActivos();
      _generarMarcadores();
    } catch (e) {
      _mensajeError = 'No se pudieron cargar los reportes: $e';
    } finally {
      _estaCargando = false;
      notifyListeners(); // Avisa a la pantalla que dibuje los pines
    }
  }

  // 2. Lógica interna: Traducir datos de BD a Gráficos de Mapa
  void _generarMarcadores() {
    _marcadores.clear();

    for (var hecho in _hechosActivos) {
      // Asignamos colores según el esquema que definiste en la BD
      double colorPin = BitmapDescriptor.hueRed; // 'problema' por defecto

      if (hecho.tipoHecho == 'alerta') {
        colorPin = BitmapDescriptor.hueOrange;
      } else if (hecho.tipoHecho == 'positivo' ||
          hecho.tipoHecho == 'comunitario') {
        colorPin = BitmapDescriptor.hueGreen;
      }

      _marcadores.add(
        Marker(
          markerId: MarkerId(hecho.id),
          position: LatLng(hecho.latitud, hecho.longitud),
          icon: BitmapDescriptor.defaultMarkerWithHue(colorPin),
          infoWindow: InfoWindow(
            title: hecho.tipoHecho.toUpperCase(),
            snippet:
                'Estado: ${hecho.estado}', // Podríamos mostrar la fecha aquí
          ),
        ),
      );
    }
  }

  // 3. Crear un nuevo reporte (Preparando el terreno para el botón +)
  Future<bool> publicarNuevoHecho(HechoModel nuevoHecho) async {
    _estaCargando = true;
    notifyListeners();

    try {
      await _repository.crearHecho(nuevoHecho);
      // Si se guardó con éxito, recargamos el mapa para ver el nuevo pin
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
