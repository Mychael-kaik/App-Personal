import 'profile.dart';

/// Confere se quem acabou de fazer login pode entrar pela porta que escolheu.
///
/// Devolve null (pode entrar) ou a mensagem de erro para mostrar.
/// Função simples e sem Supabase, para ficar fácil de entender e testar.
///
/// Importante: isto é a "porta" da tela. A segurança de verdade (quem lê o quê)
/// continua no banco (RLS): mesmo sem esta conferência, ninguém enxerga dados
/// de outra academia.
String? verificarEntrada({
  required Profile perfil,
  required String? academiaId,
  required bool modoAdmin,
}) {
  // Porta do administrador geral.
  if (modoAdmin) {
    return perfil.isAdmin
        ? null
        : 'Esta entrada é só para o administrador geral. '
            'Volte e escolha a sua academia.';
  }

  // Porta de uma academia.
  if (academiaId == null) {
    return 'Escolha a sua academia antes de entrar.';
  }
  if (perfil.isAdmin) {
    return 'Administrador geral: volte e toque em "Sou administrador".';
  }
  if (perfil.academiaId == academiaId) return null;

  return perfil.isProfessor
      ? 'Você não é um professor cadastrado nesta academia.'
      : 'Você não é um aluno cadastrado nesta academia.';
}
