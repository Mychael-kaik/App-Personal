import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dia_semana.dart';
import '../../../core/estilos.dart';
import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_providers.dart';
import '../domain/workout.dart';
import 'confirmar_nome_dialog.dart';
import 'duplicate_workout_dialog.dart';
import 'reset_password_dialog.dart';

/// Detalhe de um aluno: dados, ativar/desativar e os 7 dias da semana,
/// cada um com seu treino (ou o botão "Montar").
class StudentDetailPage extends ConsumerWidget {
  const StudentDetailPage({super.key, required this.alunoId});

  final String alunoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aluno = ref.watch(alunoProvider(alunoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aluno'),
        actions: [
          IconButton(
            tooltip: 'Editar aluno',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Rotas.alunoEditar(alunoId)),
          ),
        ],
      ),
      body: aluno.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () => ref.invalidate(alunoProvider(alunoId)),
        ),
        data: (dados) => _Conteudo(aluno: dados),
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.aluno});

  final Profile aluno;

  Future<void> _alternarAtivo(
    BuildContext context,
    WidgetRef ref,
    bool novoValor,
  ) async {
    if (!novoValor) {
      final ok = await confirmar(
        context,
        titulo: 'Desativar aluno?',
        mensagem:
            '${aluno.nome} não conseguirá mais entrar no app. Os treinos e o '
            'histórico continuam guardados e você pode reativar quando quiser.',
        textoConfirmar: 'Desativar',
        perigo: true,
      );
      if (!ok) return;
    }
    // Depois de esperar o diálogo, confere se a tela ainda existe.
    if (!context.mounted) return;
    try {
      await ref.read(adminRepositoryProvider).definirAtivo(aluno.id, novoValor);
      ref.invalidate(alunoProvider(aluno.id));
      ref.invalidate(alunosProvider);
    } catch (e) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  Future<void> _excluirDeVez(BuildContext context, WidgetRef ref) async {
    final nome = await pedirNomeParaExcluir(
      context,
      titulo: 'Excluir aluno de vez?',
      mensagem:
          'Apaga o login, os treinos e todo o histórico de ${aluno.nome}. '
          'Não dá para desfazer.',
      nomeEsperado: aluno.nome,
    );
    if (nome == null || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .excluirPessoa(id: aluno.id, confirmacao: nome);
      ref.invalidate(alunosProvider);
      if (context.mounted) {
        mostrarMensagem(context, 'Aluno excluído.');
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  Future<void> _atualizar(WidgetRef ref) async {
    ref.invalidate(alunoProvider(aluno.id));
    ref.invalidate(treinosDoAlunoProvider(aluno.id));
    try {
      await ref.read(treinosDoAlunoProvider(aluno.id).future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final treinos = ref.watch(treinosDoAlunoProvider(aluno.id));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          onRefresh: () => _atualizar(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ---- Cartão do aluno ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: Text(
                              inicial(aluno.nome),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  aluno.nome,
                                  style: tema.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(aluno.email ?? ''),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if ((aluno.observacoes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          aluno.observacoes!,
                          style: tema.textTheme.bodyMedium,
                        ),
                      ],
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aluno ativo'),
                        subtitle: Text(
                          aluno.ativo
                              ? 'Pode entrar no app e ver os treinos.'
                              : 'Sem acesso ao app.',
                        ),
                        value: aluno.ativo,
                        onChanged: (v) => _alternarAtivo(context, ref, v),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: compactoPreenchido(),
                            onPressed: () => context.push(
                              Uri(
                                path: Rotas.alunoProgresso(aluno.id),
                                queryParameters: {
                                  'nome': primeiroNome(aluno.nome),
                                },
                              ).toString(),
                            ),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Ver progresso'),
                          ),
                          OutlinedButton.icon(
                            style: compactoContorno(),
                            onPressed: () => abrirRedefinirSenha(context, aluno),
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Redefinir senha'),
                          ),
                          if (!aluno.ativo &&
                              (ref.watch(currentProfileProvider)?.isAdmin ??
                                  false))
                            OutlinedButton.icon(
                              style: compactoContorno(),
                              onPressed: () => _excluirDeVez(context, ref),
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Excluir de vez'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Treinos da semana',
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),

              // ---- Os 7 dias ----
              treinos.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (erro, _) => SizedBox(
                  height: 220,
                  child: ErroView(
                    mensagem: mensagemDeErro(erro),
                    onTentarNovamente: () =>
                        ref.invalidate(treinosDoAlunoProvider(aluno.id)),
                  ),
                ),
                data: (lista) => Column(
                  children: [
                    for (final dia in ordemDaSemana)
                      _DiaCard(
                        aluno: aluno,
                        dia: dia,
                        treino: lista.where((t) => t.dia == dia).firstOrNull,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaCard extends ConsumerWidget {
  const _DiaCard({
    required this.aluno,
    required this.dia,
    required this.treino,
  });

  final Profile aluno;
  final int dia;
  final Workout? treino;

  Future<void> _duplicar(BuildContext context, WidgetRef ref) async {
    final destino = await showDialog<DestinoDuplicacao>(
      context: context,
      builder: (_) => DuplicarTreinoDialog(alunoAtualId: aluno.id, diaAtual: dia),
    );
    if (destino == null || !context.mounted) return;

    try {
      await ref.read(adminRepositoryProvider).duplicarTreino(
            treinoId: treino!.id,
            alunoDestinoId: destino.alunoId,
            diaDestino: destino.dia,
          );
      ref.invalidate(treinosDoAlunoProvider(destino.alunoId));
      ref.invalidate(treinosDoAlunoProvider(aluno.id));
      if (context.mounted) {
        mostrarMensagem(context, 'Treino duplicado!');
      }
    } catch (e) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  Future<void> _remover(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover treino?',
      mensagem:
          'O treino de ${nomeDoDia(dia).toLowerCase()} ("${treino!.titulo}") será apagado, '
          'junto com os exercícios dele. Isso não pode ser desfeito.',
      textoConfirmar: 'Remover',
      perigo: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(adminRepositoryProvider).removerTreino(treino!.id);
      ref.invalidate(treinosDoAlunoProvider(aluno.id));
      if (context.mounted) {
        mostrarMensagem(context, 'Treino removido.');
      }
    } catch (e) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final t = treino;

    // Dia SEM treino
    if (t == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeDoDia(dia),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Sem treino', style: tema.textTheme.bodyMedium),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: compactoPreenchido(),
                onPressed: () =>
                    context.push(Rotas.treinoEditar(aluno.id, dia)),
                child: const Text('Montar'),
              ),
            ],
          ),
        ),
      );
    }

    // Dia COM treino: cartão que expande para mostrar os exercícios.
    final qtd = t.itens.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Remove as linhas divisórias que o ExpansionTile desenha por padrão.
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          nomeDoDia(dia),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${t.titulo} · $qtd ${qtd == 1 ? 'exercício' : 'exercícios'}'),
        children: [
          for (final item in t.itens)
            ListTile(
              dense: true,
              title: Text(
                item.exerciseNome,
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text(
                [
                  item.resumo,
                  if ((item.observacao ?? '').trim().isNotEmpty)
                    item.observacao!.trim(),
                ].join('\n'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      context.push(Rotas.treinoEditar(aluno.id, dia)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: () => _duplicar(context, ref),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicar'),
                ),
                TextButton.icon(
                  onPressed: () => _remover(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: tema.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
