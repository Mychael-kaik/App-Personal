import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mensagens.dart';
import '../../../core/widgets/estados.dart';
import '../../admin/data/admin_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfessorHomePage extends ConsumerStatefulWidget {
  const ProfessorHomePage({super.key});

  @override
  ConsumerState<ProfessorHomePage> createState() =>
      _ProfessorHomePageState();
}

class _ProfessorHomePageState extends ConsumerState<ProfessorHomePage> {
  int _aba = 0;

  Future<void> _sair() async {
    final sair = await confirmar(
      context,
      titulo: 'Sair do app?',
      mensagem: 'Você precisará entrar novamente com e-mail e senha.',
      textoConfirmar: 'Sair',
    );

    if (!sair || !mounted) return;

    await ref.read(authControllerProvider.notifier).sair();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(currentProfileProvider);
    const titulos = ['Meus alunos', 'Exercícios'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_aba]),
        actions: [
          if (perfil != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    perfil.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      body: IndexedStack(
        index: _aba,
        children: const [
          ProfessorAlunosTab(),
          _AbaProfessorEmConstrucao(
            icone: Icons.fitness_center,
            titulo: 'Minha biblioteca',
            mensagem:
                'Aqui você poderá cadastrar e organizar seus exercícios.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (indice) {
          setState(() => _aba = indice);
        },
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


class ProfessorAlunosTab extends ConsumerWidget {
  const ProfessorAlunosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alunos = ref.watch(alunosProvider);

    return alunos.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (erro, _) => ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => ref.invalidate(alunosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const EstadoVazio(
            icone: Icons.people_outline,
            titulo: 'Nenhum aluno encontrado',
            mensagem: 'Os alunos vinculados a você aparecerão aqui.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(alunosProvider);
            await ref.read(alunosProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final aluno = lista[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      aluno.nome.isNotEmpty
                          ? aluno.nome[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(aluno.nome),
                  subtitle: Text(aluno.email ?? ''),
                  trailing: Icon(
                    aluno.ativo
                        ? Icons.chevron_right
                        : Icons.block_outlined,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AbaProfessorEmConstrucao extends StatelessWidget {
  const _AbaProfessorEmConstrucao({
    required this.icone,
    required this.titulo,
    required this.mensagem,
  });

  final IconData icone;
  final String titulo;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
