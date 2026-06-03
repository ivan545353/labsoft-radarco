import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/notificaciones_controller.dart';
import '../models/notificacion_model.dart';

class NotificacionesScreen extends StatefulWidget {
  final NotificacionesController controller;

  const NotificacionesScreen({super.key, required this.controller});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();

    // Le decimos a Flutter: "Espera a terminar de dibujar esta pantalla por
    // primera vez, y justo DESPUÉS, pide los datos y apaga el punto del Dock".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.cargarNotificaciones();
        widget.controller.limpiarPuntoDelDock();
      }
    });
  }

  // --- 1. LÓGICA DE AGRUPACIÓN TEMPORAL ---
  Map<String, List<NotificacionModel>> _agruparNotificaciones(
    List<NotificacionModel> notificaciones,
  ) {
    final Map<String, List<NotificacionModel>> grupos = {
      'Hoy': [],
      'Ayer': [],
      'Anteriores': [],
    };

    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));

    for (var n in notificaciones) {
      if (n.creadoEn.year == hoy.year &&
          n.creadoEn.month == hoy.month &&
          n.creadoEn.day == hoy.day) {
        grupos['Hoy']!.add(n);
      } else if (n.creadoEn.year == ayer.year &&
          n.creadoEn.month == ayer.month &&
          n.creadoEn.day == ayer.day) {
        grupos['Ayer']!.add(n);
      } else {
        grupos['Anteriores']!.add(n);
      }
    }
    return grupos;
  }

  // --- 2. DICCIONARIO VISUAL Y ACCIONES ---
  Map<String, dynamic> _configuracionPorTipo(String tipo) {
    switch (tipo) {
      case 'consenso':
        return {
          'icono': Icons.check_circle_rounded,
          'color': AppColors.exito,
          'accionTexto': 'Ver en el mapa',
          'accionIcono': Icons.map_rounded,
        };
      case 'interaccion':
        return {
          'icono': Icons.chat_bubble_rounded,
          'color': AppColors.azulPrimario,
          'accionTexto': 'Responder',
          'accionIcono': Icons.reply_rounded,
        };
      case 'gamificacion':
        return {
          'icono': Icons.military_tech_rounded,
          'color': Colors.amber[600],
          'accionTexto': 'Ver mis logros',
          'accionIcono': Icons.emoji_events_rounded,
        };
      default: // 'sistema'
        return {
          'icono': Icons.info_rounded,
          'color': Colors.blueGrey[400],
          'accionTexto': 'Saber más',
          'accionIcono': Icons.arrow_forward_rounded,
        };
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 60) return '${diferencia.inMinutes}m';
    if (diferencia.inHours < 24) return '${diferencia.inHours}h';
    return '${fecha.day}/${fecha.month}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final notificaciones = widget.controller.notificaciones;
        final estaCargando = widget.controller.estaCargando;
        final grupos = _agruparNotificaciones(notificaciones);

        return Scaffold(
          backgroundColor: Colors.white, // Fondo completamente blanco y limpio
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1, // Sutil sombra al scrollear (Material 3)
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Text(
              'Actividad',
              style: TextStyle(
                color: Colors.blueGrey[900],
                fontWeight: FontWeight.w900,
              ),
            ),
            centerTitle: true,
            actions: [
              if (widget.controller.conteoNoLeidas > 0)
                TextButton(
                  onPressed: () => widget.controller.marcarTodasComoLeidas(),
                  child: const Text(
                    'Leer todo',
                    style: TextStyle(
                      color: AppColors.azulPrimario,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          body: estaCargando && notificaciones.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.azulPrimario,
                  ),
                )
              : notificaciones.isEmpty
              ? _buildEstadoVacio()
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (grupos['Hoy']!.isNotEmpty) ...[
                      _buildEncabezadoGrupo('Hoy'),
                      ...grupos['Hoy']!.map((n) => _buildItemNotificacion(n)),
                    ],
                    if (grupos['Ayer']!.isNotEmpty) ...[
                      _buildEncabezadoGrupo('Ayer'),
                      ...grupos['Ayer']!.map((n) => _buildItemNotificacion(n)),
                    ],
                    if (grupos['Anteriores']!.isNotEmpty) ...[
                      _buildEncabezadoGrupo('Anteriores'),
                      ...grupos['Anteriores']!.map(
                        (n) => _buildItemNotificacion(n),
                      ),
                    ],
                    SizedBox(
                      height: 120 + MediaQuery.of(context).padding.bottom,
                    ),
                  ],
                ),
        );
      },
    );
  }

  // --- 3. COMPONENTES VISUALES ---

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.blueGrey[200],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Todo al día',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aquí aparecerán las actualizaciones\nde tu comunidad.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey[400], height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoGrupo(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.blueGrey[900],
        ),
      ),
    );
  }

  Widget _buildItemNotificacion(NotificacionModel notificacion) {
    final config = _configuracionPorTipo(notificacion.tipo);
    final bool esNueva = !notificacion.leida;

    return Dismissible(
      key: Key(notificacion.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          widget.controller.eliminarNotificacion(notificacion.id),
      background: Container(
        color: Colors.red[500],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: esNueva
            ? AppColors.azulPrimario.withOpacity(0.04)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.controller.marcarComoLeida(notificacion.id);
            // TODO: Lógica general de navegación al tocar toda la fila
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ), // Separador ultra fino
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar / Icono
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: config['color'].withOpacity(0.1),
                      child: Icon(
                        config['icono'],
                        color: config['color'],
                        size: 24,
                      ),
                    ),
                    if (esNueva)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.azulPrimario,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Cuerpo conversacional
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notificacion.titulo,
                              style: TextStyle(
                                fontWeight: esNueva
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 15,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tiempoRelativo(notificacion.creadoEn),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificacion.mensaje,
                        style: TextStyle(
                          fontSize: 14,
                          color: esNueva
                              ? Colors.blueGrey[800]
                              : Colors.blueGrey[500],
                          height: 1.3,
                        ),
                      ),

                      // --- BOTÓN DE ACCIÓN INLINE ---
                      // --- BOTÓN DE ACCIÓN INLINE ---
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          // 1. Marcamos como leída
                          widget.controller.marcarComoLeida(notificacion.id);

                          // 2. Navegamos al detalle del reporte si existe la referencia
                          if (notificacion.referenciaId != null) {
                            // Aquí asumo que tu pantalla de detalle se llama HechoDetalleScreen
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => HechoDetalleScreen(
                            //       hechoId: notificacion.referenciaId!,
                            //     ),
                            //   ),
                            // );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                config['accionIcono'],
                                size: 16,
                                color: config['color'],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                config['accionTexto'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: config['color'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
