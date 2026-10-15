import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/domain/profile.dart';
import '../data/admin_providers.dart';

class StudentFormPage extends ConsumerWidget {
  const StudentFormPage({super.key, this.alunoId});

  final String? alunoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = alunoId;

    if (id == null) return const _StudentForm();

    final aluno = ref.watch(alunoProvider(id));

    return aluno.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Editar aluno')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (erro, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar aluno')),
        body: ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () => ref.invalidate(alunoProvider(id)),
        ),
      ),
      data: (dados) => _StudentForm(aluno: dados),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({this.aluno});

  final Profile? aluno;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _senhaCtrl;
  late final TextEditingController _obsCtrl;

  bool _salvando = false;
  bool _ocultarSenha = false;
  String? _erro;
  String _perfilNovo = 'aluno';

  bool get _editando => widget.aluno != null;

  @override
  void initState() {
    super.initState();

    final aluno = widget.aluno;
    _nomeCtrl = TextEditingController(text: aluno?.nome ?? '');
    _emailCtrl = TextEditingController(text: aluno?.email ?? '');
    _senhaCtrl = TextEditingController();
    _obsCtrl = TextEditingController(text: aluno?.observacoes ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String _gerarSenha() {
    const caracteres =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final sorteio = Random.secure();

    return List.generate(
      8,
      (_) => caracteres[sorteio.nextInt(caracteres.length)],
    ).join();
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
    final observacoes = _obsCtrl.text.trim().isEmpty
        ? null
        : _obsCtrl.text.trim();

    try {
      if (_editando) {
        final id = widget.aluno!.id;

        await repo.atualizarAluno(id, nome: nome, observacoes: observacoes);

        ref.invalidate(alunosProvider);
        ref.invalidate(alunoProvider(id));

        if (!mounted) return;

        mostrarMensagem(context, 'Aluno atualizado!');
        context.pop();
      } else {
        final email = _emailCtrl.text.trim().toLowerCase();
        final senha = _senhaCtrl.text;

        if (_perfilNovo == 'professor') {
          await repo.criarProfessor(
            nome: nome,
            email: email,
            senha: senha,
            observacoes: observacoes,
          );
        } else {
          await repo.criarAluno(
            nome: nome,
            email: email,
            senha: senha,
            observacoes: observacoes,
          );
        }

        ref.invalidate(alunosProvider);

        if (!mounted) return;

        await _mostrarDadosDeAcesso(
          email,
          senha,
          professor: _perfilNovo == 'professor',
        );

        if (!mounted) return;

        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = mensagemDeErro(e));
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _mostrarDadosDeAcesso(
    String email,
    String senha, {
    required bool professor,
  }) {
    final texto = 'E-mail: $email\nSenha: $senha';
    var copiado = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialogo) => AlertDialog(
          title: Text(
            professor ? 'Professor cadastrado!' : 'Aluno cadastrado!',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Guarde estes dados para o primeiro acesso:'),
              const SizedBox(height: 12),
              SelectableText(
                texto,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Anote agora: por segurança, a senha não poderá ser '
                'consultada novamente pelo aplicativo.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: texto));

                if (ctx.mounted) {
                  setStateDialogo(() => copiado = true);
                }
              },
              icon: Icon(copiado ? Icons.check : Icons.copy),
              label: Text(copiado ? 'Copiado!' : 'Copiar'),
            ),
            FilledButton(
              style: compactoPreenchido(),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracao(
    String rotulo,
    IconData icone, {
    Widget? sufixo,
    String? ajuda,
  }) {
    return InputDecoration(
      labelText: rotulo,
      helperText: ajuda,
      prefixIcon: Icon(icone),
      suffixIcon: sufixo,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final titulo = _editando
        ? 'Editar aluno'
        : _perfilNovo == 'professor'
        ? 'Novo professor'
        : 'Novo aluno';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_editando) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _perfilNovo,
                        decoration: _decoracao(
                          'Tipo de cadastro',
                          Icons.manage_accounts_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'aluno',
                            child: Text('Aluno'),
                          ),
                          DropdownMenuItem(
                            value: 'professor',
                            child: Text('Professor'),
                          ),
                        ],
                        onChanged: _salvando
                            ? null
                            : (valor) {
                                if (valor != null) {
                                  setState(() => _perfilNovo = valor);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nomeCtrl,
                      enabled: !_salvando,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 17),
                      decoration: _decoracao('Nome', Icons.person_outline),
                      validator: (v) => Validators.nome(v, campo: 'O nome'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !_salvando && !_editando,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(fontSize: 17),
                      decoration: _decoracao(
                        'E-mail (usado no login)',
                        Icons.mail_outline,
                        ajuda: _editando
                            ? 'O e-mail não pode ser alterado.'
                            : null,
                      ),
                      validator: _editando ? null : Validators.email,
                    ),
                    if (!_editando) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaCtrl,
                        enabled: !_salvando,
                        obscureText: _ocultarSenha,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 17),
                        decoration: _decoracao(
                          'Senha inicial',
                          Icons.lock_outline,
                          ajuda: 'Mínimo de 6 caracteres.',
                          sufixo: IconButton(
                            tooltip: _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(
                              _ocultarSenha
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _ocultarSenha = !_ocultarSenha;
                              });
                            },
                          ),
                        ),
                        validator: Validators.senhaNova,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _salvando
                              ? null
                              : () {
                                  setState(() {
                                    _senhaCtrl.text = _gerarSenha();
                                    _ocultarSenha = false;
                                  });
                                },
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Gerar senha'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _obsCtrl,
                      enabled: !_salvando,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 17),
                      decoration: _decoracao(
                        'Observações (opcional)',
                        Icons.notes_outlined,
                        ajuda: 'Ex.: objetivo, horário ou informações úteis.',
                      ),
                      validator: (v) => Validators.tamanhoMaximo(v, 500),
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
                    const SizedBox(height: 24),
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
                          : Text(
                              _editando
                                  ? 'Salvar alterações'
                                  : _perfilNovo == 'professor'
                                  ? 'Cadastrar professor'
                                  : 'Cadastrar aluno',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
