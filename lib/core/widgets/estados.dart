import 'package:flutter/material.dart';

import '../estilos.dart';

/// Tela de erro com botão "Tentar novamente".
class ErroView extends StatelessWidget {
  const ErroView({super.key, required this.mensagem, this.onTentarNovamente});

  final String mensagem;
  final VoidCallback? onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cores.error),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (onTentarNovamente != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: compactoContorno(),
                onPressed: onTentarNovamente,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mensagem amigável para listas vazias.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.mensagem,
  });

  final IconData icone;
  final String titulo;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
