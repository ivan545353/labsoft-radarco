import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hecho_model.dart';
import '../models/reporte_pendiente.dart';
import '../repositories/hechos_repository.dart';
import 'cola_reportes_service.dart';
import 'difuminado_service.dart';

// Categorías válidas para la IA (mismas que el formulario).
const List<String> kCategoriasValidasSync = [
  'Bache',
  'Basura',
  'Luminaria',
  'Agua / Caño',
  'Accidente',
  'Obstrucción',
  'Inseguridad',
  'Otro',
];

/// Publica automáticamente los reportes guardados offline cuando vuelve la red.
/// Singleton + ChangeNotifier para que la UI escuche el conteo de pendientes.
class SincronizacionService extends ChangeNotifier {
  SincronizacionService._();
  static final SincronizacionService instancia = SincronizacionService._();

  final HechosRepository _repo = HechosRepository();
  StreamSubscription<List<ConnectivityResult>>? _subConectividad;
  bool _sincronizando = false;

  // Callback opcional para refrescar el feed/mapa tras publicar.
  Future<void> Function()? _alPublicar;

  bool get sincronizando => _sincronizando;
  int get pendientes => ColaReportesService.cantidadPendientes;

  List<ReportePendiente> get enCola => ColaReportesService.obtenerTodos();
  int get enColaTotal => enCola.length;

  // Avisar a la UI que la cola cambió (ej. tras encolar un reporte offline).
  void notificarCola() => notifyListeners();

  // Vuelve a poner un retenido como pendiente e intenta publicarlo ya.
  Future<void> reintentar(ReportePendiente r) async {
    r.estado = 'pendiente';
    r.motivoRetencion = null;
    await ColaReportesService.actualizar(r);
    notifyListeners();
    await sincronizar();
  }

  Future<void> descartar(ReportePendiente r) async {
    await ColaReportesService.eliminar(r);
    notifyListeners();
  }

  /// Arranca el servicio: intento inicial + escucha de reconexión.
  void iniciar({Future<void> Function()? alPublicar}) {
    _alPublicar = alPublicar;
    sincronizar(); // intento al abrir la app

    _subConectividad ??= Connectivity().onConnectivityChanged.listen((res) {
      if (!res.contains(ConnectivityResult.none)) {
        sincronizar(); // volvió la red: reintentamos
      }
    });
  }

  /// Recorre la cola y publica lo que pueda. Seguro ante llamadas concurrentes.
  Future<void> sincronizar() async {
    if (_sincronizando) return;

    final pend = ColaReportesService.obtenerPendientes();
    if (pend.isEmpty) return;

    // Necesitamos sesión activa (RLS) y red real.
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) return;

    _sincronizando = true;
    notifyListeners();

    // ciudadano_id real (para las notificaciones).
    String? miId;
    try {
      final u = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      miId = u['id'] as String;
    } catch (_) {
      miId = null;
    }

    int publicados = 0;
    for (final r in pend) {
      try {
        if (await _procesarUno(r, miId)) publicados++;
      } catch (e) {
        debugPrint('Sync: error con ${r.id}: $e'); // queda pendiente
      }
    }

    _sincronizando = false;
    notifyListeners();

    if (publicados > 0 && _alPublicar != null) {
      await _alPublicar!();
    }
  }

  /// Procesa un reporte. Devuelve true si se publicó (y se sacó de la cola).
  Future<bool> _procesarUno(ReportePendiente r, String? miId) async {
    final archivo = File(r.imagenPath);
    if (!await archivo.exists()) {
      await ColaReportesService.eliminar(r); // imagen perdida: descartar
      return false;
    }

    // 1) IA de plausibilidad: solo RETIENE si dice explícitamente que no.
    //    Si la IA está caída/apagada (null), no retenemos.
    final rechaza = await _iaRechaza(archivo, r.categoriaNombre);
    if (rechaza == true) {
      await _retener(
        r,
        miId,
        motivo: 'La imagen no parece un reporte urbano. Revisala y reintentá.',
        avisoTitulo: 'Un reporte quedó retenido',
        avisoMsg:
            'Tu reporte de "${r.categoriaNombre}" no se publicó: la imagen no parece un hecho urbano.',
      );
      return false;
    }

    // 2) Geocoding inverso (best-effort).
    final direccion = await _resolverDireccion(r.latitud, r.longitud);

    // 3) Subir imagen a Storage.
    final urlFoto = await _subirImagen(archivo);
    if (urlFoto == null) return false; // reintentar luego

    // 4) Insertar. El trigger del servidor controla spam/auto-duplicados.
    final hecho = HechoModel(
      id: '',
      ciudadanoId: '', // crearHecho lo resuelve desde el auth user
      tipoHecho: r.tipoBackend,
      latitud: r.latitud,
      longitud: r.longitud,
      fotoUrl: urlFoto,
      estado: 'activo',
      creadoEn: DateTime.now(),
      descripcion: r.descripcionFinal,
      origenFoto: r.origenFoto,
      direccion: direccion,
    );

    try {
      await _repo.crearHecho(hecho);
    } catch (e) {
      if (e.toString().contains('SPAM_DUP')) {
        await _retener(
          r,
          miId,
          motivo: 'Ya existe un reporte parecido muy cerca de este punto.',
          avisoTitulo: 'Un reporte quedó retenido',
          avisoMsg:
              'Tu reporte offline de "${r.categoriaNombre}" no se publicó: ya hay uno parecido cerca.',
        );
        return false;
      }
      // SPAM_RATE / SPAM_HORA / fallos transitorios: dejar pendiente.
      return false;
    }

    // 5) Éxito: aviso + sacar de la cola.
    if (miId != null) {
      await _repo.crearNotificacion(
        ciudadanoId: miId,
        titulo: 'Tu reporte offline se publicó',
        mensaje:
            'Recuperaste conexión y publicamos tu reporte de "${r.categoriaNombre}".',
        tipo: 'sistema',
        referenciaId: null,
      );
    }
    await ColaReportesService.eliminar(r);
    notifyListeners();
    return true;
  }

  Future<void> _retener(
    ReportePendiente r,
    String? miId, {
    required String motivo,
    required String avisoTitulo,
    required String avisoMsg,
  }) async {
    r.estado = 'retenido';
    r.motivoRetencion = motivo;
    await ColaReportesService.actualizar(r);
    if (miId != null) {
      try {
        await _repo.crearNotificacion(
          ciudadanoId: miId,
          titulo: avisoTitulo,
          mensaje: avisoMsg,
          tipo: 'sistema',
          referenciaId: null,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  // null = no se pudo evaluar (IA caída/apagada) -> no retener.
  Future<bool?> _iaRechaza(File archivo, String categoria) async {
    try {
      final bytes = await archivo.readAsBytes();
      final b64 = base64Encode(bytes);
      final res = await Supabase.instance.client.functions.invoke(
        'analizar-foto',
        body: {
          'imagen_base64': b64,
          'categoria_elegida': categoria,
          'categorias_validas': kCategoriasValidasSync,
        },
      );
      if (res.data is Map) {
        final m = Map<String, dynamic>.from(res.data as Map);
        return m['es_plausible'] == false;
      }
      return null;
    } catch (e) {
      debugPrint('Sync IA error: $e');
      return null;
    }
  }

  Future<String?> _resolverDireccion(double lat, double lng) async {
    try {
      final marcas = await placemarkFromCoordinates(lat, lng);
      if (marcas.isEmpty) return null;
      final p = marcas.first;
      final calle = (p.thoroughfare ?? '').trim();
      final altura = (p.subThoroughfare ?? '').trim();
      final street = (p.street ?? '').trim();
      final name = (p.name ?? '').trim();
      final principal = calle.isNotEmpty
          ? (altura.isNotEmpty ? '$calle $altura' : calle)
          : (street.isNotEmpty ? street : name);
      return principal.isEmpty ? null : principal;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _subirImagen(File imagenOriginal) async {
    try {
      // HU7.3: también censuramos los reportes offline al publicarlos.
      final imagenSegura = await DifuminadoService.difuminarRegionesSensibles(
        imagenOriginal,
      );

      final outPath = '${imagenSegura.path}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        imagenSegura.absolute.path,
        outPath,
        quality: 60,
        minWidth: 1024,
        minHeight: 1024,
      );
      final archivoFinal = result != null ? File(result.path) : imagenSegura;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_offline.jpg';
      final ruta = 'reportes/$fileName';
      await Supabase.instance.client.storage
          .from('fotos_hechos')
          .upload(ruta, archivoFinal);
      return Supabase.instance.client.storage
          .from('fotos_hechos')
          .getPublicUrl(ruta);
    } catch (e) {
      debugPrint('Sync subida error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _subConectividad?.cancel();
    super.dispose();
  }
}
