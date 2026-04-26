import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/hechos_controller.dart';
import 'nuevo_hecho_sheet.dart';
import 'comunidad_feed_screen.dart';
import 'hecho_detalle_screen.dart';
import '../models/hecho_model.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../usuarios/screens/perfil_usuario_screen.dart';

class MapaPrincipalScreen extends StatefulWidget {
  const MapaPrincipalScreen({super.key});

  @override
  State<MapaPrincipalScreen> createState() => _MapaPrincipalScreenState();
}

class _MapaPrincipalScreenState extends State<MapaPrincipalScreen> {
  int _indiceTabActual = 0;
  final AuthController _authController = AuthController();
  final HechosController _hechosController = HechosController();
  final UsuarioController _usuarioController = UsuarioController();

  @override
  void dispose() {
    // Es crucial limpiar el controlador cuando la pantalla principal muera
    _hechosController.dispose();
    _usuarioController.dispose();
    super.dispose();
  }

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
  // Le pasamos el controlador prestado al mapa
  Widget get _vistaMapa =>
      _VistaMapaInteractiva(controlador: _hechosController);
  Widget get _vistaComunidad =>
      ComunidadFeedScreen(controlador: _hechosController);
  Widget get _vistaActividad => const _VistaActividadNotificaciones();
  Widget get _vistaPerfil => PerfilUsuarioScreen(
    authController: _authController,
    usuarioController: _usuarioController,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData ? snapshot.data!.session : null;
        final bool estaLogueado = session != null;

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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [SvgPicture.asset('assets/logo.svg', height: 70)],
            ),
            actions: [
              if (estaLogueado)
                SizedBox(
                  width: 60, // Contenedor del icono más ancho
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.problema),
                    onPressed: () async {
                      await _authController.cerrarSesion();
                      setState(() => _indiceTabActual = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sesión cerrada')),
                      );
                    },
                  ),
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
          //quiero que este boton flotante este un poco mas arriba
          // --- BOTÓN FLOTANTE ---
          floatingActionButton: (_indiceTabActual == 0 || _indiceTabActual == 1)
              ? Padding(
                  // ¡Este es el margen que eleva el botón!
                  // 30px suele alinearlo perfectamente con la tarjeta que está a 70px.
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: FloatingActionButton(
                    onPressed: () {
                      _verificarAccesoCiudadano(() {
                        final userId =
                            Supabase.instance.client.auth.currentUser!.id;

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => NuevoHechoSheet(
                            ciudadanoId: userId,
                            controller: _hechosController,
                          ),
                        );
                      });
                    },
                    backgroundColor: AppColors.azulPrimario,
                    elevation: 8,
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

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
                  if (index == 1 || index == 2 || index == 3) {
                    _verificarAccesoCiudadano(() {
                      setState(() => _indiceTabActual = index);
                    });
                  } else {
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
                  ),
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
  // Ahora el mapa recibe el controlador como parámetro en lugar de crearlo
  final HechosController controlador;

  const _VistaMapaInteractiva({required this.controlador});

  @override
  State<_VistaMapaInteractiva> createState() => _VistaMapaInteractivaState();
}

class _VistaMapaInteractivaState extends State<_VistaMapaInteractiva> {
  static const CameraPosition _puntoInicial = CameraPosition(
    target: LatLng(-46.4389, -67.5191),
    zoom: 14.0,
  );

  // NUEVO: Estado para saber qué pin está seleccionado
  HechoModel? _hechoSeleccionado;

  @override
  void initState() {
    super.initState();

    // Ahora el callback NO navega de golpe, sino que guarda el hecho y levanta la tarjeta
    widget.controlador.setAbrirDetalleCallback((hechoTocado) {
      setState(() {
        _hechoSeleccionado = hechoTocado;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controlador.hechosActivos.isEmpty) {
        widget.controlador.cargarHechos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controlador,
      builder: (context, child) {
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _puntoInicial,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: widget.controlador.marcadores,
              // NUEVO: Si tocan en un lugar vacío del mapa, escondemos la tarjeta
              onTap: (LatLng posicion) {
                if (_hechoSeleccionado != null) {
                  setState(() => _hechoSeleccionado = null);
                }
              },
            ),

            // Indicador de carga
            if (widget.controlador.estaCargando)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    shape: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),

            // NUEVO: LA MINI-TARJETA ANIMADA (Estilo Uber/Airbnb)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _hechoSeleccionado != null
                  ? 55
                  : -150, // Se desliza desde abajo
              left: 20,
              right: 90,
              child: _hechoSeleccionado == null
                  ? const SizedBox.shrink()
                  : _buildTarjetaPrevisualizacion(context, _hechoSeleccionado!),
            ),
          ],
        );
      },
    );
  }

  // Diseño de la Mini-Tarjeta
  Widget _buildTarjetaPrevisualizacion(BuildContext context, HechoModel hecho) {
    Color colorCategoria = hecho.tipoHecho == 'problema'
        ? Colors.red
        : hecho.tipoHecho == 'alerta'
        ? Colors.orange
        : hecho.tipoHecho == 'positivo'
        ? Colors.green
        : Colors.blue;

    return GestureDetector(
      onTap: () {
        // Al tocar esta tarjeta clara e intuitiva, AHORA SÍ vamos al detalle
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HechoDetalleScreen(hecho: hecho),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Círculo de color dinámico según la categoría
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorCategoria.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: colorCategoria),
            ),
            const SizedBox(width: 16),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hecho.tipoHecho.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: colorCategoria,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hecho.descripcion ?? 'Reporte sin descripción',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blueGrey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow
                        .ellipsis, // Pone "..." si el texto es muy largo
                  ),
                ],
              ),
            ),
            // Indicador visual de "tocar aquí"
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
