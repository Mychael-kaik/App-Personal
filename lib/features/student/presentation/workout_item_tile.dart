import 'package:flutter/material.dart';

import '../../admin/domain/workout.dart';

/// Cartão de UM exercício do treino do aluno.
///
/// O cartão inteiro é um botão grande: tocar em qualquer lugar dele marca
/// ou desmarca o exercício como concluído.
class WorkoutItemTile extends StatelessWidget {
  const WorkoutItemTile({
    super.key,
    required this.posicao,
    required this.item,
    required this.concluido,
    required this.podeMarcar,
    required this.onAlternar,
  });

  /// Número do exercício na lista (1, 2, 3...).
  final int posicao;
  final WorkoutItem item;
  final bool concluido;

  /// false quando o treino é de outro dia (só visualização) ou quando as
  /// marcações ainda não carregaram.
  final bool podeMarcar;

  /// Chamado com o NOVO valor (true = concluído).
  final ValueChanged<bool> onAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final observacao = (item.observacao ?? '').trim();
    final corDoTexto = concluido ? cores.onSurfaceVariant : null;

    final Widget marcador;
    if (concluido) {
      marcador = Icon(Icons.check_circle, size: 36, color: cores.primary);
    } else if (podeMarcar) {
      marcador = Icon(Icons.radio_button_unchecked, size: 36, color: cores.outline);
    } else {
      // Treino de outro dia: mostra só o número do exercício.
      marcador = CircleAvatar(radius: 18, child: Text('$posicao'));
    }

    return Semantics(
      container: true,
      // null = o leitor de tela não anuncia "marcado/desmarcado".
      checked: podeMarcar ? concluido : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: concluido ? cores.primaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: podeMarcar ? () => onAlternar(!concluido) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                marcador,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.exerciseNome,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: corDoTexto,
                          decoration:
                              concluido ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if ((item.grupoMuscular ?? '').isNotEmpty)
                        Text(item.grupoMuscular!, style: tema.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(
                        item.resumo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: corDoTexto,
                        ),
                      ),
                      if (observacao.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          observacao,
                          style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: corDoTexto,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
