import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final exito = await _authController.iniciarSesion(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido de nuevo!'),
          backgroundColor: AppColors.exito,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (_authController.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authController.mensajeError!),
          backgroundColor: AppColors.problema,
        ),
      );
    }
  }

  // --- NUEVA FUNCIÓN: Mostrar el Dialog de Recuperación ---
  void _mostrarDialogoRecuperacion() {
    // Si el usuario ya había escrito algo en el campo de email, lo usamos por defecto
    final emailRecuperacionController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar Contraseña'),
          content: Column(
            mainAxisSize:
                MainAxisSize.min, // Para que no ocupe toda la pantalla
            children: [
              const Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailRecuperacionController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cierra el diálogo
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Cerramos el teclado
                FocusScope.of(context).unfocus();

                // Usamos nuestro controlador
                final exito = await _authController.recuperarContrasena(
                  emailRecuperacionController.text.trim(),
                );

                if (!mounted) return;

                // Cerramos el Dialog
                Navigator.pop(context);

                // Mostramos el feedback en la pantalla principal
                if (exito) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Revisa tu bandeja de entrada o spam. Te hemos enviado un enlace.',
                      ),
                      backgroundColor: AppColors.exito,
                      duration: Duration(seconds: 4),
                    ),
                  );
                } else if (_authController.mensajeError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_authController.mensajeError!),
                      backgroundColor: AppColors.problema,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulPrimario,
              ),
              child: const Text(
                'Enviar Enlace',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ListenableBuilder(
            listenable: _authController,
            builder: (context, child) {
              return Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset('assets/logo.svg', height: 80),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Por favor ingresa tu correo.';
                        final bool emailValido = RegExp(
                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                        ).hasMatch(value);
                        if (!emailValido)
                          return 'Ingresa un correo electrónico válido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Por favor ingresa tu contraseña.';
                        return null;
                      },
                    ),

                    // --- NUEVO: Botón de olvidar contraseña alineado a la derecha ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _authController.estaCargando
                            ? null
                            : _mostrarDialogoRecuperacion,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.azulAcento,
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 10), // Ajustamos el espaciado

                    if (_authController.estaCargando)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.azulPrimario,
                                  AppColors.azulAcento,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: ElevatedButton(
                              onPressed: _ejecutarLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.azulAcento,
                            ),
                            child: const Text(
                              '¿No tienes cuenta? Regístrate aquí',
                            ),
                          ),
                          const Divider(height: 40),
                          OutlinedButton(
                            onPressed: () async {
                              await _authController.entrarComoAnonimo();
                              if (!mounted) return;
                              if (_authController.mensajeError != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _authController.mensajeError!,
                                    ),
                                    backgroundColor: AppColors.problema,
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: AppColors.azulAcento,
                              side: const BorderSide(
                                color: AppColors.azulAcento,
                              ),
                            ),
                            child: const Text(
                              'Explorar el mapa sin registrarse',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
