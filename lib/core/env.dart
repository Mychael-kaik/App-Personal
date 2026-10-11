/// Configuração do Supabase.
///
/// A URL e a chave PÚBLICA (publishable, ou anon na versão antiga) podem
/// ficar no código: quem protege os dados é o RLS do banco.
///
/// NUNCA coloque aqui a chave "secret" / "service_role".
class Env {
  const Env._();

  /// URL do seu projeto (Project Settings → API / botão Connect).
  static const String supabaseUrl = 'https://skqizpreowsdxoqoahbf.supabase.co';

  /// Chave pública. Cole a sua "Publishable key" (começa com sb_publishable_).
  static const String supabaseKey = 'sb_publishable_DhfdTdFocNY6lNHVUmH1bQ_Vuaq6svx';

  /// Confere se a configuração foi preenchida de forma plausível.
  static bool get configurado {
    final urlOk = supabaseUrl.startsWith('https://');
    final chaveOk =
        supabaseKey.startsWith('sb_publishable_') || supabaseKey.startsWith('eyJ');
    return urlOk && chaveOk;
  }
}
