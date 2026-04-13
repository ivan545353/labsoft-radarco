import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../controllers/hechos_controller.dart';
import 'hecho_detalle_screen.dart';

class ComunidadFeedScreen extends StatelessWidget {
  final HechosController controlador;

  const ComunidadFeedScreen({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, child) {
        if (controlador.estaCargando && controlador.hechosActivos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final hechosOrdenados = List<HechoModel>.from(controlador.hechosActivos)
          ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

        return Container(
          color: const Color(0xFFF4F7FB), // Fondo sutil azulado del diseño
          child: CustomScrollView(
            slivers: [
              // CABECERA DE LA PANTALLA (Stitch Style)
              SliverPadding(
                padding: const EdgeInsets.only(
                  top: 100,
                  left: 24,
                  right: 24,
                  bottom: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TU BARRIO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey[700],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Feed de la Comunidad',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // LISTA DE TARJETAS
              if (hechosOrdenados.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dynamic_feed,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aún no hay reportes en tu barrio.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          HechoCard(hecho: hechosOrdenados[index]),
                      childCount: hechosOrdenados.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// WIDGET: TARJETA DE REPORTE (Rediseño Stitch + Navegación)
// ============================================================================
class HechoCard extends StatelessWidget {
  final HechoModel hecho;

  const HechoCard({super.key, required this.hecho});

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 0) return 'Hace ${diferencia.inDays}d';
    if (diferencia.inHours > 0) return 'Hace ${diferencia.inHours}h';
    if (diferencia.inMinutes > 0) return 'Hace ${diferencia.inMinutes}m';
    return 'Justo ahora';
  }

  // Generador de Etiquetas de Estado (Pills)
  Widget _buildStatusPill() {
    Color bgColor;
    Color textColor;
    String text;

    if (hecho.estado == 'resuelto') {
      bgColor = const Color(0xFF5DF2A6); // Verde brillante
      textColor = const Color(0xFF0A5C36);
      text = 'RESUELTO';
    } else if (hecho.estado == 'en_progreso') {
      bgColor = const Color(0xFFF5A623); // Naranja
      textColor = Colors.white;
      text = 'EN PROGRESO';
    } else {
      bgColor = const Color(0xFFD4E4FB); // Azul claro
      textColor = const Color(0xFF2C6BB3);
      text = 'NUEVO REPORTE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esBurbuja = hecho.tipoHecho == 'comunitario';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HechoDetalleScreen(hecho: hecho),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CABECERA: Avatar, Nombre, Tiempo y Etiqueta
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ), // Placeholder seguro Anti-Crash
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vecino Caletense',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_tiempoTranscurrido(hecho.creadoEn)} • Zona Centro',
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusPill(),
              ],
            ),

            const SizedBox(height: 16),

            // 2. CONTENIDO (Normal o Burbuja)
            if (esBurbuja)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF3FC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  hecho.descripcion ?? 'Sin comentarios adicionales.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey[700],
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              )
            else
              Text(
                hecho.descripcion ?? 'Reporte sin descripción detallada.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey[800],
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 16),

            // 3. IMAGEN (Placeholder Anti-Crash)
            if (!esBurbuja) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 50,
                      color: Colors.black12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. BARRA DE INTERACCIONES
            Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.blueGrey[300]),
                const SizedBox(width: 6),
                Text(
                  '12',
                  style: TextStyle(
                    color: Colors.blueGrey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(width: 20),

                Icon(Icons.chat_bubble, size: 20, color: Colors.blueGrey[300]),
                const SizedBox(width: 6),
                Text(
                  '4',
                  style: TextStyle(
                    color: Colors.blueGrey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
