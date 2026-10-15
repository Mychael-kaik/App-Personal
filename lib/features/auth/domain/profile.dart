
/// Tipo de usuário do app.
enum Perfil {
  admin,
  professor,
  aluno;

  static Perfil deTexto(String valor) {
    switch (valor) {
      case 'admin':
        return Perfil.admin;
      case 'professor':
        return Perfil.professor;
      case 'aluno':
        return Perfil.aluno;
      default:
        throw FormatException('Perfil de usuário desconhecido: $valor');
    }
  }
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
    this.academiaId,
    this.professorId,
  });

  final String id;
  final String nome;
  final String? email;
  final Perfil perfil;
  final bool ativo;
  final String? observacoes;
  final String? academiaId;
  final String? professorId;

  bool get isAdmin => perfil == Perfil.admin;
  bool get isProfessor => perfil == Perfil.professor;
  bool get isAluno => perfil == Perfil.aluno;

  /// Converte o Map que o Supabase devolve em um objeto Profile.
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      nome: map['nome'] as String,
      email: map['email'] as String?,
      perfil: Perfil.deTexto(map['perfil'] as String),
      ativo: map['ativo'] as bool,
      observacoes: map['observacoes'] as String?,
      academiaId: map['academia_id'] as String?,
      professorId: map['professor_id'] as String?,
    );
  }
}
