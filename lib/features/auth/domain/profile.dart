/// Tipo de usuário do app.
enum Perfil {
  admin,
  aluno;

  static Perfil deTexto(String valor) =>
      valor == 'admin' ? Perfil.admin : Perfil.aluno;
}

/// Uma linha da tabela `profiles` do banco.
class Profile {
  const Profile({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    required this.ativo,
    this.observacoes,
  });

  final String id;
  final String nome;
  final String? email;
  final Perfil perfil;
  final bool ativo;
  final String? observacoes;

  bool get isAdmin => perfil == Perfil.admin;

  /// Converte o Map que o Supabase devolve em um objeto Profile.
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      nome: map['nome'] as String,
      email: map['email'] as String?,
      perfil: Perfil.deTexto(map['perfil'] as String),
      ativo: map['ativo'] as bool,
      observacoes: map['observacoes'] as String?,
    );
  }
}
