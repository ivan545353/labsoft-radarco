import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:exif/exif.dart';

/// Resultado de leer los metadatos EXIF de una foto.
///
/// IMPORTANTE (decisión del plan, puntos 3 y 4): el EXIF es una SEÑAL de
/// confianza, NO una prueba. Puede venir ausente (galería que lo stripea,
/// foto reenviada por WhatsApp) o incluso falsificado. Lo usamos para subir
/// o bajar la confianza del reporte, nunca como certificación absoluta.
class ResultadoExif {
  /// Se pudo leer al menos un bloque de metadatos EXIF.
  final bool tieneExif;

  /// Coordenadas embebidas en la foto (si las hubiera).
  final double? gpsLat;
  final double? gpsLng;

  /// Fecha/hora de captura original (DateTimeOriginal).
  final DateTime? fechaOriginal;

  /// Marca y modelo del dispositivo que tomó la foto (si están).
  final String? make;
  final String? model;

  const ResultadoExif({
    required this.tieneExif,
    this.gpsLat,
    this.gpsLng,
    this.fechaOriginal,
    this.make,
    this.model,
  });

  /// Constructor para "no se pudo leer / sin metadatos".
  const ResultadoExif.vacio()
    : tieneExif = false,
      gpsLat = null,
      gpsLng = null,
      fechaOriginal = null,
      make = null,
      model = null;

  bool get tieneGps => gpsLat != null && gpsLng != null;
  bool get tieneFecha => fechaOriginal != null;

  /// ¿La foto tiene más de [horas] horas de antigüedad? (punto 5)
  /// Si no hay fecha en el EXIF, devuelve null (no verificable).
  bool? esMasViejaQue({int horas = 24}) {
    if (fechaOriginal == null) return null;
    return DateTime.now().difference(fechaOriginal!).inHours > horas;
  }

  @override
  String toString() =>
      'ResultadoExif(tieneExif: $tieneExif, gps: ($gpsLat, $gpsLng), '
      'fecha: $fechaOriginal, make: $make, model: $model)';
}

/// Servicio puro de lectura de EXIF. No depende de Supabase ni de la UI.
class ExifFotoService {
  /// Lee los metadatos EXIF relevantes de un archivo de imagen.
  /// Nunca lanza: ante cualquier problema devuelve [ResultadoExif.vacio].
  static Future<ResultadoExif> leerDesdeArchivo(File archivo) async {
    try {
      final bytes = await archivo.readAsBytes();
      final datos = await readExifFromBytes(bytes);

      if (datos.isEmpty) return const ResultadoExif.vacio();

      final lat = _gradosDesdeGps(
        datos['GPS GPSLatitude'],
        datos['GPS GPSLatitudeRef'],
      );
      final lng = _gradosDesdeGps(
        datos['GPS GPSLongitude'],
        datos['GPS GPSLongitudeRef'],
      );
      // (0,0) = "isla nula": Android lo devuelve así cuando redacta la
      // ubicación. No es una coordenada real -> lo tratamos como ausente.
      double? latFinal = lat;
      double? lngFinal = lng;
      if (latFinal != null &&
          lngFinal != null &&
          latFinal.abs() < 0.0001 &&
          lngFinal.abs() < 0.0001) {
        latFinal = null;
        lngFinal = null;
      }
      final fecha = _parseFechaExif(
        datos['EXIF DateTimeOriginal'] ?? datos['Image DateTime'],
      );

      final make = _limpiar(datos['Image Make']?.printable);
      final model = _limpiar(datos['Image Model']?.printable);

      return ResultadoExif(
        tieneExif: true,
        gpsLat: latFinal, // 👈 antes: lat
        gpsLng: lngFinal, // 👈 antes: lng
        fechaOriginal: fecha,
        make: make,
        model: model,
      );
    } catch (e) {
      debugPrint('ExifFotoService: no se pudo leer EXIF -> $e');
      return const ResultadoExif.vacio();
    }
  }

  // --- Helpers privados ---

  /// Convierte la terna GPS (grados, minutos, segundos en ratios) a decimal.
  static double? _gradosDesdeGps(IfdTag? coord, IfdTag? ref) {
    if (coord == null) return null;
    try {
      final valores = coord.values.toList();
      if (valores.length < 3) return null;

      double aDouble(dynamic ratio) {
        // Cada valor es un Ratio con numerator/denominator.
        final num n = ratio.numerator as num;
        final num d = ratio.denominator as num;
        if (d == 0) return 0;
        return n / d;
      }

      final grados =
          aDouble(valores[0]) +
          aDouble(valores[1]) / 60.0 +
          aDouble(valores[2]) / 3600.0;

      final refStr = (ref?.printable ?? '').trim().toUpperCase();
      // S y W son negativos en notación decimal.
      if (refStr == 'S' || refStr == 'W') return -grados;
      return grados;
    } catch (_) {
      return null;
    }
  }

  /// Parsea "YYYY:MM:DD HH:MM:SS" (formato estándar de DateTimeOriginal).
  static DateTime? _parseFechaExif(IfdTag? tag) {
    if (tag == null) return null;
    try {
      final s = tag.printable.trim();
      final partes = s.split(' ');
      if (partes.length != 2) return null;

      final fecha = partes[0].split(':'); // [YYYY, MM, DD]
      final hora = partes[1].split(':'); // [HH, MM, SS]
      if (fecha.length != 3 || hora.length != 3) return null;

      return DateTime(
        int.parse(fecha[0]),
        int.parse(fecha[1]),
        int.parse(fecha[2]),
        int.parse(hora[0]),
        int.parse(hora[1]),
        int.parse(hora[2]),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _limpiar(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}
