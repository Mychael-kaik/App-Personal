import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/picker_field.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_providers.dart';
import '../domain/academia.dart';

/// Cadastrar uma pessoa nova (alunoId == null) ou editar uma existente.
///  - [tipo]: aluno (padrão) ou professor (só o administrador geral cadastra);
///  - [professorIdInicial]: já deixa um professor escolhido (novo aluno).
/// (Editar serve para aluno e professor: o título muda conforme o perfil.)
class StudentFormPage extends ConsumerWidget {
  const StudentFormPage({
    super.key,
    this.alunoId,
    this.tipo = Perfil.aluno,
    this.professorIdInicial,
  });

  final String? alunoId;
  final Perfil tipo;
  final String? professorIdInicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = alunoId;
    if (id == null) {
      return _StudentForm(tipo: tipo, professorIdInicial: professorIdInicial);
    }

    // Editando: primeiro carregamos os dados atuais do aluno.
    final aluno = ref.watch(alunoProvider(id));
    return aluno.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Editar cadastro')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (erro, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar cadastro')),
        body: ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () => ref.invalidate(alunoProvider(id)),
        ),
      ),
      data: (dados) => _StudentForm(aluno: dados, tipo: dados.perfil),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({this.aluno, required this.tipo, this.professorIdInicial});

  final Profile? aluno;
  final Perfil tipo;
  final String? professorIdInicial;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _senhaCtrl;
  late final TextEditingController _obsCtrl;

  // Escolhas do administrador geral ao CADASTRAR (o professor não escolhe nada).
  Profile? _professor;
  Academia? _academia;

  bool _salvando = false;
  bool _ocultarSenha = false; // começa visível: o personal precisa ler e anotar
  String? _erro;

  bool get _editando => widget.aluno != null;
  bool get _ehProfessor => widget.tipo == Perfil.professor;
  String get _palavra => _ehProfessor ? 'professor' : 'aluno';

  @override
  void initState() {
    super.initState();
    final a = widget.aluno;
    _nomeCtrl = TextEditingController(text: a?.nome ?? '');
    _emailCtrl = TextEditingController(text: a?.email ?? '');
    _senhaCtrl = TextEditingController();
    _obsCtrl = TextEditingController(text: a?.observacoes ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  /// Senha aleatória de 8 caracteres, sem letras que se confundem (0/O, 1/l/I).
  String _gerarSenha() {
    const caracteres = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
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
    final observacoes = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();

    try {
      if (_editando) {
        final id = widget.aluno!.id;
        await repo.atualizarAluno(id, nome: nome, observacoes: observacoes);
        ref.invalidate(alunosProvider);
        ref.invalidate(professoresProvider);
        ref.invalidate(alunoProvider(id));
        if (!mounted) return;
        mostrarMensagem(context, 'Cadastro atualizado!');
        context.pop();
      } else {
        final email = _emailCtrl.text.trim().toLowerCase();
        final senha = _senhaCtrl.text;
        await repo.cadastrarPessoa(
          tipo: widget.tipo,
          nome: nome,
          email: email,
          senha: senha,
          observacoes: observacoes,
          professorId: _professor?.id,
          academiaId: _academia?.id,
        );
        ref.invalidate(alunosProvider);
        ref.invalidate(professoresProvider);
        if (!mounted) return;
        await _mostrarDadosDeAcesso(email, senha);
        if (!mounted) return;
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Depois de cadastrar, mostra e-mail e senha para passar à pessoa cadastrada.
  /// A senha só aparece aqui: depois ela fica guardada de forma criptografada.
  Future<void> _mostrarDadosDeAcesso(String email, String senha) {
    final texto = 'E-mail: $email\nSenha: $senha';
    var copiado = false;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      // StatefulBuilder deixa só o diálogo se redesenhar, para o botão
      // mostrar "Copiado!" (um aviso na parte de baixo ficaria escondido
      // atrás do diálogo).
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialogo) => AlertDialog(
          title: Text(_ehProfessor ? 'Professor cadastrado!' : 'Aluno cadastrado!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Passe estes dados para o $_palavra entrar no app:'),
              const SizedBox(height: 12),
              SelectableText(
                texto,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                if (ctx.mounted) setStateDialogo(() => copiado = true);
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

  InputDecoration _decoracao(String rotulo, IconData icone,
      {Widget? sufixo, String? ajuda}) {
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

  /// Só o administrador geral escolhe: a ACADEMIA do professor novo, ou o
  /// PROFESSOR do aluno novo. (O professor cadastra alunos sempre para ele mesmo.)
  List<Widget> _escolhas() {
    if (_editando) return const [];
    final eu = ref.watch(currentProfileProvider);
    if (eu == null || !eu.isAdmin) return const [];

    if (_ehProfessor) {
      final academias = ref.watch(academiasProvider);
      return [
        academias.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensagemDeErro(e)),
          data: (lista) {
            final ativas = lista.where((a) => a.ativo).toList();
            if (ativas.isEmpty) {
              return const Text(
                'Cadastre uma academia na aba "Equipe" antes de criar professores.',
                style: TextStyle(fontSize: 16),
              );
            }
            return PickerField<Academia>(
              rotulo: 'Academia',
              icone: Icons.business_outlined,
              opcoes: ativas,
              rotuloDe: (a) => a.nome,
              valorInicial: _academia,
              onChanged: (a) => setState(() => _academia = a),
              validator: (v) => v == null ? 'Escolha a academia.' : null,
            );
          },
        ),
        const SizedBox(height: 16),
      ];
    }

    final professores = ref.watch(professoresProvider);
    return [
      professores.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(mensagemDeErro(e)),
        data: (lista) {
          final ativos = lista.where((p) => p.ativo).toList();
          if (ativos.isEmpty) {
            return const Text(
              'Cadastre um professor na aba "Equipe" antes de criar alunos.',
              style: TextStyle(fontSize: 16),
            );
          }
          _professor ??= ativos
              .where((p) => p.id == widget.professorIdInicial)
              .firstOrNull;
          return PickerField<Profile>(
            rotulo: 'Professor do aluno',
            icone: Icons.sports_outlined,
            opcoes: ativos,
            rotuloDe: (p) => p.nome,
            valorInicial: _professor,
            onChanged: (p) => setState(() => _professor = p),
            validator: (v) => v == null ? 'Escolha o professor.' : null,
          );
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editando ? 'Editar $_palavra' : 'Novo $_palavra',
        ),
      ),
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
                    ..._escolhas(),
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
                      // O e-mail é o login: não pode mudar depois de criado.
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
                            tooltip:
                                _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
                            icon: Icon(_ocultarSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                        ),
                        validator: Validators.senhaNova,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _salvando
                              ? null
                              : () => setState(() {
                                    _senhaCtrl.text = _gerarSenha();
                                    _ocultarSenha = false;
                                  }),
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
                        ajuda: 'Ex.: lesão no joelho, objetivo, horário.',
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
                                  : 'Cadastrar $_palavra',
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
