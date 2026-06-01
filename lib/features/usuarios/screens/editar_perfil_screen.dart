import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../hechos/controllers/hechos_controller.dart';

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
  bool _guardando = false;

  // Catálogo de Avatares generados dinámicamente con DiceBear (Estilo 'bottts' o 'avataaars')
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

    _aliasController = TextEditingController(text: perfil?.alias ?? '');

    // Si ya tiene un avatar, lo marcamos. Si no, seleccionamos el primero por defecto.
    if (perfil?.avatarUrl != null && perfil!.avatarUrl!.isNotEmpty) {
      _avatarSeleccionado = perfil.avatarUrl!;
      // Si el avatar actual no está en el catálogo (ej: si antes subió foto), lo añadimos a la lista
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

    if (nuevoAlias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El alias no puede estar vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nuevoAlias.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El alias debe tener al menos 3 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    // Asumimos que agregarás este método a tu UsuarioController en el siguiente paso
    final exito = await widget.usuarioController.actualizarPerfil(
      alias: nuevoAlias,
      avatarUrl: _avatarSeleccionado,
    );

    if (!mounted) return;

    setState(() => _guardando = false);

    if (exito) {
      widget.hechosController.cargarHechos();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil actualizado con éxito!'),
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safePaddingBottom = MediaQuery.of(context).padding.bottom;

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

      // BARRA INFERIOR DE GUARDADO (Sticky y protegida del teclado)
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
            backgroundColor: AppColors.azulPrimario,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
            shadowColor: AppColors.azulPrimario.withOpacity(0.4),
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
        onTap: () =>
            FocusScope.of(context).unfocus(), // Ocultar teclado al tocar fuera
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECCIÓN DE AVATAR
              Text(
                'Tu Avatar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey[400],
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              // Vista Previa Central
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azulPrimario.withOpacity(0.2),
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
              const SizedBox(height: 32),

              // Grilla de Selección de Avatares
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
                              ? AppColors.azulPrimario
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.azulPrimario.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
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

              const SizedBox(height: 40),

              // 2. SECCIÓN DE ALIAS
              Text(
                'Alias en la comunidad',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey[400],
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

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
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      color: AppColors.azulPrimario,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Este nombre será visible en todos tus reportes y comentarios.',
                style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
              ),

              const SizedBox(
                height: 40,
              ), // Espacio extra para que el teclado no tape
            ],
          ),
        ),
      ),
    );
  }
}
