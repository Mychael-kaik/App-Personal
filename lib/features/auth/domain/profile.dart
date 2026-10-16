/// Tipo de usuário do app.
///  - admin: administrador geral (vê e gerencia tudo);
///  - professor: cuida só dos próprios alunos e da própria biblioteca;
///  - aluno: vê só o próprio treino.
enum Perfil {
  admin,
  professor,
  aluno;

  static Perfil deTexto(String valor) => switch (valor) {
        'admin' => Perfil.admin,
        'professor' => Perfil.professor,
        _ => Perfil.aluno,
      };

  String get rotulo => switch (this) {
        Perfil.admin => 'Administrador geral',
        Perfil.professor => 'Professor',
        Perfil.aluno => 'Aluno',
      };
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

  /// Academia da pessoa (professores e alunos). null = administrador geral
  /// ou aluno antigo que ainda não foi passado para um professor.
  final String? academiaId;

  /// Só para alunos: o professor responsável. null = ainda sem professor.
  final String? professorId;

  /// Administrador geral.
  bool get isAdmin => perfil == Perfil.admin;
  bool get isProfessor => perfil == Perfil.professor;

  /// Equipe = quem usa o painel (administrador geral ou professor).
  bool get isEquipe => isAdmin || isProfessor;

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
