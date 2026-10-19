/// Traduz os erros do Supabase na recuperação de senha para mensagens claras.
/// [codigo] é o AuthException.code (pode ser null); [mensagem] o texto original.
String traduzirErroDeRecuperacao({String? codigo, String? mensagem}) {
  final c = (codigo ?? '').toLowerCase();
  final m = (mensagem ?? '').toLowerCase();
  bool tem(String t) => c.contains(t) || m.contains(t);

  if (tem('otp_expired') || tem('expired') || tem('invalid') || tem('token')) {
    return 'Código inválido ou vencido. Confira os números ou peça um novo código.';
  }
  if (tem('same_password') || tem('different from the old')) {
    return 'Escolha uma senha diferente da anterior.';
  }
  if (tem('weak_password') || tem('password should be')) {
    return 'Senha fraca demais. Use pelo menos 6 caracteres.';
  }
  if (tem('rate') || tem('too many') || tem('seconds')) {
    return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
  }
  return 'Não foi possível concluir. Verifique sua conexão e tente de novo.';
}
