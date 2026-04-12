import 'package:geolocator/geolocator.dart';

Future<Position> determinarPosicionActual() async {
  bool servicioHabilitado;
  LocationPermission permiso;

  // 1. Verificar si los servicios de ubicación están habilitados
  servicioHabilitado = await Geolocator.isLocationServiceEnabled();
  if (!servicioHabilitado) {
    return Future.error('Los servicios de ubicación están desactivados.');
  }

  // 2. Verificar y solicitar permisos
  permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied) {
      return Future.error('Los permisos de ubicación fueron denegados.');
    }
  }

  if (permiso == LocationPermission.deniedForever) {
    return Future.error(
      'Los permisos están denegados permanentemente. Por favor, habilítalos en los ajustes.',
    );
  }

  // 3. Obtener la posición con alta precisión
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
