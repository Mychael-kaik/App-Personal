import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dia_semana.dart';
import '../../../core/mensagens.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/estados.dart';
import '../data/admin_providers.dart';
import '../domain/workout.dart';
import 'workout_item_sheet.dart';

/// Monta (ou edita) o treino de UM aluno em UM dia da semana.
class WorkoutEditorPage extends ConsumerWidget {
  const WorkoutEditorPage({super.key, required this.alunoId, required this.dia});

  final String alunoId;
  final int dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treinos = ref.watch(treinosDoAlunoProvider(alunoId));
    final aluno = ref.watch(alunoProvider(alunoId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nomeDoDia(dia)),
            if (aluno.hasValue)
              Text(
                aluno.value!.nome,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: treinos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () =>
              ref.invalidate(treinosDoAlunoProvider(alunoId)),
        ),
        data: (lista) => _EditorForm(
          alunoId: alunoId,
          dia: dia,
          // Se já existe treino nesse dia, estamos EDITANDO; senão, criando.
          treino: lista.where((t) => t.dia == dia).firstOrNull,
        ),
      ),
    );
  }
}

/// Um item "em rascunho": ainda não foi salvo no banco.
/// A [chave] identifica o cartão na lista arrastável.
class _ItemRascunho {
  _ItemRascunho(this.chave, this.item);

  final int chave;
  WorkoutItem item;
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({
    required this.alunoId,
    required this.dia,
    required this.treino,
  });

  final String alunoId;
  final int dia;
  final Workout? treino;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final List<_ItemRascunho> _itens = [];
  int _proximaChave = 0;

  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final t = widget.treino;
    if (t != null) {
      _tituloCtrl.text = t.titulo;
      for (final item in t.itens) {
        _itens.add(_ItemRascunho(_proximaChave++, item));
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    final novo = await abrirFormularioItem(context);
    if (novo == null || !mounted) return;
    setState(() {
      _itens.add(_ItemRascunho(_proximaChave++, novo));
      _erro = null;
    });
  }

  Future<void> _editar(_ItemRascunho rascunho) async {
    final editado = await abrirFormularioItem(context, inicial: rascunho.item);
    if (editado == null || !mounted) return;
    setState(() => rascunho.item = editado);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itens.isEmpty) {
      setState(() => _erro = 'Adicione pelo menos um exercício ao treino.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      await ref.read(adminRepositoryProvider).salvarTreino(
            treinoId: widget.treino?.id,
            alunoId: widget.alunoId,
            dia: widget.dia,
            titulo: _tituloCtrl.text.trim(),
            // A posição de cada item na lista vira a "ordem" no banco.
            itens: _itens.map((r) => r.item).toList(),
          );
      ref.invalidate(treinosDoAlunoProvider(widget.alunoId));
      if (!mounted) return;
      mostrarMensagem(context, 'Treino salvo!');
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    TextFormField(
                      controller: _tituloCtrl,
                      enabled: !_salvando,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 17),
                      decoration: InputDecoration(
                        labelText: 'Título do treino',
                        hintText: 'Ex.: Peito e tríceps',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) =>
                          Validators.nome(v, campo: 'O título', max: 60),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _itens.isEmpty
                          ? 'Exercícios'
                          : 'Exercícios (${_itens.length})',
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (_itens.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Segure e arraste o ícone ≡ para mudar a ordem.',
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_itens.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Nenhum exercício ainda. Toque em "Adicionar exercício".',
                            textAlign: TextAlign.center,
                            style: tema.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _itens.length,
                        
                        onReorderItem: (antigo, novo) {
                          setState(() {
                            final movido = _itens.removeAt(antigo);
                            _itens.insert(novo, movido);
                          });
                        },

                        itemBuilder: (context, index) {
                          final rascunho = _itens[index];
                          final item = rascunho.item;
                          final obs = (item.observacao ?? '').trim();
                          return Card(
                            key: ValueKey(rascunho.chave),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: _salvando ? null : () => _editar(rascunho),
                              contentPadding:
                                  const EdgeInsets.only(left: 16, right: 4),
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(
                                item.exerciseNome,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                obs.isEmpty ? item.resumo : '${item.resumo}\n$obs',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Remover do treino',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: _salvando
                                        ? null
                                        : () => setState(
                                              () => _itens.removeAt(index),
                                            ),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _salvando ? null : _adicionar,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar exercício'),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 16),
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
                  ],
                ),
              ),
            ),
            // Barra fixa embaixo com o botão principal.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
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
                      : const Text('Salvar treino'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
