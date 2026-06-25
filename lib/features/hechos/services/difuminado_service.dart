import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// HU7.3 — Detecta rostros/patentes (vía Edge Function) y los pixela
/// ANTES de subir. Ante cualquier fallo o si no hay nada que censurar,
/// devuelve el archivo original sin bloquear la publicación.
class DifuminadoService {
  DifuminadoService._();

  static Future<File> difuminarRegionesSensibles(File original) async {
    try {
      final bytes = await original.readAsBytes();
      final cajas = await _detectarCajas(base64Encode(bytes));
      if (cajas.isEmpty) return original;

      var imagen = img.decodeImage(bytes);
      if (imagen == null) return original;
      imagen = img.bakeOrientation(imagen); // alinear con lo que vio Gemini

      final w = imagen.width;
      final h = imagen.height;

      for (final c in cajas) {
        // Gemini: [ymin, xmin, ymax, xmax] en escala 0..1000
        int x = ((c[1] / 1000.0) * w).round();
        int y = ((c[0] / 1000.0) * h).round();
        int x2 = ((c[3] / 1000.0) * w).round();
        int y2 = ((c[2] / 1000.0) * h).round();

        // Margen de seguridad del 8% para cubrir bordes
        final mx = ((x2 - x) * 0.08).round();
        final my = ((y2 - y) * 0.08).round();
        x = (x - mx).clamp(0, w - 1);
        y = (y - my).clamp(0, h - 1);
        x2 = (x2 + mx).clamp(0, w);
        y2 = (y2 + my).clamp(0, h);

        final rw = x2 - x;
        final rh = y2 - y;
        if (rw <= 1 || rh <= 1) continue;

        _pixelarRegion(imagen, x, y, rw, rh);
      }

      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/seg_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(img.encodeJpg(imagen, quality: 90));
      return out;
    } catch (e) {
      debugPrint('Difuminado: fallo, se sube original. $e');
      return original;
    }
  }

  // Mosaico: promedia el color de cada bloque y lo rellena.
  static void _pixelarRegion(img.Image src, int x, int y, int rw, int rh) {
    final menor = rw < rh ? rw : rh;
    final paso = (menor ~/ 6) < 6 ? 6 : (menor ~/ 6); // bloque del mosaico

    for (int by = y; by < y + rh; by += paso) {
      for (int bx = x; bx < x + rw; bx += paso) {
        int r = 0, g = 0, b = 0, n = 0;
        for (int j = by; j < by + paso && j < y + rh; j++) {
          for (int i = bx; i < bx + paso && i < x + rw; i++) {
            final px = src.getPixel(i, j);
            r += px.r.toInt();
            g += px.g.toInt();
            b += px.b.toInt();
            n++;
          }
        }
        if (n == 0) continue;
        final pr = (r / n).round();
        final pg = (g / n).round();
        final pb = (b / n).round();
        for (int j = by; j < by + paso && j < y + rh; j++) {
          for (int i = bx; i < bx + paso && i < x + rw; i++) {
            src.setPixelRgb(i, j, pr, pg, pb);
          }
        }
      }
    }
  }

  static Future<List<List<num>>> _detectarCajas(String base64) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'detectar-sensible',
        body: {'imagen_base64': base64},
      );
      final data = res.data;
      if (data is Map && data['regiones'] is List) {
        return (data['regiones'] as List)
            .whereType<List>()
            .map((r) => r.map((v) => v as num).toList())
            .where((r) => r.length == 4)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('detectar-sensible error: $e');
      return [];
    }
  }
}
