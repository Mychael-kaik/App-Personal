import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/widgets/picker_field.dart';
import '../../auth/domain/profile.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/admin_providers.dart';
import '../domain/academia.dart';

/// Desativa o [professor]. Se ele tem [qtdAlunos] > 0, pede o professor de
/// destino e passa todos os alunos de uma vez. Devolve true se desativou.
Future<bool> abrirDesativarProfessor(
  BuildContext context,
  Profile professor,
  int qtdAlunos,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DesativarProfessorDialog(
      professor: professor,
      qtdAlunos: qtdAlunos,
    ),
  );
  return ok ?? false;
}

class _DesativarProfessorDialog extends ConsumerStatefulWidget {
  const _DesativarProfessorDialog({
    required this.professor,
    required this.qtdAlunos,
  });

  final Profile professor;
  final int qtdAlunos;

  @override
  ConsumerState<_DesativarProfessorDialog> createState() =>
      _DesativarProfessorDialogState();
}

class _DesativarProfessorDialogState
    extends ConsumerState<_DesativarProfessorDialog> {
  final _formKey = GlobalKey<FormState>();
  Profile? _destino;
  bool _salvando = false;
  String? _erro;

  bool get _precisaDestino => widget.qtdAlunos > 0;

  Future<void> _desativar() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(adminRepositoryProvider).desativarProfessor(
            professorId: widget.professor.id,
            destinoId: _precisaDestino ? _destino!.id : null,
          );
      ref.invalidate(professoresProvider);
      ref.invalidate(alunosProvider);
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
    final p = widget.professor;
    final professores = ref.watch(professoresProvider);
    final academias = ref.watch(academiasProvider).value ?? const <Academia>[];
    String nomeAcademia(String? id) =>
        academias.where((a) => a.id == id).firstOrNull?.nome ?? '';

    final n = widget.qtdAlunos;
    return AlertDialog(
      title: const Text('Desativar professor?'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _precisaDestino
                    ? '${p.nome} não conseguirá mais entrar no app e tem '
                        '$n ${n == 1 ? 'aluno' : 'alunos'}. Escolha quem vai '
                        'assumir ${n == 1 ? 'o aluno' : 'todos'}: os treinos e o '
                        'histórico vão junto, e os exercícios usados nesses '
                        'treinos também.'
                    : '${p.nome} não conseguirá mais entrar no app. Você pode '
                        'reativar quando quiser.',
              ),
              if (_precisaDestino) ...[
                const SizedBox(height: 16),
                professores.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(mensagemDeErro(e)),
                  data: (lista) {
                    final opcoes = lista
                        .where((o) => o.ativo && o.id != p.id)
                        .toList()
                      // Professores da mesma academia primeiro.
                      ..sort((a, b) {
                        final sa = a.academiaId == p.academiaId ? 0 : 1;
                        final sb = b.academiaId == p.academiaId ? 0 : 1;
                        return sa != sb ? sa - sb : a.nome.compareTo(b.nome);
                      });
                    if (opcoes.isEmpty) {
                      return const Text(
                        'Não há outro professor ativo para receber os alunos. '
                        'Cadastre um antes de desativar.',
                      );
                    }
                    return PickerField<Profile>(
                      rotulo: 'Professor que assume os alunos',
                      icone: Icons.sports_outlined,
                      opcoes: opcoes,
                      rotuloDe: (o) => o.nome,
                      subtituloDe: (o) => nomeAcademia(o.academiaId),
                      valorInicial: _destino,
                      onChanged: (o) => setState(() => _destino = o),
                      validator: (v) =>
                          v == null ? 'Escolha o professor de destino.' : null,
                    );
                  },
                ),
              ],
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
          onPressed: _salvando ? null : _desativar,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Text(_precisaDestino ? 'Mover e desativar' : 'Desativar'),
        ),
      ],
    );
  }
}
