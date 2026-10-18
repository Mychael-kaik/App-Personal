import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_exception.dart';
import '../../../core/rotas.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/logo_academia.dart';
import 'auth_controller.dart';
import 'entrada_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();

  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    // 1) Valida os campos (mostra os erros embaixo de cada campo)
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // 2) Pede o login. Se der certo, o roteador leva para a tela certa.
      await ref
          .read(authControllerProvider.notifier)
          .entrar(_emailCtrl.text.trim(), _senhaCtrl.text);
      TextInput.finishAutofillContext();
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'Não foi possível entrar. Verifique sua conexão e tente de novo.');
      }
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  /// Volta para a lista de academias.
  void _trocarAcademia() {
    ref.read(entradaProvider.notifier).limpar();
    context.go(Rotas.academias);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escolha = ref.watch(entradaProvider);
    final academia = escolha.academia;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Em celular ocupa a largura toda; em tela grande (web) fica
              // com no máximo 420 de largura, centralizado.
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: academia != null
                            ? LogoAcademia(
                                nome: academia.nome,
                                logoPath: academia.logoPath,
                                tamanho: 96,
                              )
                            : Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: tema.colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 42,
                                  color: tema.colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        academia?.nome ?? 'Administrador geral',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entre com seu e-mail e senha.',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enabled: !_carregando,
                        style: const TextStyle(fontSize: 17),
                        decoration: _decoracao('E-mail', Icons.mail_outline),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaCtrl,
                        obscureText: _ocultarSenha,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_carregando,
                        style: const TextStyle(fontSize: 17),
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: _decoracao(
                          'Senha',
                          Icons.lock_outline,
                          sufixo: IconButton(
                            tooltip: _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(_ocultarSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                        ),
                        validator: (v) =>
                            Validators.obrigatorio(v, campo: 'A senha'),
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
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _carregando ? null : _entrar,
                        child: _carregando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _carregando ? null : _trocarAcademia,
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(academia != null
                            ? 'Trocar de academia'
                            : 'Voltar para a escolha da academia'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ainda não tem acesso? Peça ao seu personal para cadastrar você.',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
