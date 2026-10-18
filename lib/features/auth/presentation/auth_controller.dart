import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_exception.dart';
import '../data/auth_repository.dart';
import '../domain/profile.dart';
import '../domain/regra_de_entrada.dart';
import 'entrada_state.dart';

/// Guarda "quem está logado" (um [Profile], ou null se ninguém).
///
/// O estado é um AsyncValue:
///  - carregando: só acontece ao abrir o app (restaurando a sessão);
///  - dado com Profile: usuário logado;
///  - dado com null: ninguém logado.
class AuthController extends AsyncNotifier<Profile?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<Profile?> build() async {
    // Se o Supabase deslogar o usuário sozinho (ex.: sessão expirou),
    // o app volta para o login.
    final inscricao = _repo.mudancasDeAutenticacao.listen((dados) {
      if (dados.event == AuthChangeEvent.signedOut) {
        state = const AsyncData(null);
      }
    });
    ref.onDispose(inscricao.cancel);

    final usuario = _repo.usuarioAtual;
    if (usuario == null) return null;

    try {
      return await _repo.carregarPerfilValido(usuario.id);
    } catch (_) {
      await _repo.sairSemErro();
      return null;
    }
  }

  /// Faz login. Em caso de erro lança AppException (a tela mostra a mensagem).
  /// Em caso de sucesso, atualiza o estado e o roteador redireciona sozinho.
  ///
  /// Além de e-mail e senha, confere se a pessoa pertence à "porta" escolhida
  /// na tela inicial (uma academia ou o administrador geral). Se não pertencer,
  /// a sessão é encerrada na hora e o erro é mostrado.
  Future<void> entrar(String email, String senha) async {
    final escolha = ref.read(entradaProvider);
    final perfil = await _repo.entrar(email: email, senha: senha);

    final erro = verificarEntrada(
      perfil: perfil,
      academiaId: escolha.academia?.id,
      modoAdmin: escolha.modoAdmin,
    );
    if (erro != null) {
      await _repo.sairSemErro();
      throw AppException(erro);
    }
    state = AsyncData(perfil);
  }

  Future<void> sair() async {
    await _repo.sairSemErro();
    // Volta para a tela de escolha da academia.
    ref.read(entradaProvider.notifier).limpar();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Profile?>(AuthController.new);

/// Atalho: o perfil de quem está logado (ou null).
final currentProfileProvider = Provider<Profile?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.hasValue ? auth.value : null;
});
