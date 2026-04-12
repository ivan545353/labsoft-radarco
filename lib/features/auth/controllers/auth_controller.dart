import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/usuario_model.dart';

class AuthController extends ChangeNotifier {
  // Conectamos el controlador con nuestro DAO (Repositorio)
  final AuthRepository _repository = AuthRepository();

  // --- ESTADOS DE LA PANTALLA ---
  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  UsuarioModel? _usuarioActual;
  UsuarioModel? get usuarioActual => _usuarioActual;

  bool _isDisposed = false;

  // --- MÉTODOS AUXILIARES ---
  @override
  void dispose() {
    _isDisposed = true; // Avisamos que este controlador va a morir
    super.dispose();
  }

  void _setEstadoCargando(bool valor) {
    if (_isDisposed) return;
    _estaCargando = valor;
    notifyListeners();
  }

  void _manejarError(dynamic error) {
    if (_isDisposed) return; // Seguridad extra aquí también

    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials')) {
        _mensajeError = 'El correo o la contraseña son incorrectos.';
      } else if (error.message.contains('User already registered')) {
        _mensajeError = 'Este correo ya está registrado.';
      } else {
        _mensajeError = 'Error: ${error.message}';
      }
    } else {
      _mensajeError = 'Ocurrió un error inesperado.';
    }
    notifyListeners();
  }

  // --- CASOS DE USO (ACCIONES DEL USUARIO) ---

  Future<bool> iniciarSesion(String email, String password) async {
    // 4. VALIDACIÓN TEMPRANA (Client-side validation)
    if (email.isEmpty || password.isEmpty) {
      _mensajeError = 'Por favor, completa todos los campos.';
      notifyListeners();
      return false;
    }

    _setEstadoCargando(true);
    try {
      await _repository.iniciarSesion(email, password);
      return true;
    } catch (e) {
      _manejarError(e);
      return false;
    } finally {
      _setEstadoCargando(false);
    }
  }

  Future<bool> registrarse(String email, String password, String alias) async {
    _mensajeError = null; // <-- Limpieza manual al inicio

    if (email.isEmpty || password.isEmpty || alias.isEmpty) {
      _mensajeError = 'Por favor, completa todos los campos para registrarte.';
      notifyListeners();
      return false;
    }

    _setEstadoCargando(true);
    try {
      final bool aliasEnUso = await _repository.existeAlias(alias);
      if (aliasEnUso) {
        _mensajeError = 'Ese alias ya está en uso. Por favor, elige otro.';
        _setEstadoCargando(false);
        return false;
      }

      await _repository.registrarUsuario(
        email: email,
        password: password,
        alias: alias,
      );
      return true;
    } catch (e) {
      _manejarError(e); // Guarda el error
      return false;
    } finally {
      _setEstadoCargando(false); // Ya no borra el error guardado
    }
  }

  Future<bool> entrarComoAnonimo() async {
    _setEstadoCargando(true);
    try {
      await _repository.iniciarSesionAnonima();
      return true;
    } catch (e) {
      _manejarError(e);
      return false;
    } finally {
      _setEstadoCargando(false);
    }
  }

  Future<void> cerrarSesion() async {
    _setEstadoCargando(true);
    try {
      await _repository.cerrarSesion();
      _usuarioActual = null;
    } catch (e) {
      _manejarError(e);
    } finally {
      _setEstadoCargando(false);
    }
  }

  Future<bool> recuperarContrasena(String email) async {
    _mensajeError = null;

    if (email.isEmpty) {
      _mensajeError =
          'Por favor, ingresa tu correo electrónico para recuperar la contraseña.';
      notifyListeners();
      return false;
    }

    _setEstadoCargando(true);
    try {
      await _repository.enviarCorreoRecuperacion(email);
      return true;
    } catch (e) {
      _manejarError(e);
      return false;
    } finally {
      _setEstadoCargando(false);
    }
  }

  // --- NUEVO: Caso de uso para Google ---
  Future<void> entrarConGoogle() async {
    _mensajeError = null;
    _setEstadoCargando(true);
    try {
      // Nota: No retornamos un bool porque signInWithOAuth redirige la app al navegador.
      // Cuando el navegador vuelve, el AuthGate detecta la sesión automáticamente.
      await _repository.iniciarSesionConGoogle();
    } catch (e) {
      _manejarError(e);
      _setEstadoCargando(false);
    }
    // No ponemos _setEstadoCargando(false) en finally porque la app se va al navegador
  }
}
