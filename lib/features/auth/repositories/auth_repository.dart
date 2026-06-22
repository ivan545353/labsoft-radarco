import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  // Instanciamos el cliente de Supabase (Nuestra conexión a la BD)
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Iniciar Sesión Tradicional
  Future<void> iniciarSesion(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> existeAlias(String aliasBuscado) async {
    try {
      // Hacemos una consulta rápida a nuestra tabla 'usuarios'
      // maybeSingle() devuelve un registro si lo encuentra, o null si no existe.
      final response = await _supabase
          .from('usuarios')
          .select('alias')
          .eq('alias', aliasBuscado)
          .maybeSingle();

      // Si la respuesta NO es nula, significa que el alias ya está tomado
      return response != null;
    } catch (e) {
      // Si hay un error de red, por seguridad asumimos que no pudimos verificarlo
      // El constraint UNIQUE de SQL que ejecutaste nos protegerá como última barrera
      return false;
    }
  }

  // 2. Registrar Usuario y crear su perfil en la tabla pública
  Future<void> registrarUsuario({
    required String email,
    required String password,
    required String alias,
  }) async {
    // A. Registramos la credencial en el sistema interno de Auth
    final AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final String? authId = response.user?.id;

    if (authId != null) {
      // B. Si el registro fue exitoso, creamos su perfil inicial
      // 🔥 ACTUALIZADO: Pasamos la reputación en 0 y las personalizaciones por defecto
      final nuevoUsuario = UsuarioModel(
        id: '', // Se genera automáticamente en la BD
        authId: authId,
        rol: 'ciudadano',
        alias: alias,
        reputacion: 0,
        marcoEquipado: 'ninguno',
        bannerEquipado: 'clasico_azul',
        colorTema: 'azul_primario',
      );

      // SOLUCIÓN AL CLON DE CUENTAS: Usamos upsert en lugar de insert
      // Si el Trigger ya creó la fila "Vecino_...", el upsert la actualizará con el alias real
      // y con sus parámetros de personalización.
      await _supabase
          .from('usuarios')
          .upsert(
            nuevoUsuario.toJson(),
            onConflict:
                'auth_id', // Le decimos que resuelva conflictos usando esta columna única
          );
    }
  }

  // 3. Ingreso Anónimo
  Future<void> iniciarSesionAnonima() async {
    await _supabase.auth.signInAnonymously();
  }

  // 4. Cerrar Sesión
  Future<void> cerrarSesion() async {
    await _supabase.auth.signOut();
  }

  // 5. Obtener el perfil completo del usuario actual desde nuestra tabla
  Future<UsuarioModel?> obtenerPerfilUsuario(String authId) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('auth_id', authId)
          .single(); // Esperamos un solo registro

      return UsuarioModel.fromJson(response);
    } catch (e) {
      // Si entra como anónimo, no tendrá perfil en la tabla 'usuarios'
      return null;
    }
  }

  Future<UsuarioModel?> obtenerPerfilPorId(String usuarioId) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('id', usuarioId)
          .single();
      return UsuarioModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> enviarCorreoRecuperacion(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // 6. Inicio de Sesión / Registro con Google
  Future<bool> iniciarSesionConGoogle() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      // Aquí va el Deep Link, en la capa de datos
      redirectTo: 'radarciudadano://login-callback/',
    );
  }
}
