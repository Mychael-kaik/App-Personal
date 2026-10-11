import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';

/// PLACEHOLDER: o treino do dia do aluno será construído na Etapa 4.
class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu treino')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Olá, ${perfil?.nome ?? ''}!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Você entrou como ALUNO.\n'
                    'Aqui vai aparecer o treino do dia (Etapa 4).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).sair(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
