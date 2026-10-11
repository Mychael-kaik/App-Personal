import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mensagens.dart';
import '../../../core/validators.dart';
import '../data/admin_providers.dart';
import '../domain/exercise.dart';

/// Abre a folha inferior para criar (exercicio == null) ou editar um exercício.
Future<void> abrirFormularioExercicio(
  BuildContext context, {
  Exercise? exercicio,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ExerciseSheet(exercicio: exercicio),
  );
}

class ExerciseSheet extends ConsumerStatefulWidget {
  const ExerciseSheet({super.key, this.exercicio});

  final Exercise? exercicio;

  @override
  ConsumerState<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends ConsumerState<ExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descricaoCtrl;
  // Grupos escolhidos (pode ser mais de um).
  List<String> _grupos = [];
  // Opções mostradas: os grupos padrão + algum grupo antigo que o exercício
  // já tinha e que não está na lista padrão (assim ele não se perde).
  late final List<String> _opcoes;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.exercicio != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercicio;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _descricaoCtrl = TextEditingController(text: e?.descricao ?? '');
    _grupos = e?.grupos ?? [];
    _opcoes = [
      ...gruposMusculares,
      ..._grupos.where((g) => !gruposMusculares.contains(g)),
    ];
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final nome = _nomeCtrl.text.trim();
    final descricao =
        _descricaoCtrl.text.trim().isEmpty ? null : _descricaoCtrl.text.trim();

    final grupoMuscular = Exercise.juntarGrupos(_grupos);

    try {
      if (_editando) {
        await repo.atualizarExercicio(
          widget.exercicio!.id,
          nome: nome,
          grupoMuscular: grupoMuscular,
          descricao: descricao,
        );
      } else {
        await repo.criarExercicio(
          nome: nome,
          grupoMuscular: grupoMuscular,
          descricao: descricao,
        );
      }
      ref.invalidate(exerciciosProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      // Sobe a folha quando o teclado abre.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando ? 'Editar exercício' : 'Novo exercício',
                style: tema.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                enabled: !_salvando,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  labelText: 'Nome do exercício',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => Validators.nome(v, campo: 'O nome'),
              ),
              const SizedBox(height: 16),
              // Seleção múltipla: cada botão liga/desliga um grupo.
              FormField<List<String>>(
                initialValue: _grupos,
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Escolha pelo menos um grupo muscular.'
                    : null,
                builder: (campo) {
                  final escolhidos = campo.value ?? <String>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grupos musculares',
                        style: tema.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Toque para escolher um ou mais.',
                        style: tema.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final g in _opcoes)
                            FilterChip(
                              label: Text(g, style: const TextStyle(fontSize: 15)),
                              selected: escolhidos.contains(g),
                              onSelected: _salvando
                                  ? null
                                  : (marcado) {
                                      final novo = [...escolhidos];
                                      if (marcado) {
                                        novo.add(g);
                                      } else {
                                        novo.remove(g);
                                      }
                                      _grupos = novo;
                                      campo.didChange(novo);
                                    },
                            ),
                        ],
                      ),
                      if (campo.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            campo.errorText!,
                            style: TextStyle(
                              fontSize: 13,
                              color: tema.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoCtrl,
                enabled: !_salvando,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  helperText: 'Como executar, dicas de postura...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => Validators.tamanhoMaximo(v, 300),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _erro!,
                    style: TextStyle(
                      fontSize: 15,
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
