import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaPrincipalScreen extends StatefulWidget {
  const MapaPrincipalScreen({super.key});

  @override
  State<MapaPrincipalScreen> createState() => _MapaPrincipalScreenState();
}

class _MapaPrincipalScreenState extends State<MapaPrincipalScreen> {
  int _indiceTabActual = 0;
  final AuthController _authController = AuthController();

  // --- LAZY LOGIN ---
  void _verificarAccesoCiudadano(VoidCallback accionPermitida) {
    final sesionActual = Supabase.instance.client.auth.currentSession;
    if (sesionActual == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      accionPermitida();
    }
  }

  // --- LAS 4 PANTALLAS PRINCIPALES ---
  Widget get _vistaMapa => const _VistaMapaInteractiva();
  Widget get _vistaComunidad => const _VistaComunidadFeed();
  Widget get _vistaActividad =>
      const _VistaActividadNotificaciones(); // NUEVA VISTA
  Widget get _vistaPerfil => const _VistaPerfilUsuario();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData ? snapshot.data!.session : null;
        final bool estaLogueado = session != null;

        // Lista actualizada a 4 vistas
        final List<Widget> vistas = [
          _vistaMapa,
          _vistaComunidad,
          _vistaActividad,
          _vistaPerfil,
        ];

        return Scaffold(
          extendBodyBehindAppBar: true,

          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.8),
            elevation: 0,

            // centrar horizontalmente el logo
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [SvgPicture.asset('assets/logo.svg', height: 70)],
            ),
            actions: [
              if (estaLogueado)
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.problema),
                  onPressed: () async {
                    await _authController.cerrarSesion();
                    setState(() => _indiceTabActual = 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada')),
                    );
                  },
                )
              else
                TextButton(
                  onPressed: () => _verificarAccesoCiudadano(() {}),
                  child: const Text(
                    'Ingresar',
                    style: TextStyle(
                      color: AppColors.azulPrimario,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          // --- CUERPO ANIMADO ---
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_indiceTabActual),
              child: vistas[_indiceTabActual],
            ),
          ),

          // --- BOTÓN FLOTANTE (Oculto en Actividad y Perfil) ---
          floatingActionButton: (_indiceTabActual == 0 || _indiceTabActual == 1)
              ? FloatingActionButton(
                  onPressed: () {
                    _verificarAccesoCiudadano(() {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Abriendo cámara para nuevo reporte...',
                          ),
                        ),
                      );
                    });
                  },
                  backgroundColor: AppColors.azulPrimario,
                  elevation: 8,
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

          // --- BOTTOM NAVIGATION BAR ---
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: BottomNavigationBar(
                currentIndex: _indiceTabActual,
                onTap: (index) {
                  // Comunidad (1), Actividad (2) y Perfil (3) requieren login
                  if (index == 1 || index == 2 || index == 3) {
                    _verificarAccesoCiudadano(() {
                      setState(() => _indiceTabActual = index);
                    });
                  } else {
                    // Mapa (0) es libre
                    setState(() => _indiceTabActual = index);
                  }
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppColors.azulPrimario,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map),
                    label: 'Explorar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dynamic_feed),
                    label: 'Comunidad',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications_none),
                    label: 'Actividad',
                  ), // Vuelve la campanita
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SUB-WIDGETS DE VISTAS
// ============================================================================

class _VistaMapaInteractiva extends StatefulWidget {
  const _VistaMapaInteractiva();

  @override
  State<_VistaMapaInteractiva> createState() => _VistaMapaInteractivaState();
}

class _VistaMapaInteractivaState extends State<_VistaMapaInteractiva> {
  // Coordenadas centrales de Caleta Olivia
  static const CameraPosition _puntoInicial = CameraPosition(
    target: LatLng(-46.44194444, -67.5175),
    zoom: 14.0,
  );

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _puntoInicial,
      mapType: MapType.normal,
      myLocationEnabled: true, // Muestra el punto azul del usuario
      myLocationButtonEnabled: false, // Lo manejaremos con nuestra propia UI
      zoomControlsEnabled: false, // Diseño más limpio
      // Aquí es donde pintaremos los reportes de la base de datos
      markers: {
        Marker(
          markerId: const MarkerId('mock_urgente'),
          position: const LatLng(-46.4410, -67.5250),
          infoWindow: const InfoWindow(
            title: 'Bache Urgente',
            snippet: 'Reportado hace 2 horas',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
      onMapCreated: (GoogleMapController controller) {
        // Aquí puedes guardar el controlador para mover la cámara luego
      },
    );
  }
}

class _VistaComunidadFeed extends StatelessWidget {
  const _VistaComunidadFeed();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondoGeneral,
      child: const Center(
        child: Text(
          'Feed de la Comunidad\n(Aquí irán las tarjetas de reportes)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// NUEVO PLACEHOLDER PARA ACTIVIDAD
class _VistaActividadNotificaciones extends StatelessWidget {
  const _VistaActividadNotificaciones();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondoGeneral,
      child: const Center(
        child: Text(
          'Actividad y Notificaciones\n(Actualizaciones de tus reportes y medallas)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _VistaPerfilUsuario extends StatelessWidget {
  const _VistaPerfilUsuario();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fondoGeneral,
      child: const Center(
        child: Text(
          'Perfil del Ciudadano\n(Puntos, Medallas y Ajustes)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
