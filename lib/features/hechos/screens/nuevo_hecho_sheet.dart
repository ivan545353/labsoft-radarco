import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../controllers/hechos_controller.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
        });
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
        _errorFormulario = null;
      });
    }
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
    if (_posicionActual == null) {
      setState(() => _errorFormulario = 'Esperando ubicación GPS...');
      return;
    }

    setState(() {
      _subiendoDatos = true;
      _errorFormulario = null;
    });

    try {
      // --- 🛑 INTERCEPTOR DE DUPLICADOS TEMPORALMENTE DESACTIVADO PARA PRUEBAS ---
      /*
      final hechoOriginal = widget.controller.detectarDuplicado(
        _categoriaSeleccionada!.tipoBackend,
        _posicionActual!.latitude,
        _posicionActual!.longitude,
      );

      if (hechoOriginal != null) {
        await widget.controller.enviarInteraccion(hechoOriginal.id, 'sigue_pasando');
        await widget.controller.cargarHechos();

        if (!mounted) return;
        setState(() => _subiendoDatos = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '📍 ¡Aviso fusionado! Alguien ya reportó esto cerca.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.azulPrimario,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return; 
      }
      */
      // ------------------------------------------------------------------------

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
        latitud: _posicionActual!.latitude,
        longitud: _posicionActual!.longitude,
        fotoUrl: urlFotoReal,
        estado: 'activo',
        creadoEn: DateTime.now(),
        descripcion: descripcionFinal,
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

  // --- VISTAS DE LOS 3 PASOS ---

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
          'Una imagen vale más que mil palabras. Asegúrate de mostrar claramente el reporte.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 22),
        ),
        const SizedBox(height: 24),

        // BOTÓN CÁMARA GIGANTE
        Expanded(
          child: InkWell(
            onTap: _tomarFoto,
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
                          'Tocar para abrir la cámara',
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

        // ESTATUS GPS SUTIL
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _obteniendoUbicacion
                ? Colors.orange[50]
                : AppColors.exito.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _obteniendoUbicacion
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.gps_fixed,
                      color: AppColors.exito,
                      size: 18,
                    ),
              const SizedBox(width: 8),
              Text(
                _obteniendoUbicacion
                    ? 'Obteniendo ubicación exacta...'
                    : 'Ubicación GPS fijada correctamente',
                style: TextStyle(
                  color: _obteniendoUbicacion
                      ? Colors.orange[800]
                      : AppColors.exito,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
                    'Paso $_pasoActual de 3',
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _pasoActual / 3,
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
                                : (_pasoActual == 3
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
                                    _pasoActual == 3
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
