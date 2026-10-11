import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/profile.dart';

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
  Future<void> entrar(String email, String senha) async {
    final perfil = await _repo.entrar(email: email, senha: senha);
    state = AsyncData(perfil);
  }

  Future<void> sair() async {
    await _repo.sairSemErro();
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
