import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mensagens.dart';
import '../../../core/widgets/estados.dart';
import '../data/admin_providers.dart';
import '../domain/exercise.dart';
import 'exercise_sheet.dart';

/// Aba "Exercícios": biblioteca com filtro por grupo muscular.
class ExercisesTab extends ConsumerStatefulWidget {
  const ExercisesTab({super.key});

  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<ExercisesTab> {
  String? _grupo; // null = todos

  Future<void> _atualizar() async {
    ref.invalidate(exerciciosProvider);
    try {
      await ref.read(exerciciosProvider.future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  Future<void> _excluir(Exercise exercicio) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir exercício?',
      mensagem: '"${exercicio.nome}" será removido da biblioteca.',
      textoConfirmar: 'Excluir',
      perigo: true,
    );
    if (!ok) return;

    try {
      await ref.read(adminRepositoryProvider).removerExercicio(exercicio.id);
      ref.invalidate(exerciciosProvider);
      if (mounted) mostrarMensagem(context, 'Exercício excluído.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercicios = ref.watch(exerciciosProvider);

    return exercicios.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => ref.invalidate(exerciciosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const EstadoVazio(
            icone: Icons.fitness_center,
            titulo: 'Biblioteca vazia',
            mensagem:
                'Cadastre os exercícios que você usa nos treinos. Toque em "Novo exercício".',
          );
        }

        // Cada exercício pode ter vários grupos: o filtro lista cada grupo
        // uma única vez e mostra todo exercício que tenha aquele grupo.
        final grupos = lista.expand((e) => e.grupos).toSet().toList()..sort();
        // Se o grupo filtrado deixou de existir (ex.: excluímos o último), volta para "Todos".
        final grupoAtivo = grupos.contains(_grupo) ? _grupo : null;
        final filtrados = grupoAtivo == null
            ? lista
            : lista.where((e) => e.grupos.contains(grupoAtivo)).toList();

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: grupoAtivo == null,
                    onSelected: (_) => setState(() => _grupo = null),
                  ),
                  for (final g in grupos)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(g),
                        selected: grupoAtivo == g,
                        onSelected: (_) => setState(() => _grupo = g),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _atualizar,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final e = filtrados[i];
                    final descricao = (e.descricao ?? '').trim();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                        title: Text(
                          e.nome,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          descricao.isEmpty
                              ? e.grupoMuscular
                              : '${e.grupoMuscular} · $descricao',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Mais opções',
                          onSelected: (acao) {
                            if (acao == 'editar') {
                              abrirFormularioExercicio(context, exercicio: e);
                            } else {
                              _excluir(e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'editar', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                        onTap: () =>
                            abrirFormularioExercicio(context, exercicio: e),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
