import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/senha.dart';
import '../../../core/validators.dart';
import '../../auth/domain/profile.dart';
import '../data/admin_providers.dart';

/// Abre o diálogo para o personal definir uma NOVA senha para o [aluno].
///
/// O diálogo só fecha pelos botões (barrierDismissible: false): assim um
/// toque fora da caixa não faz o personal perder a senha recém-definida
/// antes de anotá-la.
Future<void> abrirRedefinirSenha(BuildContext context, Profile aluno) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RedefinirSenhaDialog(aluno: aluno),
  );
}

class RedefinirSenhaDialog extends ConsumerStatefulWidget {
  const RedefinirSenhaDialog({super.key, required this.aluno});

  final Profile aluno;

  @override
  ConsumerState<RedefinirSenhaDialog> createState() =>
      _RedefinirSenhaDialogState();
}

class _RedefinirSenhaDialogState extends ConsumerState<RedefinirSenhaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _senhaCtrl = TextEditingController();

  bool _ocultar = false; // começa visível: o personal precisa ler e anotar
  bool _salvando = false;
  String? _erro;

  /// Preenchida só depois de dar certo: troca o diálogo para a tela
  /// "Senha redefinida!" com os dados para passar ao aluno.
  String? _senhaDefinida;
  bool _copiado = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final senha = _senhaCtrl.text;
    try {
      await ref
          .read(adminRepositoryProvider)
          .redefinirSenha(alunoId: widget.aluno.id, senha: senha);
      if (mounted) setState(() => _senhaDefinida = senha);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final senha = _senhaDefinida;
    return senha == null ? _construirFormulario(context) : _construirSucesso(senha);
  }

  // ------------------------- Passo 1: digitar a nova senha ---------------
  Widget _construirFormulario(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      title: const Text('Redefinir senha'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Defina uma nova senha para ${widget.aluno.nome}. '
                'A senha antiga deixa de valer na hora.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaCtrl,
                enabled: !_salvando,
                autofocus: true,
                obscureText: _ocultar,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [LengthLimitingTextInputFormatter(72)],
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  helperText: 'Mínimo de 6 caracteres.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _ocultar
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
                validator: Validators.senhaNova,
                onFieldSubmitted: (_) => _redefinir(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _salvando
                      ? null
                      : () => setState(() {
                            _senhaCtrl.text = gerarSenhaAleatoria();
                            _ocultar = false;
                            _erro = null;
                          }),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Gerar senha'),
                ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: _salvando ? null : _redefinir,
          child: _salvando
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Text('Redefinir'),
        ),
      ],
    );
  }

  // ------------------------- Passo 2: mostrar os dados -------------------
  Widget _construirSucesso(String senha) {
    final texto = 'E-mail: ${widget.aluno.email ?? ''}\nNova senha: $senha';

    return AlertDialog(
      title: const Text('Senha redefinida!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passe estes dados para ${widget.aluno.nome} entrar no app:'),
          const SizedBox(height: 12),
          SelectableText(
            texto,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Anote agora: por segurança, a senha não poderá ser vista depois.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (mounted) setState(() => _copiado = true);
          },
          icon: Icon(_copiado ? Icons.check : Icons.copy),
          label: Text(_copiado ? 'Copiado!' : 'Copiar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
