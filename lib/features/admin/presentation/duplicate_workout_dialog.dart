import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dia_semana.dart';
import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/widgets/picker_field.dart';
import '../../auth/domain/profile.dart';
import '../data/admin_providers.dart';

/// Resultado do diálogo: para quem e para qual dia copiar o treino.
class DestinoDuplicacao {
  const DestinoDuplicacao(this.alunoId, this.dia);

  final String alunoId;
  final int dia;
}

/// Pergunta "copiar este treino para QUEM e para QUAL DIA?".
/// Devolve um [DestinoDuplicacao], ou null se o personal cancelar.
class DuplicarTreinoDialog extends ConsumerStatefulWidget {
  const DuplicarTreinoDialog({
    super.key,
    required this.alunoAtualId,
    required this.diaAtual,
  });

  final String alunoAtualId;
  final int diaAtual;

  @override
  ConsumerState<DuplicarTreinoDialog> createState() =>
      _DuplicarTreinoDialogState();
}

class _DuplicarTreinoDialogState extends ConsumerState<DuplicarTreinoDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _alunoId = widget.alunoAtualId;
  late int? _dia = widget.diaAtual;

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(DestinoDuplicacao(_alunoId!, _dia!));
  }

  @override
  Widget build(BuildContext context) {
    final alunos = ref.watch(alunosProvider);

    return AlertDialog(
      title: const Text('Duplicar treino'),
      content: SizedBox(
        width: double.maxFinite,
        child: alunos.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (erro, _) => Text(mensagemDeErro(erro)),
          data: (lista) {
            final atual =
                lista.where((a) => a.id == widget.alunoAtualId).firstOrNull;
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PickerField<Profile>(
                    rotulo: 'Para o aluno',
                    opcoes: lista,
                    rotuloDe: (a) => a.nome,
                    valorInicial: atual,
                    buscavel: lista.length > 8,
                    onChanged: (a) => _alunoId = a.id,
                    validator: (v) => v == null ? 'Escolha o aluno.' : null,
                  ),
                  const SizedBox(height: 16),
                  PickerField<int>(
                    rotulo: 'No dia',
                    opcoes: ordemDaSemana,
                    rotuloDe: nomeDoDia,
                    valorInicial: widget.diaAtual,
                    onChanged: (d) => _dia = d,
                    validator: (v) {
                      if (v == null) return 'Escolha o dia.';
                      // Copiar para o MESMO aluno no MESMO dia não faz sentido
                      // (e o banco recusaria: só existe 1 treino por aluno/dia).
                      if (_alunoId == widget.alunoAtualId &&
                          v == widget.diaAtual) {
                        return 'Escolha outro dia ou outro aluno.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: alunos.hasValue ? _confirmar : null,
          child: const Text('Duplicar'),
        ),
      ],
    );
  }
}
