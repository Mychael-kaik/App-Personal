import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/widgets/picker_field.dart';
import '../../auth/domain/profile.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/admin_providers.dart';
import '../domain/academia.dart';

/// Passa o [aluno] para outro professor (só o administrador geral).
/// Os treinos e o histórico do aluno vão junto. Devolve true se moveu.
Future<bool> abrirMoverAluno(BuildContext context, Profile aluno) async {
  final moveu = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MoverAlunoDialog(aluno: aluno),
  );
  return moveu ?? false;
}

class _MoverAlunoDialog extends ConsumerStatefulWidget {
  const _MoverAlunoDialog({required this.aluno});

  final Profile aluno;

  @override
  ConsumerState<_MoverAlunoDialog> createState() => _MoverAlunoDialogState();
}

class _MoverAlunoDialogState extends ConsumerState<_MoverAlunoDialog> {
  final _formKey = GlobalKey<FormState>();
  Profile? _professor;
  bool _salvando = false;
  String? _erro;

  Future<void> _mover() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final aluno = widget.aluno;
    try {
      await ref.read(adminRepositoryProvider).moverAluno(
            alunoId: aluno.id,
            professorId: _professor!.id,
          );
      ref.invalidate(alunoProvider(aluno.id));
      ref.invalidate(alunosProvider);
      ref.invalidate(exerciciosDoAlunoProvider(aluno.id));
      ref.invalidate(treinosDoAlunoProvider(aluno.id));
      ref.invalidate(painelDeHojeProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aluno = widget.aluno;
    final professores = ref.watch(professoresProvider);
    final academias = ref.watch(academiasProvider).value ?? const <Academia>[];
    String nomeAcademia(String? id) =>
        academias.where((a) => a.id == id).firstOrNull?.nome ?? '';

    return AlertDialog(
      title: const Text('Mudar de professor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${aluno.nome} passa a ser aluno do professor escolhido. Os '
                'treinos e o histórico vão junto; o professor anterior perde o '
                'acesso a este aluno.',
              ),
              const SizedBox(height: 16),
              professores.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(mensagemDeErro(e)),
                data: (lista) {
                  final opcoes = lista
                      .where((p) => p.ativo && p.id != aluno.professorId)
                      .toList();
                  if (opcoes.isEmpty) {
                    return const Text('Não há outro professor ativo disponível.');
                  }
                  return PickerField<Profile>(
                    rotulo: 'Novo professor',
                    icone: Icons.sports_outlined,
                    opcoes: opcoes,
                    rotuloDe: (p) => p.nome,
                    subtituloDe: (p) => nomeAcademia(p.academiaId),
                    valorInicial: _professor,
                    onChanged: (p) => setState(() => _professor = p),
                    validator: (v) => v == null ? 'Escolha o professor.' : null,
                  );
                },
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  style: TextStyle(color: tema.colorScheme.error, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: _salvando ? null : _mover,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Text('Mover'),
        ),
      ],
    );
  }
}
