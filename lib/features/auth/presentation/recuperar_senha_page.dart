import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_exception.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/validators.dart';
import '../data/auth_repository.dart';

/// "Esqueci minha senha" em 2 passos:
///  1) a pessoa informa o e-mail e recebe um CÓDIGO (números) por e-mail;
///  2) digita o código e a nova senha.
/// Usamos código (e não link) porque funciona em qualquer navegador/aparelho,
/// mesmo abrindo o e-mail em outro lugar.
class RecuperarSenhaPage extends ConsumerStatefulWidget {
  const RecuperarSenhaPage({super.key});

  @override
  ConsumerState<RecuperarSenhaPage> createState() => _RecuperarSenhaPageState();
}

class _RecuperarSenhaPageState extends ConsumerState<RecuperarSenhaPage> {
  static const _esperaReenvio = 60;

  final _emailForm = GlobalKey<FormState>();
  final _codigoForm = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _senha2Ctrl = TextEditingController();

  bool _codigoEnviado = false;
  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erro;
  int _restante = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _senha2Ctrl.dispose();
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    setState(() => _restante = _esperaReenvio);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _restante--);
      if (_restante <= 0) t.cancel();
    });
  }

  Future<void> _enviarCodigo() async {
    if (_carregando) return;
    if (!_emailForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .pedirCodigoDeRecuperacao(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      _iniciarEspera();
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = mensagemDeErro(Exception()));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _reenviar() async {
    if (_carregando || _restante > 0) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .pedirCodigoDeRecuperacao(_emailCtrl.text.trim());
      if (mounted) {
        mostrarMensagem(context, 'Enviamos um novo código.');
        _iniciarEspera();
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = mensagemDeErro(Exception()));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _trocarSenha() async {
    if (_carregando) return;
    if (!_codigoForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref.read(authRepositoryProvider).trocarSenhaComCodigo(
            email: _emailCtrl.text.trim(),
            codigo: _codigoCtrl.text.trim(),
            novaSenha: _senhaCtrl.text,
          );
      if (!mounted) return;
      mostrarMensagem(context, 'Senha alterada! Entre com a nova senha.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Rotas.academias);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = mensagemDeErro(Exception()));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  InputDecoration _decoracao(String rotulo, IconData icone, {Widget? sufixo}) {
    return InputDecoration(
      labelText: rotulo,
      prefixIcon: Icon(icone),
      suffixIcon: sufixo,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _caixaErro(ThemeData tema) => Container(
        margin: const EdgeInsets.only(top: 16),
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
      );

  Widget _botao(String texto, VoidCallback acao) => FilledButton(
        onPressed: _carregando ? null : acao,
        child: _carregando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Text(texto),
      );

  List<Widget> _passoEmail(ThemeData tema) => [
        Text(
          'Informe o e-mail da sua conta. Vamos enviar um código para você '
          'criar uma nova senha.',
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Form(
          key: _emailForm,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enabled: !_carregando,
            style: const TextStyle(fontSize: 17),
            onFieldSubmitted: (_) => _enviarCodigo(),
            decoration: _decoracao('E-mail', Icons.mail_outline),
            validator: Validators.email,
          ),
        ),
        if (_erro != null) _caixaErro(tema),
        const SizedBox(height: 24),
        _botao('Enviar código', _enviarCodigo),
      ];

  List<Widget> _passoCodigo(ThemeData tema) => [
        Text(
          'Se o e-mail ${_emailCtrl.text.trim()} estiver cadastrado, o código '
          'chegou na caixa de entrada (olhe também o spam). Digite-o abaixo e '
          'escolha a nova senha.',
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Form(
          key: _codigoForm,
          child: Column(
            children: [
              TextFormField(
                controller: _codigoCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                enabled: !_carregando,
                style: const TextStyle(fontSize: 17, letterSpacing: 4),
                decoration: _decoracao('Código do e-mail', Icons.pin_outlined),
                validator: Validators.codigoDoEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaCtrl,
                obscureText: _ocultarSenha,
                textInputAction: TextInputAction.next,
                enabled: !_carregando,
                style: const TextStyle(fontSize: 17),
                decoration: _decoracao(
                  'Nova senha',
                  Icons.lock_outline,
                  sufixo: IconButton(
                    tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(_ocultarSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _ocultarSenha = !_ocultarSenha),
                  ),
                ),
                validator: Validators.senhaNova,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senha2Ctrl,
                obscureText: _ocultarSenha,
                textInputAction: TextInputAction.done,
                enabled: !_carregando,
                style: const TextStyle(fontSize: 17),
                onFieldSubmitted: (_) => _trocarSenha(),
                decoration:
                    _decoracao('Repita a nova senha', Icons.lock_outline),
                validator: (v) =>
                    v != _senhaCtrl.text ? 'As senhas não são iguais.' : null,
              ),
            ],
          ),
        ),
        if (_erro != null) _caixaErro(tema),
        const SizedBox(height: 24),
        _botao('Trocar senha', _trocarSenha),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_carregando || _restante > 0) ? null : _reenviar,
          child: Text(_restante > 0
              ? 'Reenviar código em $_restante s'
              : 'Reenviar código'),
        ),
        TextButton(
          onPressed: _carregando
              ? null
              : () => setState(() {
                    _codigoEnviado = false;
                    _erro = null;
                    _codigoCtrl.clear();
                    _senhaCtrl.clear();
                    _senha2Ctrl.clear();
                  }),
          child: const Text('Usar outro e-mail'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _codigoEnviado ? _passoCodigo(tema) : _passoEmail(tema),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
