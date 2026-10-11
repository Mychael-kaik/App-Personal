import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_exception.dart';
import '../domain/profile.dart';

/// Único lugar que "conversa" com o Supabase para login/perfil.
/// As telas nunca chamam o Supabase direto: elas pedem para este repositório.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Usuário com sessão ativa (o Supabase restaura a sessão salva no aparelho).
  User? get usuarioAtual => _client.auth.currentUser;

  /// Avisa quando o login/logout muda (inclusive logout automático).
  Stream<AuthState> get mudancasDeAutenticacao =>
      _client.auth.onAuthStateChange;

  /// Faz login e devolve o perfil. Lança [AppException] com mensagem amigável.
  Future<Profile> entrar({required String email, required String senha}) async {
    try {
      final resposta = await _client.auth.signInWithPassword(
        email: email,
        password: senha,
      );
      final usuario = resposta.user;
      if (usuario == null) {
        throw const AppException('Não foi possível entrar. Tente novamente.');
      }
      return await carregarPerfilValido(usuario.id);
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(_traduzirErroDeLogin(e));
    } catch (_) {
      // Qualquer outra falha (ex.: sem internet depois do login):
      // não deixamos uma sessão "pela metade".
      await sairSemErro();
      rethrow;
    }
  }

  /// Busca o perfil na tabela `profiles` e confere se a conta está ativa.
  Future<Profile> carregarPerfilValido(String userId) async {
    final dados = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (dados == null) {
      await sairSemErro();
      throw const AppException(
        'Seu perfil não foi encontrado. Fale com o seu personal.',
      );
    }

    final perfil = Profile.fromMap(dados);
    if (!perfil.ativo) {
      await sairSemErro();
      throw const AppException(
        'Sua conta está desativada. Fale com o seu personal.',
      );
    }
    return perfil;
  }

  Future<void> sair() => _client.auth.signOut();

  Future<void> sairSemErro() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignoramos: o objetivo é só garantir que não sobre sessão.
    }
  }

  String _traduzirErroDeLogin(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Seu e-mail ainda não foi confirmado.';
    }
    if (msg.contains('too many') || msg.contains('rate limit')) {
      return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
    }
    return 'Não foi possível entrar. Tente novamente.';
  }
}

/// Provider = "fábrica" que o Riverpod usa para entregar o repositório
/// para qualquer lugar do app.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});
