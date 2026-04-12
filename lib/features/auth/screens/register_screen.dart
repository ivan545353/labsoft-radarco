import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _aliasController = TextEditingController();

  final AuthController _authController = AuthController();

  // Variable para controlar la suscripción al estado de autenticación
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final session = data.session;
      if (session != null && mounted) {
        // SOLUCIÓN: Limpia el historial hasta la raíz
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel(); // ¡Crucial para evitar fugas de memoria!
    _emailController.dispose();
    _passwordController.dispose();
    _aliasController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarRegistro() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final exito = await _authController.registrarse(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _aliasController.text.trim(),
    );

    if (!mounted) return;

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso! Creando tu perfil ciudadano...'),
          backgroundColor: AppColors.exito,
        ),
      );
      // ¡ELIMINAMOS EL NAVIGATOR.POP MANUAL DE AQUÍ!
    } else if (_authController.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authController.mensajeError!),
          backgroundColor: AppColors.problema,
        ),
      );
    }
  }

  // --- NUEVA FUNCIÓN: Registro con Google ---
  Future<void> _ejecutarRegistroConGoogle() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sumarse a RadarCO')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListenableBuilder(
          listenable: _authController,
          builder: (context, child) {
            return Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment
                    .stretch, // Estiramos los elementos a lo ancho
                children: [
                  SvgPicture.asset('assets/logo.svg', height: 80),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _aliasController,
                    decoration: const InputDecoration(
                      labelText: 'Alias (Cómo te verá la comunidad)',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El alias no puede estar vacío.';
                      }
                      if (value.trim().length < 3) {
                        return 'El alias debe tener al menos 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo.';
                      }
                      final bool emailValido = RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                      ).hasMatch(value);
                      if (!emailValido) {
                        return 'Ingresa un correo electrónico válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña (Mínimo 6 caracteres)',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa una contraseña.';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener mínimo 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  if (_authController.estaCargando)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- BOTÓN TRADICIONAL DE REGISTRO ---
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
                            onPressed: _ejecutarRegistro,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Crear mi cuenta',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- NUEVO BOTÓN DE GOOGLE ---
                        OutlinedButton.icon(
                          onPressed: _ejecutarRegistroConGoogle,
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                            height: 24,
                          ),
                          label: const Text(
                            'Registrarse con Google',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
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
    );
  }
}
