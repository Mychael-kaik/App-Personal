import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/painel_admin_repository.dart';
import '../../dashboard/presentation/painel_admin_tab.dart';
import '../../dashboard/presentation/today_tab.dart';
import 'exercise_sheet.dart';
import 'exercises_tab.dart';
import 'students_tab.dart';
import 'team_tab.dart';

/// Painel da equipe. Professor: Hoje, Alunos e Exercícios (só o que é dele).
/// Administrador geral: "Painel" + essas três + "Equipe" (academias e professores).
class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  int _aba = 0;

  // Chaves das abas na ordem atual (preenchida no build); serve para o
  // Painel pedir "abra a aba Alunos".
  List<String> _chaves = const [];

  void _irPara(String chave) {
    final i = _chaves.indexOf(chave);
    if (i >= 0) setState(() => _aba = i);
  }

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
    final ehAdmin = perfil?.isAdmin ?? false;

    // Abas: o administrador geral tem "Painel" a mais, no começo.
    // Cada aba tem: título, ícones, tela e (opcional) botão flutuante.
    final abas = <_Aba>[
      if (ehAdmin)
        _Aba(
          titulo: 'Painel',
          rotulo: 'Painel',
          icone: Icons.dashboard_outlined,
          iconeAtivo: Icons.dashboard,
          tela: PainelAdminTab(onAbrirAlunos: () => _irPara('alunos')),
          chave: 'painel',
        ),
      _Aba(
        titulo: 'Hoje',
        rotulo: 'Hoje',
        icone: Icons.today_outlined,
        iconeAtivo: Icons.today,
        tela: const TodayTab(),
        chave: 'hoje',
      ),
      _Aba(
        titulo: ehAdmin ? 'Alunos' : 'Meus alunos',
        rotulo: 'Alunos',
        icone: Icons.people_outline,
        iconeAtivo: Icons.people,
        tela: const StudentsTab(),
        chave: 'alunos',
        botao: FloatingActionButton.extended(
          onPressed: () => context.push(Rotas.alunoNovo),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Novo aluno'),
        ),
      ),
      _Aba(
        titulo: ehAdmin ? 'Exercícios (por professor)' : 'Meus exercícios',
        rotulo: 'Exercícios',
        icone: Icons.fitness_center_outlined,
        iconeAtivo: Icons.fitness_center,
        tela: const ExercisesTab(),
        chave: 'exercicios',
        botao: FloatingActionButton.extended(
          onPressed: () => abrirFormularioExercicio(context),
          icon: const Icon(Icons.add),
          label: const Text('Novo exercício'),
        ),
      ),
      if (ehAdmin)
        _Aba(
          titulo: 'Equipe',
          rotulo: 'Equipe',
          icone: Icons.groups_outlined,
          iconeAtivo: Icons.groups,
          tela: const TeamTab(),
          chave: 'equipe',
          botao: FloatingActionButton.extended(
            onPressed: () => context.push(Rotas.professorNovo),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Novo professor'),
          ),
        ),
    ];
    _chaves = [for (final a in abas) a.chave];
    final atual = abas[_aba.clamp(0, abas.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text(atual.titulo),
        actions: [
          if (atual.chave == 'hoje')
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(painelDeHojeProvider),
            ),
          if (atual.chave == 'exercicios' && !ehAdmin)
            IconButton(
              tooltip: 'Biblioteca-modelo',
              icon: const Icon(Icons.collections_bookmark_outlined),
              onPressed: () => context.push(Rotas.modelos),
            ),
          if (atual.chave == 'painel')
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () => atualizarPainelAdmin(ref),
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
      // IndexedStack mantém as abas "vivas": ao trocar de aba, a lista
      // e o filtro continuam como você deixou.
      body: IndexedStack(
        index: _aba.clamp(0, abas.length - 1),
        children: [for (final a in abas) a.tela],
      ),
      floatingActionButton: atual.botao,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba.clamp(0, abas.length - 1),
        onDestinationSelected: (i) {
          // Ao voltar para "Hoje" ou "Painel", busca os números de novo.
          if (abas[i].chave == 'hoje') ref.invalidate(painelDeHojeProvider);
          if (abas[i].chave == 'painel') atualizarPainelAdmin(ref);
          setState(() => _aba = i);
        },
        destinations: [
          for (final a in abas)
            NavigationDestination(
              icon: Icon(a.icone),
              selectedIcon: Icon(a.iconeAtivo),
              label: a.rotulo,
            ),
        ],
      ),
    );
  }
}

/// Uma aba do painel da equipe.
class _Aba {
  const _Aba({
    required this.titulo,
    required this.rotulo,
    required this.icone,
    required this.iconeAtivo,
    required this.tela,
    required this.chave,
    this.botao,
  });

  final String titulo;
  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;
  final String chave;
  final Widget? botao;
}
