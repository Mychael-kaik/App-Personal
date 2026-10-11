import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../auth/presentation/auth_controller.dart';
import 'exercise_sheet.dart';
import 'exercises_tab.dart';
import 'students_tab.dart';

/// Painel do personal: duas abas (Alunos e Exercícios).
class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  int _aba = 0;

  Future<void> _sair() async {
    final sair = await confirmar(
      context,
      titulo: 'Sair do app?',
      mensagem: 'Você precisará entrar de novo com e-mail e senha.',
      textoConfirmar: 'Sair',
    );
    if (!sair) return;
    await ref.read(authControllerProvider.notifier).sair();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(currentProfileProvider);
    final naAbaDeAlunos = _aba == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(naAbaDeAlunos ? 'Meus alunos' : 'Exercícios'),
        actions: [
          if (perfil != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                // Limita a largura: um nome muito longo não pode estourar a barra.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    perfil.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _sair,
          ),
        ],
      ),
      // IndexedStack mantém as duas abas "vivas": ao trocar de aba, a lista
      // e o filtro continuam como você deixou.
      body: IndexedStack(
        index: _aba,
        children: const [StudentsTab(), ExercisesTab()],
      ),
      floatingActionButton: naAbaDeAlunos
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Rotas.alunoNovo),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Novo aluno'),
            )
          : FloatingActionButton.extended(
              onPressed: () => abrirFormularioExercicio(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo exercício'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Alunos',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Exercícios',
          ),
        ],
      ),
    );
  }
}
