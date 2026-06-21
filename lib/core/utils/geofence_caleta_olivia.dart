import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geocerca (Geofencing) del ejido urbano de Caleta Olivia.
///
/// Pedido del Sprint Review 3: "Diseñar un polígono de control (Geofencing)
/// para Caleta Olivia. Si el usuario sale del área, notificarle y bloquear
/// la publicación".
///
/// El polígono de abajo es una APROXIMACIÓN generosa del ejido urbano.
/// Para producción, reemplazá los vértices por el límite municipal real
/// (podés trazarlo sobre Google Maps y copiar las coordenadas).
/// El orden de los vértices puede ser horario o antihorario; el algoritmo
/// de "ray casting" funciona igual en ambos casos.

/// Centro aproximado de la ciudad (fallback cuando no hay GPS).
const LatLng kCentroCaletaOlivia = LatLng(-46.4389, -67.5191);

/// Vértices que delimitan el área permitida para crear reportes.
/// (latitud, longitud)
const List<LatLng> kPoligonoCaletaOlivia = [
  LatLng(-46.405, -67.560), // NO
  LatLng(-46.405, -67.490), // NE (hacia la costa)
  LatLng(-46.430, -67.475), // E
  LatLng(-46.470, -67.490), // SE
  LatLng(-46.475, -67.540), // SO
  LatLng(-46.445, -67.565), // O
];

/// Devuelve `true` si el [punto] cae dentro del ejido urbano de Caleta Olivia.
///
/// Usa el algoritmo de ray casting (par/impar de cruces). Es O(n) sobre los
/// vértices del polígono y no requiere ninguna librería externa.
bool estaDentroDeCaletaOlivia(
  LatLng punto, {
  List<LatLng> poligono = kPoligonoCaletaOlivia,
}) {
  bool dentro = false;
  int j = poligono.length - 1;

  for (int i = 0; i < poligono.length; i++) {
    final double xi = poligono[i].longitude;
    final double yi = poligono[i].latitude;
    final double xj = poligono[j].longitude;
    final double yj = poligono[j].latitude;

    final bool cruza =
        ((yi > punto.latitude) != (yj > punto.latitude)) &&
        (punto.longitude < (xj - xi) * (punto.latitude - yi) / (yj - yi) + xi);

    if (cruza) dentro = !dentro;
    j = i;
  }

  return dentro;
}
