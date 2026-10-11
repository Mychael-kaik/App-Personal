import 'package:flutter/material.dart';

/// Tela mostrada por um instante enquanto o app descobre se já existe login salvo.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
