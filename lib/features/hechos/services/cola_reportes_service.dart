import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reporte_pendiente.dart';

/// Cola local persistente de reportes creados sin conexión.
/// Guarda la metadata en Hive y la imagen como archivo en el dir de la app.
class ColaReportesService {
  ColaReportesService._();

  static const String _boxName = 'reportes_pendientes';
  static Box<String>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  static String _generarId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(0x7fffffff);
    return '${ts}_$r';
  }

  /// Copia la foto a un directorio persistente y encola el reporte.
  static Future<ReportePendiente> encolar({
    required String categoriaNombre,
    required String tipoBackend,
    required String descripcionFinal,
    required double latitud,
    required double longitud,
    required String origenFoto,
    required File imagenOriginal,
    required DateTime capturadoEn,
  }) async {
    final id = _generarId();

    final dirDocs = await getApplicationDocumentsDirectory();
    final dirOffline = Directory('${dirDocs.path}/reportes_offline');
    if (!await dirOffline.exists()) {
      await dirOffline.create(recursive: true);
    }
    final destino = '${dirOffline.path}/$id.jpg';
    await imagenOriginal.copy(destino);

    final reporte = ReportePendiente(
      id: id,
      categoriaNombre: categoriaNombre,
      tipoBackend: tipoBackend,
      descripcionFinal: descripcionFinal,
      latitud: latitud,
      longitud: longitud,
      origenFoto: origenFoto,
      imagenPath: destino,
      capturadoEn: capturadoEn,
      encoladoEn: DateTime.now(),
    );

    await _box?.put(id, reporte.toJsonString());
    return reporte;
  }

  static List<ReportePendiente> obtenerTodos() {
    final box = _box;
    if (box == null) return [];
    final lista = box.values
        .map((s) => ReportePendiente.fromJsonString(s))
        .toList();
    lista.sort((a, b) => a.encoladoEn.compareTo(b.encoladoEn));
    return lista;
  }

  static List<ReportePendiente> obtenerPendientes() =>
      obtenerTodos().where((r) => r.estado == 'pendiente').toList();

  static int get cantidadPendientes => obtenerPendientes().length;

  static Future<void> actualizar(ReportePendiente r) async {
    await _box?.put(r.id, r.toJsonString());
  }

  static Future<void> eliminar(ReportePendiente r) async {
    await _box?.delete(r.id);
    try {
      final f = File(r.imagenPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('No se pudo borrar imagen offline: $e');
    }
  }
}
