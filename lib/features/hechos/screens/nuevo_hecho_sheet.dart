import 'package:flutter/material.dart';
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
  // Categoría por defecto: Problema
  String _tipoSeleccionado = 'problema';
  bool _obteniendoUbicacion = true;
  Position? _posicionActual;

  // Controlador para capturar lo que el usuario escribe
  final TextEditingController _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _capturarUbicacionConPermisos();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _capturarUbicacionConPermisos() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) throw Exception('El GPS está desactivado.');

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied)
          throw Exception('Permiso denegado.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _posicionActual = pos;
          _obteniendoUbicacion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de ubicación: $e'),
            backgroundColor: AppColors.problema,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 24 + bottomInset,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador del panel
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
            const SizedBox(height: 16),

            // CATEGORÍA (Diseño Stitch)
            Text(
              'CATEGORÍA DEL REPORTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),

            // Cuadrícula de categorías (2x2) para que quepan las 4
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBotonCategoria(
                  Icons.warning_rounded,
                  'Problema',
                  'problema',
                  Colors.red,
                ),
                _buildBotonCategoria(
                  Icons.thumb_up_alt_rounded,
                  'Positivo',
                  'positivo',
                  Colors.green,
                ),
                _buildBotonCategoria(
                  Icons.error_outline_rounded,
                  'Alerta',
                  'alerta',
                  Colors.orange,
                ),
                _buildBotonCategoria(
                  Icons.group_rounded,
                  'Comunitario',
                  'comunitario',
                  Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // DESCRIPCIÓN
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
                border: Border.all(color: Colors.grey[200]!),
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
                decoration: InputDecoration(
                  hintText:
                      '¿Qué estás viendo? Danos algunos detalles para el equipo de la ciudad...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // UBICACIÓN
            Text(
              'UBICACIÓN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: _obteniendoUbicacion
                        ? Colors.grey
                        : AppColors.azulPrimario,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _obteniendoUbicacion
                              ? 'Calculando coordenadas...'
                              : 'Posición detectada correctamente',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (_posicionActual != null)
                          Text(
                            '${_posicionActual!.latitude.toStringAsFixed(5)}, ${_posicionActual!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // BOTÓN PUBLICAR
            ElevatedButton.icon(
              onPressed:
                  (_obteniendoUbicacion || widget.controller.estaCargando)
                  ? null
                  : _enviarReporte,
              icon: Icon(
                widget.controller.estaCargando ? null : Icons.send_rounded,
                color: Colors.white,
              ),
              label: widget.controller.estaCargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Publicar Reporte',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulPrimario,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 5,
                shadowColor: AppColors.azulPrimario.withOpacity(0.4),
              ),
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'TU REPORTE SERÁ PÚBLICO PARA LA COMUNIDAD.',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para los botones de categoría estilo "Cápsula"
  Widget _buildBotonCategoria(
    IconData icono,
    String etiqueta,
    String valor,
    Color color,
  ) {
    bool seleccionado = _tipoSeleccionado == valor;
    return GestureDetector(
      onTap: () => setState(() => _tipoSeleccionado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? color : Colors.white,
          border: Border.all(color: seleccionado ? color : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(100),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: seleccionado ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Text(
              etiqueta,
              style: TextStyle(
                color: seleccionado ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enviarReporte() async {
    final nuevoHecho = HechoModel(
      id: '',
      ciudadanoId: widget.ciudadanoId,
      tipoHecho: _tipoSeleccionado,
      latitud: _posicionActual!.latitude,
      longitud: _posicionActual!.longitude,
      fotoUrl: 'https://via.placeholder.com/150',
      estado: 'activo',
      creadoEn: DateTime.now(),
      descripcion: _descripcionController.text
          .trim(), // Capturamos la descripción real
    );

    final exito = await widget.controller.publicarNuevoHecho(nuevoHecho);

    if (!mounted) return;

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
}
