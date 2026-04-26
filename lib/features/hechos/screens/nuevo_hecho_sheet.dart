import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../controllers/hechos_controller.dart';

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
  String _tipoSeleccionado = 'problema';
  final TextEditingController _descripcionController = TextEditingController();
  LatLng? _posicionActual;
  String? _errorDescripcion;

  // NUEVO: Variables para la cámara
  File? _imagenSeleccionada;
  bool _subiendoDatos = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _posicionActual = LatLng(position.latitude, position.longitude);
      });
    }
  }

  // NUEVO: Método para abrir la cámara o galería
  Future<void> _seleccionarImagen() async {
    // Te damos la opción de abrir la cámara (ideal para teléfono real)
    // o la galería (ideal para probar en el emulador)
    final XFile? imagenEscogida = await _picker.pickImage(
      source: ImageSource
          .camera, // Cambia a ImageSource.gallery si prefieres probar fotos guardadas
      imageQuality:
          70, // Comprimimos al 70% para ahorrar datos y no saturar la memoria
      maxWidth: 1024,
    );

    if (imagenEscogida != null && mounted) {
      setState(() {
        _imagenSeleccionada = File(imagenEscogida.path);
        // Si había error visual de falta de foto, lo limpiamos
      });
    }
  }

  // NUEVO: Método para subir la foto a Supabase Storage
  Future<String?> _subirImagenASupabase(File archivoImagen) async {
    try {
      final supabase = Supabase.instance.client;
      // Creamos un nombre único basado en el tiempo para no sobreescribir fotos
      final extension = archivoImagen.path.split('.').last;
      final nombreArchivo =
          '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final rutaArchivo =
          '${widget.ciudadanoId}/$nombreArchivo'; // Organizamos por carpetas de usuario

      // Subimos al bucket 'fotos_hechos'
      await supabase.storage
          .from('fotos_hechos')
          .upload(rutaArchivo, archivoImagen);

      // Obtenemos la URL pública para guardarla en la tabla de PostgreSQL
      final urlPublica = supabase.storage
          .from('fotos_hechos')
          .getPublicUrl(rutaArchivo);
      return urlPublica;
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      return null;
    }
  }

  void _enviarReporte() async {
    final textoDescripcion = _descripcionController.text.trim();

    // 1. Validar que haya descripción
    if (textoDescripcion.isEmpty) {
      setState(
        () => _errorDescripcion =
            'Por favor, describe el hecho para la comunidad.',
      );
      return;
    }

    // 2. Validar que haya tomado una foto (HU1.1 obliga a subir foto)
    if (_imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes adjuntar una foto del reporte.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Validar ubicación
    if (_posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buscando tu ubicación... intenta de nuevo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _subiendoDatos = true);

    // 4. Subir imagen primero
    final urlFotoReal = await _subirImagenASupabase(_imagenSeleccionada!);

    if (urlFotoReal == null) {
      setState(() => _subiendoDatos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir la foto. Intenta nuevamente.'),
            backgroundColor: AppColors.problema,
          ),
        );
      }
      return;
    }

    // 5. Crear el modelo con la URL real
    final nuevoHecho = HechoModel(
      id: '',
      ciudadanoId: widget.ciudadanoId,
      tipoHecho: _tipoSeleccionado,
      latitud: _posicionActual!.latitude,
      longitud: _posicionActual!.longitude,
      fotoUrl: urlFotoReal, // ¡Mágia conectada!
      estado: 'activo',
      creadoEn: DateTime.now(),
      descripcion: textoDescripcion,
    );

    // 6. Enviar a base de datos
    final exito = await widget.controller.publicarNuevoHecho(nuevoHecho);

    if (!mounted) return;
    setState(() => _subiendoDatos = false);

    if (exito) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reporte publicado con éxito!'),
          backgroundColor: AppColors.exito,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.mensajeError ?? 'Error al publicar'),
          backgroundColor: AppColors.problema,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.fondoGeneral,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'NUEVO REPORTE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.azulPrimario,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // --- ZONA DE CÁMARA INTERACTIVA ---
              GestureDetector(
                onTap: _subiendoDatos ? null : _seleccionarImagen,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _imagenSeleccionada == null
                          ? AppColors.azulPrimario.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _imagenSeleccionada != null
                        ? Image.file(
                            _imagenSeleccionada!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ) // Muestra la foto tomada
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: AppColors.azulPrimario.withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toca para tomar una foto',
                                style: TextStyle(
                                  color: Colors.blueGrey[400],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // CATEGORÍAS
              Text(
                'CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoriaChip(
                      label: 'Problema',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.problema,
                      isSelected: _tipoSeleccionado == 'problema',
                      onTap: () =>
                          setState(() => _tipoSeleccionado = 'problema'),
                    ),
                    const SizedBox(width: 8),
                    _CategoriaChip(
                      label: 'Alerta',
                      icon: Icons.error_outline,
                      color: AppColors.alerta,
                      isSelected: _tipoSeleccionado == 'alerta',
                      onTap: () => setState(() => _tipoSeleccionado = 'alerta'),
                    ),
                    const SizedBox(width: 8),
                    _CategoriaChip(
                      label: 'Positivo',
                      icon: Icons.thumb_up_alt_outlined,
                      color: AppColors.exito,
                      isSelected: _tipoSeleccionado == 'positivo',
                      onTap: () =>
                          setState(() => _tipoSeleccionado = 'positivo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // DESCRIPCIÓN CON VALIDACIÓN VISUAL
              Text(
                'DESCRIPCIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _errorDescripcion != null
                        ? Colors.red
                        : Colors.grey[200]!,
                    width: _errorDescripcion != null ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _descripcionController,
                  maxLines: 4,
                  onChanged: (valor) {
                    if (_errorDescripcion != null)
                      setState(() => _errorDescripcion = null);
                  },
                  decoration: InputDecoration(
                    hintText:
                        '¿Qué estás viendo? Danos algunos detalles para el equipo de la ciudad...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_errorDescripcion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    _errorDescripcion!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // BOTÓN PUBLICAR CON ESTADO DE CARGA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _subiendoDatos ? null : _enviarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.azulPrimario.withOpacity(0.5),
                  ),
                  child: _subiendoDatos
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Publicar Reporte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
}

// ... Mantén tu widget privado _CategoriaChip idéntico al final del archivo ...
class _CategoriaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoriaChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
