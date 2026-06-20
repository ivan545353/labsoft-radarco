import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/notificaciones_controller.dart';
import '../models/notificacion_model.dart';
import '../../hechos/controllers/hechos_controller.dart';
import '../../hechos/screens/hecho_detalle_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  final NotificacionesController controller;
  final HechosController hechosController;

  const NotificacionesScreen({
    super.key,
    required this.controller,
    required this.hechosController,
  });

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.cargarNotificaciones();
        widget.controller.limpiarPuntoDelDock();
      }
    });
  }

  // --- LÓGICA MAESTRA DE NAVEGACIÓN ---
  Future<void> _procesarToqueNotificacion(
    NotificacionModel notificacion, {
    bool esAccionRapida = false,
  }) async {
    // 1. Siempre marcamos como leída al interactuar
    widget.controller.marcarComoLeida(notificacion.id);

    // 2. Caso Especial: Gamificación (Muestra modal, no navega)
    if (notificacion.tipo == 'gamificacion') {
      _mostrarModalLogro(notificacion);
      return;
    }

    // 3. Validación de seguridad
    if (notificacion.referenciaId == null) return;

    // 4. Mostrar overlay de carga visual (Evita toques múltiples)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.azulPrimario),
      ),
    );

    // 5. Descargar el reporte completo desde Supabase usando el método que ya tenías
    final hecho = await widget.hechosController.obtenerHechoPorId(
      notificacion.referenciaId!,
    );

    // Quitar overlay de carga
    if (mounted) Navigator.pop(context);

    // 6. Ejecutar la acción correspondiente
    if (hecho != null && mounted) {
      // Navegamos a la pantalla de detalle del reporte
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HechoDetalleScreen(
            hecho: hecho,
            controller: widget.hechosController,
          ),
        ),
      );

      // (Nota: Si tuvieras acceso directo al ComentariosSheet desde aquí,
      // podrías invocarlo cuando 'esAccionRapida' y 'tipo' == 'interaccion' sean verdaderos).
    } else if (mounted) {
      // Manejo de errores profesional si el reporte fue borrado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este reporte ya no está disponible en la plataforma.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- MODAL DE CELEBRACIÓN (GAMIFICACIÓN) ---
  void _mostrarModalLogro(NotificacionModel notificacion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                notificacion.titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[900],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notificacion.mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '¡Genial!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  // --- MÉTODOS AUXILIARES ---
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

  Map<String, dynamic> _configuracionPorTipo(String tipo) {
    switch (tipo) {
      case 'consenso':
        return {
          'icono': Icons.check_circle_rounded,
          'color': AppColors.exito,
          'accionTexto': 'Ver reporte',
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
          'accionTexto': 'Ver logro',
          'accionIcono': Icons.emoji_events_rounded,
        };
      default:
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final notificaciones = widget.controller.notificaciones;
        final estaCargando = widget.controller.estaCargando;
        final grupos = _agruparNotificaciones(notificaciones);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            automaticallyImplyLeading: false,
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
          // 📍 ENLAZAMOS EL TOQUE GENERAL (Abre el reporte normalmente)
          onTap: () =>
              _procesarToqueNotificacion(notificacion, esAccionRapida: false),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      const SizedBox(height: 8),
                      InkWell(
                        // 📍 ENLAZAMOS LA ACCIÓN INLINE
                        onTap: () => _procesarToqueNotificacion(
                          notificacion,
                          esAccionRapida: true,
                        ),
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
