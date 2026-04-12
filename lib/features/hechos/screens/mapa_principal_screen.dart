import 'package:flutter/material.dart';
import '../../auth/controllers/auth_controller.dart';

class MapaPrincipalScreen extends StatelessWidget {
  const MapaPrincipalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Instanciamos nuestro cerebro para poder usar el botón de salir
    final AuthController authController = AuthController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Vivo - Caleta Olivia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              // Llamamos al método limpio de nuestro controlador
              await authController.cerrarSesion();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '¡Bienvenido!\nAquí construiremos el mapa interactivo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
