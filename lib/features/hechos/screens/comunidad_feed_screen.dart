import 'package:flutter/material.dart';
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

        // INTERCEPTOR VISUAL: Filtramos los hechos para excluir los 'positivos' del MVP
        // y luego los ordenamos de forma descendente por fecha.
        final hechosOrdenados =
            controlador.hechosActivos
                .where((hecho) => hecho.tipoHecho != 'positivo')
                .toList()
              ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

        return Container(
          color: const Color(0xFFF4F7FB), // Fondo sutil azulado del diseño
          child: CustomScrollView(
            slivers: [
              // CABECERA DE LA PANTALLA (Stitch Style)
              SliverPadding(
                padding: const EdgeInsets.only(
                  top: 130,
                  left: 24,
                  right: 24,
                  bottom: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                      (context, index) => HechoCard(
                        hecho: hechosOrdenados[index],
                        controlador:
                            controlador, // <--- PASAMOS EL CONTROLADOR A LA TARJETA
                      ),
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
// WIDGET: TARJETA DE REPORTE con Píldora de Vida Útil (TTL)
// ============================================================================
class HechoCard extends StatelessWidget {
  final HechoModel hecho;
  final HechosController controlador; // <--- AÑADIDO PARA LA HERENCIA

  const HechoCard({
    super.key,
    required this.hecho,
    required this.controlador, // <--- REQUERIDO EN EL CONSTRUCTOR
  });

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

  // Indicador visual de la Vida Dinámica Restante
  Widget _buildTTLPill() {
    final horasRestantes = hecho.caducaEn.difference(DateTime.now()).inHours;
    final esUrgente = horasRestantes <= 24 && horasRestantes >= 0;
    final Color colorBase = esUrgente
        ? const Color(0xFFE65100)
        : const Color(0xFF546E7A); // Naranja cálido vs Azul grisáceo

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorBase.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esUrgente
                ? Icons.local_fire_department_rounded
                : Icons.hourglass_bottom_rounded,
            size: 14,
            color: colorBase,
          ),
          const SizedBox(width: 4),
          Text(
            hecho.tiempoRestanteVida,
            style: TextStyle(
              color: colorBase,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
            builder: (context) => HechoDetalleScreen(
              hecho: hecho,
              controller: controlador, // <--- HERENCIA PERFECTA AL DETALLE
            ),
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
            // 1. CABECERA: Avatar Dinámico, Nombre, Tiempo y Etiqueta
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[100],
                  backgroundImage:
                      hecho.avatarAutor != null && hecho.avatarAutor!.isNotEmpty
                      ? NetworkImage(hecho.avatarAutor!)
                      : null,
                  child: hecho.avatarAutor == null || hecho.avatarAutor!.isEmpty
                      ? Icon(Icons.person, color: Colors.blueGrey[300])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hecho.nombreAutor ?? 'Ciudadano Anónimo', // Nombre real
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_tiempoTranscurrido(hecho.creadoEn)} • Nivel ${(hecho.reputacionAutor ?? 0) ~/ 50 + 1}', // Nivel real
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

            // 3. IMAGEN DINÁMICA (Con protección)
            if (!esBurbuja &&
                hecho.fotoUrl != null &&
                hecho.fotoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  hecho.fotoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. BARRA DE INTERACCIONES BALANCEADA
            Row(
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Colors.blueGrey[300],
                ),
                const SizedBox(width: 6),
                Text(
                  '${hecho.conteoUpvotes}',
                  style: TextStyle(
                    color: Colors.blueGrey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(width: 20),

                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: Colors.blueGrey[300],
                ),
                const SizedBox(width: 6),
                Text(
                  '${hecho.conteoComentarios}',
                  style: TextStyle(
                    color: Colors.blueGrey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const Spacer(), // Empuja la píldora a la derecha
                // Píldora de Tiempo Restante Dinámico
                if (hecho.estado != 'resuelto') _buildTTLPill(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
