import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerUtils {
  /// Convierte un ícono de Flutter en un BitmapDescriptor compatible con Google Maps
  static Future<BitmapDescriptor> getBytesFromIcon({
    required IconData icon,
    required Color color,
    int size = 110, // Tamaño del marcador en pixeles
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(pictureRecorder);
    final ui.Paint paint = ui.Paint()
      ..color = Colors.white.withOpacity(0.0); // Fondo transparente

    // Dibujamos un círculo de fondo para que el ícono resalte
    final Rect rect = Rect.fromLTWH(0.0, 0.0, size.toDouble(), size.toDouble());
    canvas.drawRect(rect, paint);

    // Dibujamos la sombra
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2.2,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3),
    );

    // Dibujamos el círculo de color de fondo
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2.2,
      Paint()..color = color,
    );

    // Dibujamos el ícono blanco en el centro
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size / 2, // El ícono ocupa la mitad del tamaño total
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
