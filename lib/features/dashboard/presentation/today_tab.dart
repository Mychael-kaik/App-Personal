import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../data/dashboard_repository.dart';
import '../domain/painel_hoje.dart';

/// Aba "Hoje" do professor: quem treinou hoje e quanto do treino cada aluno
/// já fez. Tocar num aluno abre a tela dele.
class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  Future<void> _atualizar(WidgetRef ref) async {
    ref.invalidate(painelDeHojeProvider);
    try {
      await ref.read(painelDeHojeProvider.future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painel = ref.watch(painelDeHojeProvider);

    return painel.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => ref.invalidate(painelDeHojeProvider),
      ),
      data: (p) {
        if (p.alunos.isEmpty) {
          return const EstadoVazio(
            icone: Icons.group_add_outlined,
            titulo: 'Nenhum aluno ativo',
            mensagem: 'Cadastre alunos na aba "Alunos" para acompanhá-los aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => _atualizar(ref),
          child: _Lista(painel: p),
        );
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.painel});

  final PainelDeHoje painel;

  static const _secoes = <(SituacaoHoje, String)>[
    (SituacaoHoje.emAndamento, 'Treinando agora'),
    (SituacaoHoje.concluiu, 'Concluíram o treino'),
    (SituacaoHoje.naoComecou, 'Ainda não começaram'),
    (SituacaoHoje.semTreino, 'Sem treino hoje'),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          // Sempre rolável, para o "puxar para atualizar" funcionar mesmo
          // com poucos alunos.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              formatarDataLonga(painel.data),
              style: tema.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Resumo(
                    valor: '${painel.treinaram}',
                    total: painel.comTreino,
                    rotulo: 'treinaram',
                    icone: Icons.directions_run,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Resumo(
                    valor: '${painel.concluiram}',
                    total: painel.comTreino,
                    rotulo: 'concluíram',
                    icone: Icons.emoji_events_outlined,
                  ),
                ),
              ],
            ),
            for (final (situacao, titulo) in _secoes)
              ..._secao(context, situacao, titulo),
          ],
        ),
      ),
    );
  }

  List<Widget> _secao(BuildContext context, SituacaoHoje situacao, String titulo) {
    final doGrupo = painel.alunos.where((a) => a.situacao == situacao).toList();
    if (doGrupo.isEmpty) return const [];
    final tema = Theme.of(context);
    return [
      const SizedBox(height: 18),
      Text(
        '$titulo (${doGrupo.length})',
        style:
            tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      for (final a in doGrupo) _CartaoDoAluno(item: a),
    ];
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.valor,
    required this.total,
    required this.rotulo,
    required this.icone,
  });

  final String valor;
  final int total;
  final String rotulo;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icone, color: cores.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$valor de $total',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cores.onPrimaryContainer,
                  ),
                ),
                Text(
                  '$rotulo (com treino hoje)',
                  style: TextStyle(
                    fontSize: 12,
                    color: cores.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoDoAluno extends StatelessWidget {
  const _CartaoDoAluno({required this.item});

  final AlunoHoje item;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final aluno = item.aluno;

    final String detalhe;
    if (!item.temTreino) {
      detalhe = 'Dia de descanso';
    } else {
      detalhe = '${item.tituloTreino} · ${item.feitos} de ${item.total} '
          '${item.total == 1 ? 'exercício' : 'exercícios'}';
    }

    final concluiu = item.situacao == SituacaoHoje.concluiu;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Rotas.alunoDetalhe(aluno.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    concluiu ? cores.primary : cores.surfaceContainerHighest,
                foregroundColor: concluiu ? cores.onPrimary : null,
                child: concluiu
                    ? const Icon(Icons.check)
                    : Text(inicial(aluno.nome)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aluno.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detalhe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium,
                    ),
                    if (item.temTreino) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: item.progresso,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cores.outline),
            ],
          ),
        ),
      ),
    );
  }
}
