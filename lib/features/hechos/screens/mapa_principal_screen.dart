import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
              mainAxisAlignment: MainAxisAlignment.center,
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

class _VistaMapaInteractiva extends StatelessWidget {
  const _VistaMapaInteractiva();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFC8E6D3),
          child: const Center(
            child: Text(
              'Mapa de Caleta Olivia',
              style: TextStyle(color: Colors.black38),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.5,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: const Icon(Icons.warning, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: const Text(
                  'URGENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
