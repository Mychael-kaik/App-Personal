import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/presentation/today_tab.dart';
import 'exercise_sheet.dart';
import 'exercises_tab.dart';
import 'students_tab.dart';

/// Painel do personal: três abas (Hoje, Alunos e Exercícios).
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
    const titulos = ['Hoje', 'Meus alunos', 'Exercícios'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_aba]),
        actions: [
          if (_aba == 0)
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(painelDeHojeProvider),
            ),
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
      // IndexedStack mantém as três abas "vivas": ao trocar de aba, a lista
      // e o filtro continuam como você deixou.
      body: IndexedStack(
        index: _aba,
        children: const [TodayTab(), StudentsTab(), ExercisesTab()],
      ),
      floatingActionButton: switch (_aba) {
        1 => FloatingActionButton.extended(
            onPressed: () => context.push(Rotas.alunoNovo),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Novo aluno'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: () => abrirFormularioExercicio(context),
            icon: const Icon(Icons.add),
            label: const Text('Novo exercício'),
          ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          // Ao voltar para "Hoje", busca os números de novo.
          if (i == 0) ref.invalidate(painelDeHojeProvider);
          setState(() => _aba = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Hoje',
          ),
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
