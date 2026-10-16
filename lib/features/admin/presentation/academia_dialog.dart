import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../data/admin_providers.dart';
import '../domain/academia.dart';

/// Cria (academia == null) ou edita uma academia. Só o administrador geral
/// consegue gravar (o banco recusa qualquer outra pessoa).
Future<void> abrirFormularioAcademia(
  BuildContext context, {
  Academia? academia,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AcademiaDialog(academia: academia),
  );
}

class _AcademiaDialog extends ConsumerStatefulWidget {
  const _AcademiaDialog({this.academia});

  final Academia? academia;

  @override
  ConsumerState<_AcademiaDialog> createState() => _AcademiaDialogState();
}

class _AcademiaDialogState extends ConsumerState<_AcademiaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late bool _ativo;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.academia != null;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.academia?.nome ?? '');
    _ativo = widget.academia?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;

    // Suspender uma academia derruba o acesso de TODOS os professores e alunos dela.
    if (_editando && widget.academia!.ativo && !_ativo) {
      final ok = await confirmar(
        context,
        titulo: 'Suspender a academia?',
        mensagem:
            'Todos os professores e alunos de "${widget.academia!.nome}" perdem '
            'o acesso ao app até você reativar. Nada é apagado.',
        textoConfirmar: 'Suspender',
        perigo: true,
      );
      if (!ok || !mounted) return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final nome = _nomeCtrl.text.trim();
    try {
      if (_editando) {
        await repo.atualizarAcademia(
          widget.academia!.id,
          nome: nome,
          ativo: _ativo,
        );
      } else {
        await repo.criarAcademia(nome);
      }
      ref.invalidate(academiasProvider);
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
    return AlertDialog(
      title: Text(_editando ? 'Editar academia' : 'Nova academia'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nomeCtrl,
              enabled: !_salvando,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(labelText: 'Nome da academia'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Informe o nome (2 a 100 letras).';
                return null;
              },
            ),
            if (_editando)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Academia ativa'),
                subtitle: Text(
                  _ativo
                      ? 'Professores e alunos podem entrar.'
                      : 'Todos perdem o acesso até reativar.',
                ),
                value: _ativo,
                onChanged: _salvando ? null : (v) => setState(() => _ativo = v),
              ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(
                _erro!,
                style: TextStyle(color: tema.colorScheme.error, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
