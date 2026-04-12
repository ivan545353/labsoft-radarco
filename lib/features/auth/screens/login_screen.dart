import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Escuchador para cerrar la pantalla si Google nos loguea
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.session != null && mounted) {
        // SOLUCIÓN: Limpia todo el historial de pantallas y vuelve a la raíz (el mapa)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
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
      // ¡ELIMINAMOS EL NAVIGATOR.POP MANUAL DE AQUÍ! El listener se encargará de cerrarlo.
    } else if (_authController.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authController.mensajeError!),
          backgroundColor: AppColors.problema,
        ),
      );
    }
  }

  Future<void> _ejecutarLoginConGoogle() async {
    FocusScope.of(context).unfocus();
    await _authController.entrarConGoogle();

    if (!mounted) return;
    if (_authController.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authController.mensajeError!),
          backgroundColor: AppColors.problema,
        ),
      );
    }
  }

  void _mostrarDialogoRecuperacion() {
    final emailRecuperacionController = TextEditingController(
      text: _emailController.text,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar Contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailRecuperacionController,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final exito = await _authController.recuperarContrasena(
                  emailRecuperacionController.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                if (exito) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Revisa tu bandeja de entrada.'),
                      backgroundColor: AppColors.exito,
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ), // AppBar por si quieren volver atrás
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ListenableBuilder(
            listenable: _authController,
            builder: (context, child) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa tu correo.'
                            : null,
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa tu contraseña.'
                            : null,
                      ),
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
                      const SizedBox(height: 10),
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
                            OutlinedButton.icon(
                              onPressed: _ejecutarLoginConGoogle,
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                height: 24,
                              ),
                              label: const Text(
                                'Ingresar con Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.azulAcento,
                              ),
                              child: const Text(
                                '¿No tienes cuenta? Regístrate aquí',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
