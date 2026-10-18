import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/domain/profile.dart';
import '../data/admin_providers.dart';
import '../../../core/widgets/logo_academia.dart';
import '../domain/academia.dart';
import 'academia_dialog.dart';
import 'confirmar_nome_dialog.dart';
import 'desativar_professor_dialog.dart';
import 'reset_password_dialog.dart';

/// Aba "Equipe" (só o administrador geral): academias e os professores de cada uma.
class TeamTab extends ConsumerWidget {
  const TeamTab({super.key});

  Future<void> _atualizar(WidgetRef ref) async {
    ref.invalidate(academiasProvider);
    ref.invalidate(professoresProvider);
    ref.invalidate(alunosProvider);
    try {
      await ref.read(professoresProvider.future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  Future<void> _alternarAtivo(
    BuildContext context,
    WidgetRef ref,
    Profile professor,
    int qtdAlunos,
  ) async {
    if (professor.ativo) {
      // O diálogo cuida de tudo: pede o professor de destino (se houver alunos)
      // e chama o banco, que move os alunos e desativa numa operação só.
      final ok = await abrirDesativarProfessor(context, professor, qtdAlunos);
      if (ok && context.mounted) {
        mostrarMensagem(context, '${professor.nome} foi desativado.');
      }
      return;
    }
    try {
      await ref.read(adminRepositoryProvider).definirAtivo(professor.id, true);
      ref.invalidate(professoresProvider);
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    Profile professor,
  ) async {
    final nome = await pedirNomeParaExcluir(
      context,
      titulo: 'Excluir professor de vez?',
      mensagem:
          'Isto apaga o login e os exercícios de ${professor.nome}. Não dá para '
          'desfazer. Só é possível se ele não tiver mais alunos nem exercícios '
          'usados em treinos.',
      nomeEsperado: professor.nome,
    );
    if (nome == null || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .excluirPessoa(id: professor.id, confirmacao: nome);
      ref.invalidate(professoresProvider);
      ref.invalidate(alunosProvider);
      if (context.mounted) {
        mostrarMensagem(context, 'Professor excluído.');
      }
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academias = ref.watch(academiasProvider);
    final professores = ref.watch(professoresProvider);
    final alunos = ref.watch(alunosProvider);

    if (academias.hasError || professores.hasError) {
      final erro = academias.error ?? professores.error!;
      return ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => _atualizar(ref),
      );
    }
    if (!academias.hasValue || !professores.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final listaAcademias = academias.value!;
    final listaProfessores = professores.value!;
    final listaAlunos = alunos.value ?? const <Profile>[];
    final semProfessor = listaAlunos.where((a) => a.professorId == null).length;

    int alunosDe(String professorId) =>
        listaAlunos.where((a) => a.professorId == professorId).length;

    return RefreshIndicator(
      onRefresh: () => _atualizar(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          OutlinedButton.icon(
            style: compactoContorno(),
            onPressed: () => abrirFormularioAcademia(context),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Nova academia'),
          ),
          const SizedBox(height: 12),
          if (listaAcademias.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhuma academia ainda. Crie a primeira e depois cadastre os '
                'professores dela.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          if (semProfessor > 0)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '$semProfessor ${semProfessor == 1 ? 'aluno ainda está' : 'alunos ainda estão'} '
                  'sem professor. Abra o aluno e toque em "Mudar de professor".',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          for (final academia in listaAcademias)
            _AcademiaCard(
              academia: academia,
              professores: listaProfessores
                  .where((p) => p.academiaId == academia.id)
                  .toList(),
              alunosDe: alunosDe,
              onAlternarAtivo: (p) => _alternarAtivo(context, ref, p, alunosDe(p.id)),
              onExcluir: (p) => _excluir(context, ref, p),
            ),
        ],
      ),
    );
  }
}

class _AcademiaCard extends StatelessWidget {
  const _AcademiaCard({
    required this.academia,
    required this.professores,
    required this.alunosDe,
    required this.onAlternarAtivo,
    required this.onExcluir,
  });

  final Academia academia;
  final List<Profile> professores;
  final int Function(String professorId) alunosDe;
  final void Function(Profile professor) onAlternarAtivo;
  final void Function(Profile professor) onExcluir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LogoAcademia(
                  nome: academia.nome,
                  logoPath: academia.logoPath,
                  tamanho: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    academia.nome,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (!academia.ativo) const Chip(label: Text('Suspensa')),
                IconButton(
                  tooltip: 'Editar academia',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      abrirFormularioAcademia(context, academia: academia),
                ),
              ],
            ),
            if (professores.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 4, 8, 12),
                child: Text('Nenhum professor nesta academia ainda.'),
              ),
            for (final p in professores)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(p.nome.trim().isEmpty ? '?' : p.nome.trim()[0].toUpperCase())),
                title: Text(
                  p.nome,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${alunosDe(p.id)} ${alunosDe(p.id) == 1 ? 'aluno' : 'alunos'}'
                  '${p.ativo ? '' : ' · desativado'}\n${p.email ?? ''}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (acao) {
                    switch (acao) {
                      case 'alunos':
                        context.push(
                          Uri(
                            path: Rotas.alunoNovo,
                            queryParameters: {'professor': p.id},
                          ).toString(),
                        );
                      case 'editar':
                        context.push(Rotas.alunoEditar(p.id));
                      case 'senha':
                        abrirRedefinirSenha(context, p);
                      case 'ativo':
                        onAlternarAtivo(p);
                      case 'excluir':
                        onExcluir(p);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'alunos',
                      child: Text('Cadastrar aluno para ele'),
                    ),
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'senha',
                      child: Text('Redefinir senha'),
                    ),
                    PopupMenuItem(
                      value: 'ativo',
                      child: Text(p.ativo ? 'Desativar' : 'Reativar'),
                    ),
                    if (!p.ativo)
                      const PopupMenuItem(
                        value: 'excluir',
                        child: Text('Excluir de vez'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
