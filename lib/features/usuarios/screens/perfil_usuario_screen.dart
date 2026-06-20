import 'package:flutter/material.dart';
import 'package:radar_ciudadano/features/usuarios/screens/editar_perfil_screen.dart';
import 'package:radar_ciudadano/features/usuarios/screens/privacidad_datos_screen.dart';
import 'package:radar_ciudadano/features/usuarios/screens/ayuda_soporte_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../hechos/controllers/hechos_controller.dart';
import '../../utils/catalogo_recompensas.dart'; // Importar catálogo

// --- MODELO: LOGROS EVOLUTIVOS ---
class TierLogro {
  final String titulo;
  final int meta;
  final Color colorRango;
  final IconData icono;
  TierLogro(this.titulo, this.meta, this.colorRango, this.icono);
}

class LogroEvolutivo {
  final String descripcionBasica;
  final int progresoActual;
  final List<TierLogro> tiers;

  LogroEvolutivo({
    required this.descripcionBasica,
    required this.progresoActual,
    required this.tiers,
  });

  int get indiceTierActual {
    int indice = -1;
    for (int i = 0; i < tiers.length; i++) {
      if (progresoActual >= tiers[i].meta) {
        indice = i;
      } else {
        break;
      }
    }
    return indice;
  }

  TierLogro get tierVisual =>
      indiceTierActual == -1 ? tiers[0] : tiers[indiceTierActual];
  TierLogro? get proximoTier =>
      indiceTierActual + 1 < tiers.length ? tiers[indiceTierActual + 1] : null;
  bool get estaDesbloqueado => progresoActual >= tiers[0].meta;
}

// --- PANTALLA ---
class PerfilUsuarioScreen extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final HechosController hechosController;
  final bool esPerfilPropio;
  final String? usuarioIdVisualizado;

  const PerfilUsuarioScreen({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.hechosController,
    this.esPerfilPropio = true,
    this.usuarioIdVisualizado,
  });

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  int _totalReportesCreados = 0;
  int _totalProblemasResueltos = 0;
  int _totalConfirmaciones = 0;
  int _totalComentarios = 0;

  final Color _bronce = const Color(0xFFCD7F32);
  final Color _plata = const Color(0xFF90A4AE);
  final Color _oro = const Color(0xFFFFB300);
  final Color _diamante = const Color(0xFF00BCEB);

  @override
  void initState() {
    super.initState();
    _cargarDatosDePantalla();
  }

  void _cargarDatosDePantalla() {
    if (widget.esPerfilPropio) {
      widget.usuarioController.cargarPerfil();
    }
    _calcularEstadisticasDelUsuario();
  }

  void _calcularEstadisticasDelUsuario() {
    final idFiltrar = widget.esPerfilPropio
        ? widget.usuarioController.perfilActual?.id
        : widget.usuarioIdVisualizado;
    if (idFiltrar == null) return;

    int creados = 0;
    int resueltos = 0;

    for (var hecho in widget.hechosController.hechosActivos) {
      if (hecho.ciudadanoId == idFiltrar) {
        creados++;
        if (hecho.estado == 'resuelto') resueltos++;
      }
    }
    setState(() {
      _totalReportesCreados = creados;
      _totalProblemasResueltos = resueltos;
    });
  }

  List<LogroEvolutivo> _generarLogros() {
    return [
      LogroEvolutivo(
        descripcionBasica: 'Reportes creados',
        progresoActual: _totalReportesCreados,
        tiers: [
          TierLogro('Iniciador', 1, _bronce, Icons.flag_outlined),
          TierLogro('Vigilante', 10, _plata, Icons.remove_red_eye_rounded),
          TierLogro('Faro Cívico', 50, _oro, Icons.my_location_rounded),
          TierLogro('Radar Humano', 100, _diamante, Icons.radar_rounded),
        ],
      ),
      LogroEvolutivo(
        descripcionBasica: 'Confirmaciones',
        progresoActual: _totalConfirmaciones,
        tiers: [
          TierLogro('Voz Activa', 5, _bronce, Icons.how_to_vote_outlined),
          TierLogro('Validador', 25, _plata, Icons.fact_check_rounded),
          TierLogro('Auditor', 50, _oro, Icons.rule_rounded),
          TierLogro('Juez Vecinal', 100, _diamante, Icons.gavel_rounded),
        ],
      ),
      LogroEvolutivo(
        descripcionBasica: 'Casos cerrados',
        progresoActual: _totalProblemasResueltos,
        tiers: [
          TierLogro('Primer Cierre', 1, _bronce, Icons.handshake_outlined),
          TierLogro('Solucionador', 10, _plata, Icons.build_circle_rounded),
          TierLogro('Héroe Local', 50, _oro, Icons.verified_rounded),
          TierLogro('Gestor Urbano', 100, _diamante, Icons.stars_rounded),
        ],
      ),
      LogroEvolutivo(
        descripcionBasica: 'Comentarios',
        progresoActual: _totalComentarios,
        tiers: [
          TierLogro(
            'Vecino Sociable',
            1,
            _bronce,
            Icons.chat_bubble_outline_rounded,
          ),
          TierLogro('Debatiente', 10, _plata, Icons.forum_rounded),
          TierLogro('Comunicador', 50, _oro, Icons.record_voice_over_rounded),
          TierLogro('Voz del Barrio', 100, _diamante, Icons.campaign_rounded),
        ],
      ),
    ];
  }

  int _calcularNivel(int reputacion) => (reputacion / 50).floor() + 1;
  double _calcularProgreso(int reputacion) => (reputacion % 50) / 50.0;
  int _puntosFaltantes(int reputacion) => 50 - (reputacion % 50);

  String _obtenerEstatus(int reputacion) {
    if (reputacion >= 500) return 'Referente de Zona';
    if (reputacion >= 250) return 'Vecino Confiable';
    if (reputacion >= 100) return 'Colaborador Frecuente';
    if (reputacion >= 50) return 'Participante Activo';
    return 'Nuevo Usuario';
  }

  @override
  Widget build(BuildContext context) {
    final double safePaddingTop = MediaQuery.of(context).padding.top;
    final double safePaddingBottom = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: widget.usuarioController,
      builder: (context, child) {
        final perfil = widget.usuarioController.perfilActual;
        final estaCargando = widget.usuarioController.estaCargando;

        final int puntos = perfil?.reputacion ?? 0;
        final int nivel = _calcularNivel(puntos);
        final String estatus = _obtenerEstatus(puntos);
        final double progreso = _calcularProgreso(puntos);
        final logrosEvolutivos = _generarLogros();

        // 🔥 OBTENER PERSONALIZACIÓN DEL CATÁLOGO
        final colorTema = CatalogoRecompensas.getColorTema(
          perfil?.colorTema ?? 'azul_primario',
        );
        final gradienteBanner = CatalogoRecompensas.getGradienteBanner(
          perfil?.bannerEquipado ?? 'clasico_azul',
        );
        final colorMarco = CatalogoRecompensas.getColorMarco(
          perfil?.marcoEquipado ?? 'ninguno',
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          body: estaCargando
              ? Center(child: CircularProgressIndicator(color: colorTema))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // --- CABECERA PARALLAX ---
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            height: 200 + safePaddingTop,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradienteBanner,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(40),
                              ),
                            ),
                            child: !widget.esPerfilPropio
                                ? SafeArea(
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
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
                                    color: colorTema.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    estatus.toUpperCase(),
                                    style: TextStyle(
                                      color: colorTema,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorTema,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Faltan ${_puntosFaltantes(puntos)} puntos para subir de nivel',
                                  style: TextStyle(
                                    color: Colors.blueGrey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🔥 AVATAR CON MARCO DINÁMICO
                          Positioned(
                            top: 70 + safePaddingTop,
                            child: Container(
                              padding: EdgeInsets.all(
                                perfil?.marcoEquipado != 'ninguno' ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: perfil?.marcoEquipado != 'ninguno'
                                    ? Border.all(color: colorMarco, width: 4)
                                    : null,
                                boxShadow: perfil?.marcoEquipado != 'ninguno'
                                    ? [
                                        BoxShadow(
                                          color: colorMarco.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFEEF3FC),
                                backgroundImage:
                                    perfil?.avatarUrl != null &&
                                        perfil!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(perfil.avatarUrl!)
                                    : null,
                                child:
                                    perfil?.avatarUrl == null ||
                                        perfil!.avatarUrl!.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: colorTema,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- MÉTRICAS CONCRETAS ---
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
                              'Puntos Totales',
                              '$puntos',
                              Icons.stars_rounded,
                              colorTema,
                            ),
                            const SizedBox(width: 16),
                            _buildStatCard(
                              'Problemas Resueltos',
                              '$_totalProblemasResueltos',
                              Icons.check_circle_rounded,
                              AppColors.exito,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- CUADRÍCULA EVOLUTIVA ---
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        top: 32,
                        left: 24,
                        right: 24,
                        bottom: 16,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          widget.esPerfilPropio
                              ? 'Evolución de Logros'
                              : 'Logros Obtenidos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.95,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildMedallaEvolutiva(logrosEvolutivos[index]),
                          childCount: logrosEvolutivos.length,
                        ),
                      ),
                    ),

                    // --- ZONA PRIVADA ---
                    if (widget.esPerfilPropio)
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: 32,
                          left: 24,
                          right: 24,
                          bottom: 120 + safePaddingBottom,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text(
                              'Ajustes Privados',
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
                              'Editar mis datos',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditarPerfilScreen(
                                      usuarioController:
                                          widget.usuarioController,
                                      hechosController: widget.hechosController,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMenuOption(
                              Icons.security_rounded,
                              'Privacidad de la cuenta',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivacidadDatosScreen(
                                      authController: widget.authController,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMenuOption(
                              Icons.help_outline_rounded,
                              'Contactar soporte',
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
                            InkWell(
                              onTap: () => widget.authController.cerrarSesion(),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                      )
                    else
                      SliverToBoxAdapter(
                        child: SizedBox(height: 120 + safePaddingBottom),
                      ),
                  ],
                ),
        );
      },
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

  Widget _buildMedallaEvolutiva(LogroEvolutivo logro) {
    final estaDesbloqueado = logro.estaDesbloqueado;
    final tierVisual = logro.tierVisual;
    final proximo = logro.proximoTier;

    final colorFondo = estaDesbloqueado ? Colors.white : Colors.grey[100];
    final colorBorde = estaDesbloqueado
        ? tierVisual.colorRango.withOpacity(0.4)
        : Colors.transparent;
    final colorIcono = estaDesbloqueado
        ? tierVisual.colorRango
        : Colors.grey[400];
    final colorTitulo = estaDesbloqueado
        ? Colors.blueGrey[900]
        : Colors.grey[500];

    final int metaActual = proximo?.meta ?? tierVisual.meta;
    final double porcentaje = (logro.progresoActual / metaActual).clamp(
      0.0,
      1.0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorBorde, width: 2),
        boxShadow: estaDesbloqueado
            ? [
                BoxShadow(
                  color: tierVisual.colorRango.withOpacity(0.12),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tierVisual.icono, size: 36, color: colorIcono),
          const SizedBox(height: 12),
          Text(
            estaDesbloqueado ? tierVisual.titulo : 'Bloqueado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: colorTitulo,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            logro.descripcionBasica,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[400],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${logro.progresoActual}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: colorIcono,
                ),
              ),
              Text(
                proximo != null ? '${proximo.meta}' : 'MAX',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: estaDesbloqueado
                  ? tierVisual.colorRango.withOpacity(0.15)
                  : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(colorIcono!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label, {VoidCallback? onTap}) {
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
        onTap: onTap,
      ),
    );
  }
}
