import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final AuthController _auth = AuthController();
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  int _paso = 1; // 1 = pedir email · 2 = código + nueva contraseña
  bool _cargando = false;
  bool _verPass = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Evita que el listener de login nos expulse al verificar el código.
    AuthController.recuperacionEnProceso = true;
  }

  @override
  void dispose() {
    AuthController.recuperacionEnProceso = false;
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _auth.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    final ok = await _auth.enviarCodigoRecuperacion(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (ok) {
        _paso = 2;
      } else {
        _error = _auth.mensajeError;
      }
    });
  }

  Future<void> _confirmar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    final ok = await _auth.confirmarNuevaContrasena(
      email: _emailCtrl.text.trim(),
      codigo: _codigoCtrl.text.trim(),
      nuevaContrasena: _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada. Iniciá sesión con tu nueva clave.',
          ),
          backgroundColor: AppColors.exito,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _cargando = false;
        _error = _auth.mensajeError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoGeneral,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.azulOscuro,
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _paso == 1 ? _buildPasoEmail() : _buildPasoCodigo(),
        ),
      ),
    );
  }

  Widget _buildPasoEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Te enviaremos un código de 6 dígitos a tu correo.',
          style: TextStyle(fontSize: 15, color: Colors.blueGrey[600]),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.problema, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        _botonPrincipal(texto: 'Enviar código', onPressed: _enviarCodigo),
      ],
    );
  }

  Widget _buildPasoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingresá el código de 8 dígitos que enviamos a ${_emailCtrl.text.trim()} y tu nueva contraseña.',
          style: TextStyle(fontSize: 15, color: Colors.blueGrey[600]),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codigoCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código de 8 dígitos',
            prefixIcon: Icon(Icons.pin_outlined),
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passCtrl,
          obscureText: !_verPass,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _verPass = !_verPass),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.problema, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        _botonPrincipal(texto: 'Cambiar contraseña', onPressed: _confirmar),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _cargando ? null : _enviarCodigo,
            child: const Text('Reenviar código'),
          ),
        ),
      ],
    );
  }

  Widget _botonPrincipal({
    required String texto,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.azulPrimario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
