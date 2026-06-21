import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../controllers/hechos_controller.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/geofence_caleta_olivia.dart';
import 'hecho_detalle_screen.dart';

class CategoriaReporte {
  final String nombre;
  final IconData icono;
  final String tipoBackend;
  final Color color;

  CategoriaReporte(this.nombre, this.icono, this.tipoBackend, this.color);
}

class NuevoHechoSheet extends StatefulWidget {
  final String ciudadanoId;
  final HechosController controller;

  const NuevoHechoSheet({
    super.key,
    required this.ciudadanoId,
    required this.controller,
  });

  @override
  State<NuevoHechoSheet> createState() => _NuevoHechoSheetState();
}

class _NuevoHechoSheetState extends State<NuevoHechoSheet> {
  final TextEditingController _descripcionController = TextEditingController();

  int _pasoActual = 1; // Controla el estado del Wizard (1, 2 o 3)

  CategoriaReporte? _categoriaSeleccionada;
  File? _imagenSeleccionada;
  Position? _posicionActual;

  // --- UBICACIÓN ELEGIDA EN EL MAPA + GEOCERCA ---
  // Por defecto apuntamos al centro de la ciudad (siempre dentro de la geocerca).
  // Si el GPS resuelve, lo movemos al punto real del usuario.
  LatLng _ubicacionElegida = kCentroCaletaOlivia;
  bool _dentroDeGeocerca = true;
  GoogleMapController? _mapController;

  // --- BÚSQUEDA POR DIRECCIÓN / CALLE ---
  final TextEditingController _busquedaController = TextEditingController();
  bool _buscandoDireccion = false;

  // --- CONFIANZA DEL DATO (Capas 1 y 2) ---
  // Origen de la foto: 'en_vivo' (cámara, en el lugar) | 'adjuntada' (galería, remoto)
  String? _origenFoto;
  // Capa 1: atestación obligatoria del usuario antes de publicar.
  bool _aceptoAtestacion = false;

  // Reporte "a distancia": el pin quedó lejos del GPS real (o no hay GPS).
  bool get _esReporteRemoto {
    if (_posicionActual == null) return true;
    final distancia = Geolocator.distanceBetween(
      _posicionActual!.latitude,
      _posicionActual!.longitude,
      _ubicacionElegida.latitude,
      _ubicacionElegida.longitude,
    );
    return distancia > 80; // metros
  }

  bool _obteniendoUbicacion = true;
  bool _subiendoDatos = false;
  String? _errorFormulario;

  // Catálogo optimizado para tarjetas de 2 columnas
  final List<CategoriaReporte> _categorias = [
    CategoriaReporte(
      'Bache',
      Icons.terrain_rounded,
      'problema',
      Colors.red[400]!,
    ),
    CategoriaReporte(
      'Basura',
      Icons.delete_outline_rounded,
      'problema',
      Colors.brown[400]!,
    ),
    CategoriaReporte(
      'Luminaria',
      Icons.lightbulb_outline_rounded,
      'problema',
      Colors.amber[600]!,
    ),
    CategoriaReporte(
      'Agua / Caño',
      Icons.water_drop_outlined,
      'problema',
      Colors.blue[400]!,
    ),
    CategoriaReporte(
      'Accidente',
      Icons.car_crash_outlined,
      'alerta',
      Colors.deepOrange[400]!,
    ),
    CategoriaReporte(
      'Obstrucción',
      Icons.block_flipped,
      'alerta',
      Colors.orange[400]!,
    ),
    CategoriaReporte(
      'Inseguridad',
      Icons.security_outlined,
      'alerta',
      Colors.purple[400]!,
    ),
    CategoriaReporte(
      'Otro',
      Icons.info_outline_rounded,
      'problema',
      Colors.blueGrey[400]!,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionGPS();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _busquedaController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- LOGICA DEL WIZARD ---
  void _avanzarPaso() {
    FocusScope.of(context).unfocus(); // Ocultar teclado al avanzar

    if (_pasoActual == 1 && _categoriaSeleccionada == null) {
      setState(
        () => _errorFormulario = 'Selecciona una categoría para continuar.',
      );
      return;
    }

    if (_pasoActual == 2 && _descripcionController.text.trim().isEmpty) {
      setState(() => _errorFormulario = 'Agrega una breve descripción.');
      return;
    }

    // Paso 3 = Ubicación. No dejamos avanzar si el pin quedó fuera del ejido.
    if (_pasoActual == 3 && !_dentroDeGeocerca) {
      setState(
        () => _errorFormulario =
            'El punto elegido está fuera del ejido urbano de Caleta Olivia. Movè el mapa dentro del área permitida.',
      );
      return;
    }

    setState(() {
      _errorFormulario = null;
      _pasoActual++;
    });
  }

  void _retrocederPaso() {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorFormulario = null;
      _pasoActual--;
    });
  }

  // --- METODOS DE DATOS ---
  Future<void> _obtenerUbicacionGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desactivado');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Permiso denegado');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _posicionActual = position;
          _obteniendoUbicacion = false;
          // Arrancamos el pin sobre la ubicación real del usuario.
          _ubicacionElegida = LatLng(position.latitude, position.longitude);
          _dentroDeGeocerca = estaDentroDeCaletaOlivia(_ubicacionElegida);
        });

        // Si el usuario ya está en el paso del mapa, lo centramos en su GPS.
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_ubicacionElegida, 16),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _obteniendoUbicacion = false;
          _errorFormulario = 'No pudimos acceder a tu ubicación exacta.';
        });
      }
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _imagenSeleccionada = File(pickedFile.path);
        _origenFoto = 'en_vivo';
        _errorFormulario = null;
      });
    }
  }

  Future<void> _elegirDeGaleria() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _imagenSeleccionada = File(pickedFile.path);
        _origenFoto = 'adjuntada';
        _errorFormulario = null;
      });
    }
  }

  // En el lugar -> cámara directa. A distancia -> dejamos elegir cámara o galería.
  void _seleccionarFoto() {
    if (!_esReporteRemoto) {
      _tomarFoto();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.azulPrimario,
              ),
              title: const Text('Tomar foto ahora'),
              onTap: () {
                Navigator.pop(context);
                _tomarFoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.azulPrimario,
              ),
              title: const Text('Elegir de la galería'),
              subtitle: const Text('Para reportar un lugar donde no estás'),
              onTap: () {
                Navigator.pop(context);
                _elegirDeGaleria();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _subirImagenASupabase(
    File imagenOriginal,
    String idUsuario,
  ) async {
    try {
      // 1. Definir ruta temporal para la imagen comprimida
      final lastIndex = imagenOriginal.absolute.path.lastIndexOf(
        RegExp(r'.jp'),
      );
      final splitted = imagenOriginal.absolute.path.substring(0, (lastIndex));
      final outPath = "${splitted}_compressed.jpg";

      // 2. Compresión Física agresiva pero sin pérdida visible de calidad
      var result = await FlutterImageCompress.compressAndGetFile(
        imagenOriginal.absolute.path,
        outPath,
        quality: 60, // Comprime la calidad a un 60% (ideal para móviles)
        minWidth: 1024, // Limita el ancho máximo para no subir 4K
        minHeight: 1024,
      );

      // Si falla la compresión, usamos la original como plan B
      File archivoFinal = result != null ? File(result.path) : imagenOriginal;

      // 3. Subir a Supabase
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$idUsuario.jpg';
      final ruta = 'reportes/$fileName';

      await Supabase.instance.client.storage
          .from('fotos_hechos')
          .upload(ruta, archivoFinal);

      return Supabase.instance.client.storage
          .from('fotos_hechos')
          .getPublicUrl(ruta);
    } catch (e) {
      debugPrint('Error subiendo imagen comprimida: $e');
      return null;
    }
  }

  void _enviarReporte() async {
    if (_categoriaSeleccionada == null) {
      setState(() => _errorFormulario = 'Por favor, selecciona una categoría.');
      return;
    }
    if (_descripcionController.text.trim().isEmpty) {
      setState(
        () => _errorFormulario = 'Agrega una breve descripción del reporte.',
      );
      return;
    }
    if (_imagenSeleccionada == null) {
      setState(() => _errorFormulario = 'Falta la foto del reporte.');
      return;
    }
    if (!_aceptoAtestacion) {
      setState(
        () => _errorFormulario =
            'Debés confirmar que la imagen corresponde al lugar marcado.',
      );
      return;
    }
    // Última barrera de seguridad: el punto elegido debe estar dentro del ejido.
    if (!estaDentroDeCaletaOlivia(_ubicacionElegida)) {
      setState(
        () => _errorFormulario =
            'El reporte está fuera del ejido urbano de Caleta Olivia.',
      );
      return;
    }

    setState(() {
      _subiendoDatos = true;
      _errorFormulario = null;
    });

    try {
      // 2. TRADUCCIÓN DE ID (Con Fallback de Seguridad RLS)
      String ciudadanoIdReal = widget.ciudadanoId;
      try {
        final usuarioData = await Supabase.instance.client
            .from('usuarios')
            .select('id')
            .eq('auth_id', widget.ciudadanoId)
            .maybeSingle();

        if (usuarioData != null) {
          ciudadanoIdReal = usuarioData['id'];
        }
      } catch (err) {
        debugPrint('Aviso: No se pudo traducir el ID. Usando original. $err');
      }

      // --- INTERCEPTOR BLANDO DE DUPLICADOS ---
      // Detección en memoria: misma categoría, < 40 m, hecho activo.
      final hechoOriginal = widget.controller.detectarDuplicado(
        _categoriaSeleccionada!.nombre,
        _ubicacionElegida.latitude,
        _ubicacionElegida.longitude,
      );

      if (hechoOriginal != null) {
        if (!mounted) return;
        setState(
          () => _subiendoDatos = false,
        ); // pausa el spinner mientras decide

        final decision = await _mostrarHojaDuplicado(hechoOriginal);

        // Canceló (tocó fuera): no hacemos nada, sus datos quedan en el formulario.
        if (decision == null) return;

        // Confirmó que es el mismo hecho -> sumamos su aporte al original.
        if (decision == 'mismo') {
          await _confirmarDuplicado(hechoOriginal, ciudadanoIdReal);
          return;
        }

        // Eligió "es un hecho distinto" -> seguimos publicando normalmente.
        if (!mounted) return;
        setState(() => _subiendoDatos = true);
      }

      // 3. SUBIR IMAGEN A STORAGE
      final urlFotoReal = await _subirImagenASupabase(
        _imagenSeleccionada!,
        ciudadanoIdReal,
      );

      if (urlFotoReal == null)
        throw Exception('Fallo la subida al Storage de imágenes de Supabase.');

      // 4. ARMAR EL MODELO DEFINITIVO
      final descripcionFinal =
          '[${_categoriaSeleccionada!.nombre}] - ${_descripcionController.text.trim()}';

      final nuevoHecho = HechoModel(
        id: '', // Se autogenera en la BD
        ciudadanoId: ciudadanoIdReal,
        tipoHecho: _categoriaSeleccionada!.tipoBackend,
        latitud: _ubicacionElegida.latitude,
        longitud: _ubicacionElegida.longitude,
        fotoUrl: urlFotoReal,
        estado: 'activo',
        creadoEn: DateTime.now(),
        descripcion: descripcionFinal,
        origenFoto: _origenFoto ?? 'en_vivo',
      );

      // 5. PUBLICAR
      final exito = await widget.controller.publicarNuevoHecho(nuevoHecho);

      if (!mounted) return;
      setState(() => _subiendoDatos = false);

      if (exito) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reporte publicado con éxito!'),
            backgroundColor: AppColors.exito,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(
          () => _errorFormulario =
              widget.controller.mensajeError ??
              'Error devuelto por el controlador.',
        );
      }
    } catch (e) {
      debugPrint('⚠️ ERROR CRÍTICO: $e');
      if (!mounted) return;
      setState(() {
        _subiendoDatos = false;
        _errorFormulario = 'DEBUG SQL: ${e.toString()}';
      });
    }
  }

  // --- INTERCEPTOR BLANDO: hoja de desambiguación ---
  // Devuelve 'mismo', 'distinto' o null (si el usuario la cierra).
  Future<String?> _mostrarHojaDuplicado(HechoModel original) async {
    final conteos = await widget.controller.obtenerConteoInteracciones(
      original.id,
    );
    final confirmaciones = conteos['sigue_pasando'] ?? 0;
    final distancia = Geolocator.distanceBetween(
      _ubicacionElegida.latitude,
      _ubicacionElegida.longitude,
      original.latitud,
      original.longitud,
    ).round();

    // Parseo de categoría y descripción del original
    final desc = original.descripcion ?? '';
    final match = RegExp(r'^\[(.*?)\] - (.*)$').firstMatch(desc);
    final categoria = match?.group(1) ?? 'Reporte';
    final descripcionLimpia = match?.group(2) ?? desc;

    final dif = DateTime.now().difference(original.creadoEn);
    final hace = dif.inDays > 0
        ? 'hace ${dif.inDays}d'
        : dif.inHours > 0
        ? 'hace ${dif.inHours}h'
        : 'hace ${dif.inMinutes}m';

    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    color: AppColors.azulPrimario,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Parece que esto ya fue reportado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Encontramos un reporte muy cerca ($distancia m). ¿Es el mismo hecho?',
                style: TextStyle(color: Colors.blueGrey[500], fontSize: 14),
              ),
              const SizedBox(height: 18),

              // Tarjeta del reporte original
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (original.fotoUrl != null &&
                        original.fotoUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: Image.network(
                          original.fotoUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 700,
                          errorBuilder: (c, e, s) => Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.azulPrimario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descripcionLimpia.isNotEmpty
                                ? descripcionLimpia
                                : 'Reporte en la zona',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 14,
                                color: Colors.blueGrey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$confirmaciones confirman · $hace',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Acción principal: es lo mismo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'mismo'),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Es lo mismo, sumar mi aporte',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Acción secundaria: es distinto
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, 'distinto'),
                  child: Text(
                    'Es un hecho distinto, publicar igual',
                    style: TextStyle(
                      color: Colors.blueGrey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // El usuario confirmó "es lo mismo": subimos su foto como evidencia,
  // sumamos su aporte al original y lo llevamos al detalle del original.
  Future<void> _confirmarDuplicado(
    HechoModel original,
    String ciudadanoIdReal,
  ) async {
    if (!mounted) return;
    setState(() => _subiendoDatos = true);

    // Subimos su foto como evidencia adjunta al original.
    final urlEvidencia = await _subirImagenASupabase(
      _imagenSeleccionada!,
      ciudadanoIdReal,
    );

    final ok = await widget.controller.confirmarComoDuplicado(
      original: original,
      ciudadanoId: ciudadanoIdReal,
      textoEvidencia: _descripcionController.text.trim(),
      fotoUrlEvidencia: urlEvidencia,
    );

    if (!mounted) return;
    setState(() => _subiendoDatos = false);

    if (!ok) {
      setState(
        () => _errorFormulario =
            widget.controller.mensajeError ?? 'No se pudo sumar tu aporte.',
      );
      return;
    }

    // Refrescamos el original para mostrar los conteos actualizados.
    final actualizado =
        await widget.controller.obtenerHechoPorId(original.id) ?? original;

    if (!mounted) return;

    // Capturamos navigator y messenger ANTES de cerrar la hoja.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.pop(); // cierra la hoja de nuevo reporte
    navigator.push(
      MaterialPageRoute(
        builder: (_) => HechoDetalleScreen(
          hecho: actualizado,
          controller: widget.controller,
        ),
      ),
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Sumaste tu aporte a este reporte. ¡Gracias por confirmar!',
        ),
        backgroundColor: AppColors.azulPrimario,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // --- LÓGICA DEL MAPA SELECTOR (UBICACIÓN REMOTA) ---

  void _recalcularGeocerca() {
    final dentro = estaDentroDeCaletaOlivia(_ubicacionElegida);
    if (dentro != _dentroDeGeocerca) {
      setState(() => _dentroDeGeocerca = dentro);
    }
  }

  Future<void> _centrarEnMiUbicacion() async {
    if (_posicionActual == null) {
      await _obtenerUbicacionGPS();
    }
    if (_posicionActual != null && _mapController != null) {
      final destino = LatLng(
        _posicionActual!.latitude,
        _posicionActual!.longitude,
      );
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(destino, 16),
      );
      _ubicacionElegida = destino;
      _recalcularGeocerca();
    }
  }

  void _mostrarAvisoBusqueda(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey[800],
      ),
    );
  }

  Future<void> _buscarDireccion() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _buscandoDireccion = true);

    try {
      // Sesgamos la búsqueda hacia la ciudad para mejorar la precisión.
      final consulta = texto.toLowerCase().contains('caleta')
          ? texto
          : '$texto, Caleta Olivia, Santa Cruz, Argentina';

      final resultados = await locationFromAddress(consulta);

      if (resultados.isEmpty) {
        _mostrarAvisoBusqueda('No encontramos esa dirección. Probá con otra.');
        return;
      }

      final r = resultados.first;
      final destino = LatLng(r.latitude, r.longitude);
      _ubicacionElegida = destino;

      // El animate dispara onCameraMove/onCameraIdle, que recalculan la geocerca.
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(destino, 17),
      );
      _recalcularGeocerca();
    } catch (e) {
      _mostrarAvisoBusqueda(
        'No pudimos buscar esa dirección. Verificá la conexión e intentá de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _buscandoDireccion = false);
    }
  }

  // --- VISTAS DE LOS 4 PASOS ---

  Widget _buildPasoUbicacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirma la ubicación',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D1E20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mové el mapa para dejar el pin justo sobre el hecho. Podés reportar un punto aunque no estés parado ahí.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 18),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _ubicacionElegida,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  // 🔧 Evita el "tironeo": el mapa reclama el gesto de arrastre
                  // de inmediato para no pelear con el bottom sheet deslizante.
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  // El pin está fijo en el centro: movemos el mapa, no el pin.
                  onCameraMove: (posicion) =>
                      _ubicacionElegida = posicion.target,
                  onCameraIdle: _recalcularGeocerca,
                ),

                // PIN FIJO CENTRAL (se eleva un poco para que la punta marque el centro)
                Padding(
                  padding: const EdgeInsets.only(bottom: 42),
                  child: Icon(
                    Icons.location_on,
                    size: 50,
                    color: _dentroDeGeocerca
                        ? AppColors.azulPrimario
                        : AppColors.problema,
                  ),
                ),

                // BUSCADOR DE DIRECCIÓN + INDICADOR DENTRO / FUERA
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Campo de búsqueda por calle / dirección
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(
                              Icons.search_rounded,
                              color: Colors.blueGrey[400],
                              size: 22,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _busquedaController,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _buscarDireccion(),
                                decoration: const InputDecoration(
                                  hintText: 'Buscar calle o dirección...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            _buscandoDireccion
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.azulPrimario,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.azulPrimario,
                                    ),
                                    onPressed: _buscarDireccion,
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // INDICADOR DENTRO / FUERA
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _dentroDeGeocerca
                              ? Colors.white
                              : AppColors.problema,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _dentroDeGeocerca
                                  ? Icons.check_circle_rounded
                                  : Icons.location_off_rounded,
                              size: 18,
                              color: _dentroDeGeocerca
                                  ? AppColors.exito
                                  : Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _dentroDeGeocerca
                                    ? 'Dentro de Caleta Olivia'
                                    : 'Fuera del área permitida',
                                style: TextStyle(
                                  color: _dentroDeGeocerca
                                      ? Colors.blueGrey[800]
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // BOTÓN "CENTRAR EN MI UBICACIÓN"
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'fab_centrar_ubicacion',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.azulPrimario,
                    elevation: 4,
                    onPressed: _centrarEnMiUbicacion,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaso1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué quieres reportar?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D1E20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona la categoría que mejor describa el problema.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 22),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // ¡Tarjetas masivas y accesibles!
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
            ),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final seleccionado = _categoriaSeleccionada == cat;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _categoriaSeleccionada = cat;
                    _errorFormulario = null;
                  });
                  // Avanza automáticamente al tocar para ser más ágil
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    _avanzarPaso,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? AppColors.azulPrimario
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: seleccionado
                          ? AppColors.azulPrimario
                          : Colors.grey[200]!,
                      width: 2,
                    ),
                    boxShadow: seleccionado
                        ? [
                            BoxShadow(
                              color: AppColors.azulPrimario.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat.icono,
                        color: seleccionado ? Colors.white : cat.color,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        cat.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: seleccionado
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: seleccionado
                              ? Colors.white
                              : Colors.blueGrey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaso2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agrega los detalles',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D1E20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Brinda información clara para que los demás vecinos lo ubiquen rápidamente.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 22),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: _descripcionController,
            maxLines: 6,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText:
                  'Ej: Pozo profundo en la esquina de la plaza principal. Hay que esquivarlo con cuidado...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                height: 1.5,
              ),
              contentPadding: const EdgeInsets.all(20),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidencia visual',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D1E20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _esReporteRemoto
              ? 'Reporte a distancia: podés tomar una foto o adjuntar una de tu galería que muestre el lugar.'
              : 'Una imagen vale más que mil palabras. Asegúrate de mostrar claramente el reporte.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 20),
        ),
        const SizedBox(height: 24),

        // BOTÓN CÁMARA / GALERÍA
        Expanded(
          child: InkWell(
            onTap: _seleccionarFoto,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _imagenSeleccionada != null
                      ? AppColors.exito
                      : Colors.blueGrey[200]!,
                  width: _imagenSeleccionada != null ? 3 : 2,
                ),
              ),
              child: _imagenSeleccionada != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_imagenSeleccionada!, fit: BoxFit.cover),
                          Container(
                            color: Colors.black38,
                          ), // Capa oscura para contraste
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tocar para cambiar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.azulPrimario,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _esReporteRemoto
                              ? 'Tocar para tomar o adjuntar una foto'
                              : 'Tocar para abrir la cámara',
                          style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SELLO DE ORIGEN DE LA FOTO (Capa 2: transparencia)
        if (_origenFoto != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _origenFoto == 'en_vivo'
                    ? Icons.photo_camera_rounded
                    : Icons.collections_rounded,
                size: 16,
                color: Colors.blueGrey[500],
              ),
              const SizedBox(width: 8),
              Text(
                _origenFoto == 'en_vivo'
                    ? 'Foto tomada en el lugar'
                    : 'Imagen adjunta (reporte a distancia)',
                style: TextStyle(
                  color: Colors.blueGrey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // CHECKBOX DE ATESTACIÓN (Capa 1: obligatorio para publicar)
        InkWell(
          onTap: () => setState(() => _aceptoAtestacion = !_aceptoAtestacion),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _aceptoAtestacion
                  ? AppColors.azulPrimario.withOpacity(0.06)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _aceptoAtestacion
                    ? AppColors.azulPrimario
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _aceptoAtestacion,
                  activeColor: AppColors.azulPrimario,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) =>
                      setState(() => _aceptoAtestacion = v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Confirmo que esta imagen corresponde al lugar que marqué en el mapa y que el reporte es verídico.',
                    style: TextStyle(
                      color: Colors.blueGrey[700],
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        margin: const EdgeInsets.only(top: kToolbarHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // HANDLE Y BARRA DE PROGRESO
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Text(
                    'Paso $_pasoActual de 4',
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _pasoActual / 4,
                      backgroundColor: Colors.grey[200],
                      color: AppColors.azulPrimario,
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CONTENIDO DINÁMICO (WIZARD)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey<int>(_pasoActual),
                          child: _pasoActual == 1
                              ? _buildPaso1()
                              : _pasoActual == 2
                              ? _buildPaso2()
                              : _pasoActual == 3
                              ? _buildPasoUbicacion()
                              : _buildPaso3(),
                        ),
                      ),
                    ),

                    // MENSAJE DE ERROR GLOBAL
                    if (_errorFormulario != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[400],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorFormulario!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // CONTROLES INFERIORES (Atrás / Continuar)
                    Row(
                      children: [
                        if (_pasoActual > 1) ...[
                          OutlinedButton(
                            onPressed: _subiendoDatos ? null : _retrocederPaso,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey[600],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _subiendoDatos
                                ? null
                                : (_pasoActual == 4
                                      ? _enviarReporte
                                      : _avanzarPaso),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.azulPrimario,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: _subiendoDatos
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    _pasoActual == 4
                                        ? 'Publicar Reporte'
                                        : 'Continuar',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
