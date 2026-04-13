import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';

class HechoDetalleScreen extends StatelessWidget {
  final HechoModel hecho;

  const HechoDetalleScreen({super.key, required this.hecho});

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 0) return 'Reportado hace ${diferencia.inDays} d';
    if (diferencia.inHours > 0) return 'Reportado hace ${diferencia.inHours} h';
    if (diferencia.inMinutes > 0)
      return 'Reportado hace ${diferencia.inMinutes} min';
    return 'Reportado justo ahora';
  }

  Map<String, dynamic> _obtenerEstilos() {
    switch (hecho.tipoHecho) {
      case 'problema':
        return {'color': Colors.red, 'titulo': 'Problema Reportado'};
      case 'alerta':
        return {'color': Colors.orange, 'titulo': 'Alerta Comunitaria'};
      case 'positivo':
        return {'color': Colors.green, 'titulo': 'Hecho Positivo'};
      default:
        return {'color': Colors.blue, 'titulo': 'Reporte Comunitario'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilos = _obtenerEstilos();
    final colorPrincipal = estilos['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.white,
      // BARRA INFERIOR DE ACCIONES (Fija en la parte inferior)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Botón de Upvote (Corazón)
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Voto registrado!')),
                  );
                },
                icon: const Icon(
                  Icons.favorite_border,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              // Botón Compartir
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.azulPrimario,
                    side: const BorderSide(color: AppColors.azulPrimario),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón Agregar Comentario
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.add_comment,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Comentar',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // IMAGEN DE CABECERA (Solución Anti-Crash)
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: AppColors.azulPrimario,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              // Quitamos el Image.network y ponemos un fondo con ícono
              background: Container(
                color: AppColors.azulPrimario,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 60,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Foto ciudadana pendiente',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CUERPO DEL DETALLE (La "Hoja" blanca)
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(
                0.0,
                -30.0,
                0.0,
              ), // Sube la hoja blanca sobre la foto
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TÍTULO Y ESTADO
                    Text(
                      estilos['titulo'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: hecho.estado == 'activo'
                                ? Colors.blue[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: hecho.estado == 'activo'
                                    ? Colors.blue[700]
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hecho.estado.toUpperCase(),
                                style: TextStyle(
                                  color: hecho.estado == 'activo'
                                      ? Colors.blue[700]
                                      : Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _tiempoTranscurrido(hecho.creadoEn),
                          style: TextStyle(
                            color: Colors.blueGrey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // TARJETA DEL USUARIO (Mock)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/150?img=11',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Julián Rivera',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[900],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Vecino Activo • Nivel 4',
                                  style: TextStyle(
                                    color: Colors.blueGrey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline,
                              size: 18,
                              color: AppColors.azulPrimario,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // DESCRIPCIÓN COMPLETA
                    Text(
                      hecho.descripcion ?? 'Sin descripción detallada.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey[800],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCIÓN: VALIDACIÓN COMUNITARIA
                    Text(
                      'VALIDACIÓN COMUNITARIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón: Sigue Pasando
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red[100]!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red[400],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sigue pasando',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '14 vecinos confirmaron esto hoy',
                                    style: TextStyle(
                                      color: Colors.blueGrey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón: Marcar como Resuelto
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A5C36,
                          ), // Verde oscuro del diseño
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Marcar como Resuelto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '¿Se arregló desde tu última visita?',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.celebration,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40), // Espacio extra para el scroll
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
