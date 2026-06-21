import 'dart:ui';
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
import '../../notificaciones/screens/notificaciones_screen.dart';
import '../../notificaciones/controllers/notificaciones_controller.dart';

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
  final NotificacionesController _notificacionesController =
      NotificacionesController();

  @override
  void dispose() {
    _hechosController.dispose();
    _usuarioController.dispose();
    _notificacionesController.dispose();
    super.dispose();
  }

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

  Widget get _vistaMapa =>
      _VistaMapaInteractiva(controlador: _hechosController);
  Widget get _vistaComunidad =>
      ComunidadFeedScreen(controlador: _hechosController);
  Widget get _vistaActividad => NotificacionesScreen(
    controller: _notificacionesController,
    hechosController: _hechosController,
  );
  Widget get _vistaPerfil => PerfilUsuarioScreen(
    authController: _authController,
    usuarioController: _usuarioController,
    hechosController: _hechosController,
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
          extendBody: true,

          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.7),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SvgPicture.asset('assets/logo.svg', height: 45),
                ),
              ],
            ),
            actions: [
              if (estaLogueado)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () async {
                      await _authController.cerrarSesion();
                      setState(() => _indiceTabActual = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sesión cerrada exitosamente'),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: () => _verificarAccesoCiudadano(() {}),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.azulPrimario.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'Ingresar',
                      style: TextStyle(
                        color: AppColors.azulPrimario,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          body: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_indiceTabActual),
                  child: vistas[_indiceTabActual],
                ),
              ),

              // --- SMART DOCK ---
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: SafeArea(child: _buildRadarDock()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadarDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.map_rounded, 'Mapa'),
              _buildNavItem(1, Icons.dynamic_feed_rounded, 'Feed'),

              GestureDetector(
                onTap: () {
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
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: AppColors.azulPrimario,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azulPrimario.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_location_alt_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              _buildNavItem(2, Icons.notifications_rounded, 'Avisos'),
              _buildNavItem(3, Icons.person_rounded, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _indiceTabActual == index;

    Widget iconWidget = Icon(
      icon,
      color: isSelected ? AppColors.azulPrimario : Colors.blueGrey[400],
      size: 24,
    );

    if (index == 2) {
      iconWidget = ListenableBuilder(
        listenable: _notificacionesController,
        builder: (context, child) {
          return Badge(
            isLabelVisible: _notificacionesController.mostrarPuntoEnDock,
            backgroundColor: Colors.redAccent,
            smallSize: 10,
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: () {
        if (index == 1 || index == 2 || index == 3) {
          _verificarAccesoCiudadano(
            () => setState(() => _indiceTabActual = index),
          );
        } else {
          setState(() => _indiceTabActual = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.azulPrimario.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            iconWidget,
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.azulPrimario,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUB-WIDGET DEL MAPA (CON FILTROS FLOTANTES Y MINI-TARJETA)
// ============================================================================

class _VistaMapaInteractiva extends StatefulWidget {
  final HechosController controlador;

  const _VistaMapaInteractiva({required this.controlador});

  @override
  State<_VistaMapaInteractiva> createState() => _VistaMapaInteractivaState();
}

class _VistaMapaInteractivaState extends State<_VistaMapaInteractiva> {
  static const CameraPosition _puntoInicial = CameraPosition(
    target: LatLng(-46.4389, -67.5191), // Caleta Olivia
    zoom: 14.0,
  );

  HechoModel? _hechoSeleccionado;

  // --- VARIABLES DE FILTRO ---
  String _filtroEstado = 'Todos';
  // 🔥 CAMBIO CLAVE: Preseleccionamos 'Semana' por defecto
  String _filtroTiempo = 'Semana';
  String _filtroCategoria = 'Todas';

  final List<String> _categorias = [
    'Todas',
    'Bache',
    'Basura',
    'Luminaria',
    'Agua / Caño',
    'Accidente',
    'Obstrucción',
    'Inseguridad',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    widget.controlador.setAbrirDetalleCallback((hechoTocado) {
      setState(() => _hechoSeleccionado = hechoTocado);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controlador.hechosActivos.isEmpty) {
        widget.controlador.cargarHechos();
      }
    });
  }

  // --- INTELIGENCIA DE PARSEO ---
  Map<String, String> _parsearDescripcion(String descRaw, String tipoBackend) {
    final match = RegExp(r'^\[(.*?)\] - (.*)$').firstMatch(descRaw);
    if (match != null) {
      return {
        'categoria': match.group(1) ?? 'Reporte',
        'descripcion': match.group(2) ?? '',
      };
    }
    return {
      'categoria': tipoBackend == 'problema' ? 'Problema' : 'Alerta',
      'descripcion': descRaw,
    };
  }

  String _extraerCategoria(String descripcion, String tipoBackend) {
    return _parsearDescripcion(descripcion, tipoBackend)['categoria']!;
  }

  Map<String, dynamic> _getEstilosCategoria(
    String categoria,
    String tipoBackend,
  ) {
    switch (categoria) {
      case 'Bache':
        return {'icono': Icons.terrain_rounded, 'color': Colors.red[500]};
      case 'Basura':
        return {
          'icono': Icons.delete_outline_rounded,
          'color': Colors.brown[400],
        };
      case 'Luminaria':
        return {
          'icono': Icons.lightbulb_outline_rounded,
          'color': Colors.amber[600],
        };
      case 'Agua / Caño':
        return {'icono': Icons.water_drop_outlined, 'color': Colors.blue[500]};
      case 'Accidente':
        return {
          'icono': Icons.car_crash_outlined,
          'color': Colors.deepOrange[500],
        };
      case 'Obstrucción':
        return {'icono': Icons.block_flipped, 'color': Colors.orange[500]};
      case 'Inseguridad':
        return {'icono': Icons.security_outlined, 'color': Colors.purple[400]};
      default:
        return tipoBackend == 'alerta'
            ? {'icono': Icons.warning_rounded, 'color': Colors.orange[500]}
            : {
                'icono': Icons.report_problem_rounded,
                'color': Colors.blueGrey[500],
              };
    }
  }

  void _abrirPanelFiltrosAvanzados() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
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
                    const SizedBox(height: 24),
                    Text(
                      'Filtros del Mapa',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'ESTADO DEL REPORTE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: ['Todos', 'Activos', 'Resueltos'].map((estado) {
                        final isSelected = _filtroEstado == estado;
                        return ChoiceChip(
                          label: Text(
                            estado,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueGrey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _filtroEstado = estado);
                            }
                            setState(() {});
                          },
                          selectedColor: AppColors.azulPrimario,
                          backgroundColor: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'ANTIGÜEDAD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Siempre', 'Hoy', 'Semana', 'Mes'].map((
                        tiempo,
                      ) {
                        final isSelected = _filtroTiempo == tiempo;
                        return ChoiceChip(
                          label: Text(
                            tiempo == 'Semana'
                                ? 'Últimos 7 días'
                                : tiempo == 'Mes'
                                ? 'Últimos 30 días'
                                : tiempo,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueGrey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _filtroTiempo = tiempo);
                            }
                            setState(() {});
                          },
                          selectedColor: AppColors.azulPrimario,
                          backgroundColor: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _filtroEstado = 'Todos';
                              _filtroTiempo =
                                  'Siempre'; // Al limpiar, le permitimos ver todo el historial
                              _filtroCategoria = 'Todas';
                            });
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulPrimario,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Aplicar Filtros',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controlador,
      builder: (context, child) {
        // --- 1. FILTRADO DINÁMICO DE DATOS ---
        final hechosFiltrados = widget.controlador.hechosActivos.where((hecho) {
          if (hecho.tipoHecho == 'positivo') return false;

          if (_filtroEstado == 'Activos' && hecho.estado == 'resuelto') {
            return false;
          }
          if (_filtroEstado == 'Resueltos' && hecho.estado != 'resuelto') {
            return false;
          }

          final diasAntiguedad = DateTime.now()
              .difference(hecho.creadoEn)
              .inDays;

          if (_filtroTiempo == 'Hoy' && diasAntiguedad > 1) return false;
          if (_filtroTiempo == 'Semana' && diasAntiguedad > 7) return false;
          if (_filtroTiempo == 'Mes' && diasAntiguedad > 30) return false;

          if (_filtroCategoria != 'Todas') {
            final categoriaReal = _extraerCategoria(
              hecho.descripcion ?? '',
              hecho.tipoHecho,
            );
            if (categoriaReal != _filtroCategoria) return false;
          }

          return true;
        }).toList();

        // Creamos un Set con los IDs permitidos para filtrar los marcadores del mapa
        final Set<String> idsFiltrados = hechosFiltrados
            .map((h) => h.id)
            .toSet();

        // Extraemos solo los marcadores que superaron el filtro
        final marcadoresFiltrados = widget.controlador.marcadores
            .where((m) => idsFiltrados.contains(m.markerId.value))
            .toSet();

        int filtrosActivosCount = 0;
        if (_filtroEstado != 'Todos') filtrosActivosCount++;
        if (_filtroTiempo != 'Siempre') filtrosActivosCount++; // Empezará en 1

        // Verifica si la tarjeta activa sigue siendo válida tras el filtro
        final bool mostrarTarjetaSeleccionada =
            _hechoSeleccionado != null &&
            idsFiltrados.contains(_hechoSeleccionado!.id);

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _puntoInicial,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(
                bottom: 110,
                top: 160,
              ), // Margen ajustado para la barra de filtros
              markers:
                  marcadoresFiltrados, // ¡MAGIA! Pasamos solo los pines filtrados
              onTap: (LatLng posicion) {
                if (_hechoSeleccionado != null) {
                  setState(() => _hechoSeleccionado = null);
                }
              },
            ),

            // --- BARRA FLOTANTE DE FILTROS ---
            Positioned(
              top: 100, // Debajo de la AppBar
              left: 0,
              right: 0,
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categorias.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ActionChip(
                        avatar: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: filtrosActivosCount > 0
                              ? Colors.white
                              : AppColors.azulPrimario,
                        ),
                        label: Text(
                          filtrosActivosCount > 0
                              ? 'Filtros ($filtrosActivosCount)'
                              : 'Filtros',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: filtrosActivosCount > 0
                                ? Colors.white
                                : AppColors.azulPrimario,
                          ),
                        ),
                        backgroundColor: filtrosActivosCount > 0
                            ? AppColors.azulPrimario
                            : Colors.white.withOpacity(0.9),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.2),
                        onPressed: _abrirPanelFiltrosAvanzados,
                      ),
                    );
                  }

                  final categoria = _categorias[index - 1];
                  final isSelected = _filtroCategoria == categoria;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        categoria,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.blueGrey[700],
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _filtroCategoria = categoria);
                        }
                      },
                      backgroundColor: Colors.white.withOpacity(0.9),
                      selectedColor: AppColors.azulPrimario,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.azulPrimario
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.2),
                    ),
                  );
                },
              ),
            ),

            if (widget.controlador.estaCargando)
              Positioned(
                top: 170,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.azulPrimario,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Actualizando mapa...',
                          style: TextStyle(
                            color: Colors.blueGrey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Mini-Tarjeta: Se eleva y se oculta dinámicamente si el filtro la excluye
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: mostrarTarjetaSeleccionada ? 120 : -150,
              left: 20,
              right: 20,
              child: _hechoSeleccionado == null
                  ? const SizedBox.shrink()
                  : _buildTarjetaPrevisualizacion(context, _hechoSeleccionado!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTarjetaPrevisualizacion(BuildContext context, HechoModel hecho) {
    final parseado = _parsearDescripcion(
      hecho.descripcion ?? '',
      hecho.tipoHecho,
    );
    final categoriaNombre = parseado['categoria']!;
    final descripcionLimpia = parseado['descripcion']!;
    final estilosUI = _getEstilosCategoria(categoriaNombre, hecho.tipoHecho);

    final bool esResuelto = hecho.estado == 'resuelto';
    final Color colorUI = esResuelto
        ? Colors.green[600]!
        : estilosUI['color'] as Color;
    final IconData iconoUI = esResuelto
        ? Icons.verified_rounded
        : estilosUI['icono'] as IconData;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HechoDetalleScreen(
              hecho: hecho,
              controller: widget.controlador,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[100]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: colorUI.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorUI.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconoUI, color: colorUI, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esResuelto
                        ? 'RESUELTO • ${categoriaNombre.toUpperCase()}'
                        : categoriaNombre.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: colorUI,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcionLimpia.isNotEmpty
                        ? descripcionLimpia
                        : 'Reporte en la zona',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blueGrey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.blueGrey[400],
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
