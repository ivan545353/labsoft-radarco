import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../hechos/controllers/hechos_controller.dart';
import '../../../core/utils/catalogo_recompensas.dart'; // Importamos el catálogo

class EditarPerfilScreen extends StatefulWidget {
  final UsuarioController usuarioController;
  final HechosController hechosController;

  const EditarPerfilScreen({
    super.key,
    required this.usuarioController,
    required this.hechosController,
  });

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  late TextEditingController _aliasController;
  late String _avatarSeleccionado;

  // 🔥 Nuevas variables de estado visual
  late String _marcoSeleccionado;
  late String _bannerSeleccionado;
  late String _temaSeleccionado;
  late int _reputacion;

  bool _guardando = false;

  final List<String> _catalogoAvatares = [
    'https://api.dicebear.com/7.x/bottts/png?seed=Felix&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/bottts/png?seed=Aneka&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/bottts/png?seed=Leo&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/bottts/png?seed=Mimi&backgroundColor=d1d4f9',
    'https://api.dicebear.com/7.x/bottts/png?seed=Jack&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/bottts/png?seed=Lola&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/bottts/png?seed=Sam&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/bottts/png?seed=Zoe&backgroundColor=d1d4f9',
  ];

  @override
  void initState() {
    super.initState();
    final perfil = widget.usuarioController.perfilActual;

    _reputacion = perfil?.reputacion ?? 0;
    _aliasController = TextEditingController(text: perfil?.alias ?? '');
    _marcoSeleccionado = perfil?.marcoEquipado ?? 'ninguno';
    _bannerSeleccionado = perfil?.bannerEquipado ?? 'clasico_azul';
    _temaSeleccionado = perfil?.colorTema ?? 'azul_primario';

    if (perfil?.avatarUrl != null && perfil!.avatarUrl!.isNotEmpty) {
      _avatarSeleccionado = perfil.avatarUrl!;
      if (!_catalogoAvatares.contains(_avatarSeleccionado)) {
        _catalogoAvatares.insert(0, _avatarSeleccionado);
      }
    } else {
      _avatarSeleccionado = _catalogoAvatares[0];
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    final nuevoAlias = _aliasController.text.trim();
    if (nuevoAlias.isEmpty || nuevoAlias.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El alias debe tener al menos 3 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    // 🔥 Enviamos todas las personalizaciones
    final exito = await widget.usuarioController.actualizarPerfil(
      alias: nuevoAlias,
      avatarUrl: _avatarSeleccionado,
      marcoEquipado: _marcoSeleccionado,
      bannerEquipado: _bannerSeleccionado,
      colorTema: _temaSeleccionado,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (exito) {
      widget.hechosController.cargarHechos();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil personalizado con éxito!'),
          backgroundColor: AppColors.exito,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.usuarioController.mensajeError ??
                'Error al actualizar el perfil',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safePaddingBottom = MediaQuery.of(context).padding.bottom;
    final colorPrimarioActual = CatalogoRecompensas.getColorTema(
      _temaSeleccionado,
    ); // Previsualización en tiempo real

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
          'Editar Perfil',
          style: TextStyle(
            color: Colors.blueGrey[900],
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          16 +
              safePaddingBottom +
              (bottomInset > 0 ? bottomInset - safePaddingBottom : 0),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _guardando ? null : _guardarCambios,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorPrimarioActual,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
            shadowColor: colorPrimarioActual.withOpacity(0.4),
          ),
          child: _guardando
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  'Guardar Cambios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECCIÓN DE AVATAR (Con previsualización de Marco)
              _buildSectionTitle('Tu Identidad'),
              Center(
                child: Container(
                  padding: EdgeInsets.all(
                    _marcoSeleccionado != 'ninguno' ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CatalogoRecompensas.getColorMarco(
                        _marcoSeleccionado,
                      ),
                      width: _marcoSeleccionado != 'ninguno' ? 4 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorPrimarioActual.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: NetworkImage(_avatarSeleccionado),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _catalogoAvatares.length,
                itemBuilder: (context, index) {
                  final avatarUrl = _catalogoAvatares[index];
                  final isSelected = _avatarSeleccionado == avatarUrl;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _avatarSeleccionado = avatarUrl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorPrimarioActual
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // 2. SECCIÓN DE ALIAS
              _buildSectionTitle('Alias en la comunidad'),
              Container(
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
                child: TextField(
                  controller: _aliasController,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: VecinoActivo99',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: colorPrimarioActual,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🔥 3. VITRINA DE PERSONALIZACIÓN
              _buildSectionTitle('Fondo del Perfil (Banner)'),
              _buildSelectorHorizontal(
                items: CatalogoRecompensas.banners,
                seleccionadoId: _bannerSeleccionado,
                onSeleccionar: (id) => setState(() => _bannerSeleccionado = id),
                buildItem: (recompensa, isSelected) => Container(
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: recompensa.valorVisual),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Tema de Color (Botones e Íconos)'),
              _buildSelectorHorizontal(
                items: CatalogoRecompensas.temas,
                seleccionadoId: _temaSeleccionado,
                onSeleccionar: (id) => setState(() => _temaSeleccionado = id),
                buildItem: (recompensa, isSelected) => Container(
                  width: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recompensa.valorVisual,
                    border: isSelected
                        ? Border.all(color: Colors.blueGrey[900]!, width: 3)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Marco del Avatar'),
              _buildSelectorHorizontal(
                items: CatalogoRecompensas.marcos,
                seleccionadoId: _marcoSeleccionado,
                onSeleccionar: (id) => setState(() => _marcoSeleccionado = id),
                buildItem: (recompensa, isSelected) => Container(
                  width: 60,
                  decoration: BoxDecoration(
                    shape: recompensa.id == 'hexagono_oro'
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius: recompensa.id == 'hexagono_oro'
                        ? BorderRadius.circular(12)
                        : null,
                    border: Border.all(
                      color: recompensa.id == 'ninguno'
                          ? Colors.grey[300]!
                          : recompensa.valorVisual,
                      width: 4,
                    ),
                    color: isSelected
                        ? Colors.blueGrey[50]
                        : Colors.transparent,
                  ),
                  child: recompensa.id == 'ninguno'
                      ? Icon(Icons.block, color: Colors.grey[400])
                      : null,
                ),
              ),

              const SizedBox(height: 60), // Margen para teclado
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.blueGrey[400],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSelectorHorizontal({
    required List<Recompensa> items,
    required String seleccionadoId,
    required Function(String) onSeleccionar,
    required Widget Function(Recompensa, bool) buildItem,
  }) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final recompensa = items[index];
          final estaDesbloqueada = recompensa.estaDesbloqueada(_reputacion);
          final isSelected = seleccionadoId == recompensa.id;

          return GestureDetector(
            onTap: estaDesbloqueada
                ? () => onSeleccionar(recompensa.id)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Necesitas ${recompensa.puntosRequeridos} puntos para desbloquear esto',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: estaDesbloqueada ? 1.0 : 0.3,
                    child: buildItem(recompensa, isSelected),
                  ),
                  if (!estaDesbloqueada)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
