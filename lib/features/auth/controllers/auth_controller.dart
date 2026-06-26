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

  // Mientras está abierto el flujo de recuperación, evita que el listener
  // de login interprete la sesión temporal del OTP como un login normal.
  static bool recuperacionEnProceso = false;

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

  // Recuperación por código (OTP) — Paso 1: enviar el código al correo.
  Future<bool> enviarCodigoRecuperacion(String email) async {
    _mensajeError = null;
    if (email.isEmpty) {
      _mensajeError = 'Por favor, ingresá tu correo electrónico.';
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

  // Paso 2: verificar el código y setear la nueva contraseña.
  Future<bool> confirmarNuevaContrasena({
    required String email,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    _mensajeError = null;
    if (codigo.trim().length < 8) {
      _mensajeError = 'Ingresá el código de 8 dígitos que te enviamos.';
      notifyListeners();
      return false;
    }
    if (nuevaContrasena.length < 6) {
      _mensajeError = 'La contraseña debe tener al menos 6 caracteres.';
      notifyListeners();
      return false;
    }
    _setEstadoCargando(true);
    try {
      await _repository.verificarCodigoRecuperacion(
        email: email,
        token: codigo.trim(),
      );
      await _repository.actualizarContrasena(nuevaContrasena);
      // Cerramos la sesión temporal: el usuario inicia con su nueva clave.
      await _repository.cerrarSesion();
      return true;
    } catch (e) {
      _manejarError(e);
      return false;
    } finally {
      _setEstadoCargando(false);
    }
  }

  // --- CASO DE USO: Inicio de sesión con Google ---
  Future<void> entrarConGoogle() async {
    _mensajeError = null;
    _setEstadoCargando(true);
    try {
      // Le da la orden al repositorio de abrir el navegador
      await _repository.iniciarSesionConGoogle();
    } catch (e) {
      _manejarError(e);
    } finally {
      // ¡LA SOLUCIÓN! Apagamos la carga.
      // Cuando el usuario vuelva del navegador (con éxito o cancelando),
      // la interfaz estará libre y el AuthGate se encargará de moverlo al mapa automáticamente.
      _setEstadoCargando(false);
    }
  }

  // --- Eliminar Cuenta (borrado real server-side) ---
  Future<bool> eliminarCuenta() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Borrado real: anonimiza reportes/comentarios, borra datos personales
      // y elimina el perfil + la cuenta de auth. Si falla, RPC lanza excepción.
      await Supabase.instance.client.rpc('eliminar_mi_cuenta');

      // Solo llegamos acá si el servidor borró de verdad.
      // El signOut puede fallar (el token ya no existe): no debe invalidar el éxito.
      try {
        await cerrarSesion();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error al eliminar la cuenta: $e');
      return false;
    }
  }
}
