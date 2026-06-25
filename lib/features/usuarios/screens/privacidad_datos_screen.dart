import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';

class PrivacidadDatosScreen extends StatefulWidget {
  final AuthController authController; // 🔥 NUEVO: Recibimos el controlador

  const PrivacidadDatosScreen({super.key, required this.authController});

  @override
  State<PrivacidadDatosScreen> createState() => _PrivacidadDatosScreenState();
}

class _PrivacidadDatosScreenState extends State<PrivacidadDatosScreen> {
  bool _gpsHabilitado = false;
  bool _verificandoPermisos = true;
  bool _eliminandoCuenta = false; // 🔥 NUEVO: Estado de carga para el botón

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
  }

  Future<void> _verificarPermisos() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (mounted) {
      setState(() {
        _gpsHabilitado =
            serviceEnabled &&
            (permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse);
        _verificandoPermisos = false;
      });
    }
  }

  Future<void> _gestionarPermisoGPS(bool valor) async {
    await Geolocator.openAppSettings();
  }

  void _solicitarDescargaDatos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Se ha enviado un enlace de descarga a tu correo electrónico.',
        ),
        backgroundColor: AppColors.exito,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  Future<void> _procesarEliminacionCuenta(BuildContext modalContext) async {
    // Cerramos el modal primero
    Navigator.pop(modalContext);

    setState(() => _eliminandoCuenta = true);

    final exito = await widget.authController.eliminarCuenta();

    if (!mounted) return;
    setState(() => _eliminandoCuenta = false);

    if (exito) {
      // La sesión ya se cerró. Volvemos a la raíz (el mapa, en modo anónimo).
      // popUntil saca de la pila Perfil y Privacidad; el mensaje se muestra
      // con el messenger de la app, que sobrevive al pop.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta eliminada correctamente. Tus reportes ahora son anónimos.',
          ),
          backgroundColor: AppColors.exito,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al intentar eliminar la cuenta.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _mostrarAdvertenciaEliminacion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !_eliminandoCuenta, // Bloquear cierre si está cargando
      builder: (modalContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red[600],
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¿Eliminar tu cuenta?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[900],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Esta acción es irreversible. Se borrarán tus medallas, tu reputación y tu información personal. Tus reportes permanecerán anónimos para no afectar el mapa de la comunidad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _eliminandoCuenta
                          ? null
                          : () => Navigator.pop(modalContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey[300]!, width: 2),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      // 🔥 CONECTAMOS EL BOTÓN AL MÉTODO
                      onPressed: _eliminandoCuenta
                          ? null
                          : () => _procesarEliminacionCuenta(modalContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sí, Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.blueGrey,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacidad y Datos',
          style: TextStyle(
            color: Colors.blueGrey[900],
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECCIÓN 1: TRANSPARENCIA ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.azulPrimario.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.azulPrimario.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        color: AppColors.azulPrimario,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nuestro Compromiso',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.azulPrimario,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RadarCO utiliza tu ubicación únicamente para posicionar los reportes en el mapa. Nunca vendemos tu información personal a terceros.',
                              style: TextStyle(
                                color: Colors.blueGrey[700],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- SECCIÓN 2: PERMISOS ---
                Text(
                  'PERMISOS DEL DISPOSITIVO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey[600],
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: Colors.blueGrey[700],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Servicios de Ubicación',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey[900],
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Requerido para crear reportes',
                          style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: _verificandoPermisos
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: _gpsHabilitado,
                                onChanged: _gestionarPermisoGPS,
                                activeColor: AppColors.azulPrimario,
                                activeTrackColor: AppColors.azulPrimario
                                    .withOpacity(0.2),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- SECCIÓN 3: GESTIÓN DE DATOS ---
                Text(
                  'TUS DATOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey[600],
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.download_rounded,
                            color: Colors.blueGrey[700],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Descargar mi información',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey[900],
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Obtén una copia de todos tus reportes',
                          style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.blueGrey[300],
                          size: 14,
                        ),
                        onTap: _solicitarDescargaDatos,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // --- SECCIÓN 4: DANGER ZONE ---
                Text(
                  'ZONA PELIGROSA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.red[700],
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _mostrarAdvertenciaEliminacion,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.red[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Eliminar mi cuenta',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red[700],
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Borrar permanentemente todos tus datos',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // OVERLAY DE CARGA (Bloquea la pantalla mientras se procesa la eliminación)
          if (_eliminandoCuenta)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Borrando cuenta...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
