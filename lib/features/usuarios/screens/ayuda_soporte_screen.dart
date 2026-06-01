import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class AyudaSoporteScreen extends StatelessWidget {
  const AyudaSoporteScreen({super.key});

  Future<void> _enviarCorreoSoporte(BuildContext context) async {
    // Configuramos el esquema 'mailto' con destinatario y asunto prellenado
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'soporte@radarco.app',
      queryParameters: {'subject': 'Soporte RadarCO - Consulta'},
    );

    try {
      // Intentamos abrir la aplicación de correo nativa
      final bool lanzado = await launchUrl(emailLaunchUri);

      if (!lanzado && context.mounted) {
        // Fallback si el celular no tiene ninguna app de correos instalada
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró una aplicación de correo instalada.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocurrió un error al intentar abrir el correo.'),
            backgroundColor: AppColors.problema,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.blueGrey,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ayuda y Soporte',
          style: TextStyle(
            color: Colors.blueGrey[900],
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER VISUAL ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.azulPrimario.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 64,
                      color: AppColors.azulPrimario,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¿En qué podemos ayudarte?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Encuentra respuestas rápidas o contáctanos.',
                    style: TextStyle(color: Colors.blueGrey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- SECCIÓN: PREGUNTAS FRECUENTES ---
            Text(
              'PREGUNTAS FRECUENTES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey[400],
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
                  _buildFaqItem(
                    pregunta: '¿Cómo reporto un problema en mi barrio?',
                    respuesta:
                        'Toca el botón central "Reportar" en el mapa. Selecciona la ubicación exacta, elige la categoría (ej. Bache, Luminaria), añade una foto si la tienes y presiona Publicar.',
                  ),
                  _buildDivider(),
                  _buildFaqItem(
                    pregunta: '¿Qué significa "Posiblemente Solucionado"?',
                    respuesta:
                        'Cuando el autor original o 3 vecinos diferentes indican que el problema fue reparado, el reporte cambia a este estado. No se borra del historial, pero deja de marcarse como un problema activo.',
                  ),
                  _buildDivider(),
                  _buildFaqItem(
                    pregunta: '¿Cómo funciona la reputación?',
                    respuesta:
                        'Ganas puntos cada vez que creas un reporte validado por la comunidad o cuando interactúas confirmando el estado de otros reportes. Al sumar puntos, subirás de nivel y desbloquearás nuevos rangos.',
                  ),
                  _buildDivider(),
                  _buildFaqItem(
                    pregunta: '¿Mis reportes son públicos?',
                    respuesta:
                        'Tus reportes y tu alias son públicos para la comunidad de Caleta Olivia. Sin embargo, si decides eliminar tu cuenta, tus reportes pasarán a ser completamente anónimos.',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- SECCIÓN: CONTACTO DIRECTO ---
            Text(
              'CONTACTO DIRECTO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey[400],
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _enviarCorreoSoporte(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(20),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.azulPrimario.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.email_rounded,
                        color: AppColors.azulPrimario,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escríbenos un correo',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey[900],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'soporte@radarco.app',
                            style: TextStyle(
                              color: Colors.blueGrey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.blueGrey[300],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- VERSIÓN DE LA APP ---
            Center(
              child: Text(
                'RadarCO v1.0.0 (MVP)\nHecho con ❤️ para Caleta Olivia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blueGrey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required String pregunta,
    required String respuesta,
    bool isLast = false,
  }) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: AppColors.azulPrimario,
        collapsedIconColor: Colors.blueGrey[400],
        title: Text(
          pregunta,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey[900],
            fontSize: 14,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        children: [
          Text(
            respuesta,
            style: TextStyle(
              color: Colors.blueGrey[600],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: Colors.grey[100], height: 1, thickness: 1),
    );
  }
}
