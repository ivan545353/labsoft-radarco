import 'package:flutter/material.dart';
import 'package:radar_ciudadano/features/usuarios/screens/editar_perfil_screen.dart';
import 'package:radar_ciudadano/features/usuarios/screens/privacidad_datos_screen.dart';
import 'package:radar_ciudadano/features/usuarios/screens/ayuda_soporte_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../hechos/controllers/hechos_controller.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final HechosController hechosController;

  const PerfilUsuarioScreen({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.hechosController,
  });

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  @override
  void initState() {
    super.initState();
    widget.usuarioController.cargarPerfil();
  }

  // --- MOTOR DE GAMIFICACIÓN BÁSICA ---
  int _calcularNivel(int reputacion) {
    return (reputacion / 50).floor() + 1;
  }

  double _calcularProgreso(int reputacion) {
    return (reputacion % 50) / 50.0;
  }

  int _puntosParaProximoNivel(int reputacion) {
    return 50 - (reputacion % 50);
  }

  String _obtenerRango(int nivel) {
    if (nivel >= 10) return 'Héroe de la Ciudad';
    if (nivel >= 7) return 'Guardián Cívico';
    if (nivel >= 4) return 'Colaborador Frecuente';
    if (nivel >= 2) return 'Vecino Observador';
    return 'Ciudadano Nuevo';
  }

  @override
  Widget build(BuildContext context) {
    // Leemos las áreas seguras del dispositivo (Notch superior y Barra de gestos inferior)
    final double safePaddingTop = MediaQuery.of(context).padding.top;
    final double safePaddingBottom = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: widget.usuarioController,
      builder: (context, child) {
        final perfil = widget.usuarioController.perfilActual;
        final estaCargando = widget.usuarioController.estaCargando;

        final int reputacion = perfil?.reputacion ?? 0;
        final int nivel = _calcularNivel(reputacion);
        final String rango = _obtenerRango(nivel);
        final double progreso = _calcularProgreso(reputacion);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          body: estaCargando
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.azulPrimario,
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // --- CABECERA PARALLAX DINÁMICA ---
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // Fondo de la cabecera (Crece dinámicamente según el notch del celular)
                          Container(
                            height: 200 + safePaddingTop,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.azulPrimario,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.azulPrimario,
                                  AppColors.azulPrimario.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(40),
                              ),
                            ),
                          ),

                          // Tarjeta de Perfil Flotante (Se empuja hacia abajo respetando la barra superior)
                          Container(
                            margin: EdgeInsets.only(
                              top: 120 + safePaddingTop,
                              left: 24,
                              right: 24,
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  perfil?.alias ?? 'Usuario',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueGrey[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.exito.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    rango.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.exito,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // BARRA DE PROGRESO DE NIVEL
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'NIVEL $nivel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'NIVEL ${nivel + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progreso,
                                    minHeight: 10,
                                    backgroundColor: Colors.blueGrey[50],
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.azulPrimario,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Faltan ${_puntosParaProximoNivel(reputacion)} puntos para subir de nivel',
                                  style: TextStyle(
                                    color: Colors.blueGrey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Avatar Flotante (Se ancla perfectamente entre las dos capas)
                          Positioned(
                            top: 70 + safePaddingTop,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFEEF3FC),
                                backgroundImage:
                                    perfil?.avatarUrl != null &&
                                        perfil!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(perfil!.avatarUrl!)
                                    : null,
                                child:
                                    perfil?.avatarUrl == null ||
                                        perfil!.avatarUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: AppColors.azulPrimario,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- ESTADÍSTICAS RÁPIDAS ---
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        top: 24,
                        left: 24,
                        right: 24,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            _buildStatCard(
                              'Reputación',
                              '$reputacion',
                              Icons.stars_rounded,
                              Colors.amber[600]!,
                            ),
                            const SizedBox(width: 16),
                            _buildStatCard(
                              'Aportes',
                              '12',
                              Icons.map_rounded,
                              AppColors.azulPrimario,
                            ), // Mock
                          ],
                        ),
                      ),
                    ),

                    // --- VITRINA DE MEDALLAS ---
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 32, bottom: 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Tus Logros',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueGrey[900],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 110,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                children: [
                                  _buildMedalla(
                                    'Primer Paso',
                                    'Reporte creado',
                                    Icons.flag_rounded,
                                    Colors.orange,
                                    true,
                                  ),
                                  _buildMedalla(
                                    'Voz Confiable',
                                    '10 confirmaciones',
                                    Icons.campaign_rounded,
                                    Colors.blue,
                                    false,
                                  ),
                                  _buildMedalla(
                                    'Solucionador',
                                    'Caso cerrado',
                                    Icons.handshake_rounded,
                                    Colors.green,
                                    false,
                                  ),
                                  _buildMedalla(
                                    'Ojo de Halcón',
                                    '5 baches',
                                    Icons.remove_red_eye_rounded,
                                    Colors.purple,
                                    false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- OPCIONES Y AJUSTES ---
                    SliverPadding(
                      // Se agrega el padding inferior + 100px para evitar el Smart Dock
                      padding: EdgeInsets.only(
                        top: 16,
                        left: 24,
                        right: 24,
                        bottom: 120 + safePaddingBottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text(
                            'Ajustes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey[400],
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildMenuOption(
                            Icons.edit_rounded,
                            'Editar mi perfil',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditarPerfilScreen(
                                    usuarioController: widget.usuarioController,
                                    hechosController: widget
                                        .hechosController, // 🔥 SE LO PASAMOS A LA OTRA PANTALLA
                                  ),
                                ),
                              );
                            },
                          ),
                          // ELIMINADA la opción de Notificaciones por redundancia con el Dock
                          _buildMenuOption(
                            Icons.security_rounded,
                            'Privacidad y Datos',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PrivacidadDatosScreen(
                                    authController: widget
                                        .authController, // 🔥 PASAMOS EL CONTROLADOR
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildMenuOption(
                            Icons.help_outline_rounded,
                            'Ayuda y Soporte',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AyudaSoporteScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // BOTÓN CERRAR SESIÓN ESTILO "GHOST"
                          InkWell(
                            onTap: () => widget.authController.cerrarSesion(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red[100]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Colors.red[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cerrar Sesión',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.blueGrey[900],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalla(
    String titulo,
    String subtitulo,
    IconData icono,
    MaterialColor color,
    bool desbloqueada,
  ) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: desbloqueada ? Colors.white : Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: desbloqueada ? color[100]! : Colors.transparent,
        ),
        boxShadow: desbloqueada
            ? [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icono,
            size: 32,
            color: desbloqueada ? color[500] : Colors.blueGrey[200],
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: desbloqueada ? Colors.blueGrey[900] : Colors.blueGrey[400],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[300],
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label, {VoidCallback? onTap}) {
    // <-- Agregado {VoidCallback? onTap}
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blueGrey[700], size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey[900],
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.blueGrey[300],
          size: 14,
        ),
        onTap: onTap, // 🔥 CONECTAMOS LA ACCIÓN
      ),
    );
  }
}
