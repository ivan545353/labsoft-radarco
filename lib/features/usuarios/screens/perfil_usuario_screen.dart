import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/usuario_controller.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;

  const PerfilUsuarioScreen({
    super.key,
    required this.authController,
    required this.usuarioController,
  });

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  @override
  void initState() {
    super.initState();
    // Cargamos los datos apenas se entra a la pestaña
    widget.usuarioController.cargarPerfil();
  }

  int _calcularNivel(int reputacion) {
    return (reputacion / 50).floor() + 1;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.usuarioController,
      builder: (context, child) {
        final perfil = widget.usuarioController.perfilActual;

        if (widget.usuarioController.estaCargando) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          color: const Color(0xFFF4F7FB),
          child: CustomScrollView(
            slivers: [
              // CABECERA CON AVATAR Y REPUTACIÓN
              SliverPadding(
                padding: const EdgeInsets.only(top: 100, left: 24, right: 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.azulPrimario,
                              width: 3,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 44,
                            backgroundColor: Color(0xFFEEF3FC),
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.azulPrimario,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        perfil?.alias ?? 'Cargando...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBadgeNivel(_calcularNivel(perfil?.reputacion ?? 0)),
                    ],
                  ),
                ),
              ),

              // ESTADÍSTICAS RÁPIDAS
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Reputación',
                        '${perfil?.reputacion ?? 0}',
                        Icons.star_rounded,
                        Colors.amber,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Reportes',
                        '12',
                        Icons.map_rounded,
                        AppColors.azulPrimario,
                      ), // Placeholder por ahora
                    ],
                  ),
                ),
              ),

              // OPCIONES Y AJUSTES
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMenuOption(Icons.edit_outlined, 'Editar mi perfil'),
                    _buildMenuOption(
                      Icons.notifications_outlined,
                      'Notificaciones',
                    ),
                    _buildMenuOption(Icons.security_outlined, 'Privacidad'),
                    const SizedBox(height: 32),
                    // BOTÓN CERRAR SESIÓN
                    ElevatedButton.icon(
                      onPressed: () => widget.authController.cerrarSesion(),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.problema,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
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

  Widget _buildBadgeNivel(int nivel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.azulPrimario,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'NIVEL $nivel',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

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
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey[600]),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
