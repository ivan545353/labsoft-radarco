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
  String _tipoSeleccionado = 'problema';
  bool _obteniendoUbicacion = true;
  Position? _posicionActual;

  @override
  void initState() {
    super.initState();
    _capturarUbicacionConPermisos();
  }

  // --- LA MAGIA ESTÁ AQUÍ: Pedimos permiso antes de buscar el GPS ---
  Future<void> _capturarUbicacionConPermisos() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) throw Exception('El GPS está apagado.');

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          throw Exception('Permiso de ubicación denegado.');
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        throw Exception('Permisos denegados permanentemente en los ajustes.');
      }

      // Si todo está bien, obtenemos la posición
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
        Navigator.pop(context); // Cerramos el panel
        // AHORA SÍ LE AVISAMOS AL USUARIO POR QUÉ SE CERRÓ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No podemos crear el reporte: $e'),
            backgroundColor: AppColors.problema,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 20),
          const Text(
            '¿Qué quieres reportar?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Selector de Tipo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTipoIcon(Icons.warning, 'problema', Colors.red),
              _buildTipoIcon(Icons.info, 'alerta', Colors.orange),
              _buildTipoIcon(Icons.check_circle, 'positivo', Colors.green),
              _buildTipoIcon(Icons.group, 'comunitario', Colors.blue),
            ],
          ),

          const SizedBox(height: 30),

          // Estado de la Ubicación
          ListTile(
            leading: Icon(
              Icons.location_on,
              color: _obteniendoUbicacion
                  ? Colors.grey
                  : AppColors.azulPrimario,
            ),
            title: Text(
              _obteniendoUbicacion
                  ? 'Calculando coordenadas...'
                  : 'Ubicación fijada con éxito',
            ),
            subtitle: _posicionActual != null
                ? Text(
                    'Lat: ${_posicionActual!.latitude.toStringAsFixed(4)}\nLng: ${_posicionActual!.longitude.toStringAsFixed(4)}',
                  )
                : null,
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: (_obteniendoUbicacion || widget.controller.estaCargando)
                ? null
                : _enviarReporte,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azulPrimario,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: widget.controller.estaCargando
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Publicar Reporte',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoIcon(IconData icon, String tipo, Color color) {
    bool seleccionado = _tipoSeleccionado == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: seleccionado ? color : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: seleccionado ? color : Colors.grey),
      ),
    );
  }

  void _enviarReporte() async {
    final nuevoHecho = HechoModel(
      id: '', // Supabase lo genera
      ciudadanoId: widget.ciudadanoId,
      tipoHecho: _tipoSeleccionado,
      latitud: _posicionActual!.latitude,
      longitud: _posicionActual!.longitude,
      fotoUrl: 'https://via.placeholder.com/150', // Mock de foto
      estado: 'activo',
      creadoEn: DateTime.now(),
    );

    final exito = await widget.controller.publicarNuevoHecho(nuevoHecho);

    if (mounted && exito) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reporte publicado en Caleta Olivia!'),
          backgroundColor: AppColors.exito,
        ),
      );
    }
  }
}
