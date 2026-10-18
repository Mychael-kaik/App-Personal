/// Números do painel do administrador geral (vêm das funções SQL
/// `painel_geral`, `painel_por_academia`, `painel_por_professor` e
/// `alunos_parados`).
int _n(Object? v) => (v as num?)?.toInt() ?? 0;

class PainelGeral {
  const PainelGeral({
    required this.academiasTotal,
    required this.academiasAtivas,
    required this.professoresTotal,
    required this.professoresAtivos,
    required this.alunosTotal,
    required this.alunosAtivos,
    required this.alunosSemProfessor,
    required this.treinaramHoje,
    required this.treinaram7d,
  });

  final int academiasTotal;
  final int academiasAtivas;
  final int professoresTotal;
  final int professoresAtivos;
  final int alunosTotal;
  final int alunosAtivos;

  /// Alunos ativos que ainda não foram passados para um professor.
  final int alunosSemProfessor;

  /// Alunos que concluíram pelo menos 1 exercício hoje / nos últimos 7 dias.
  final int treinaramHoje;
  final int treinaram7d;

  factory PainelGeral.fromMap(Map<String, dynamic> m) => PainelGeral(
        academiasTotal: _n(m['academias_total']),
        academiasAtivas: _n(m['academias_ativas']),
        professoresTotal: _n(m['professores_total']),
        professoresAtivos: _n(m['professores_ativos']),
        alunosTotal: _n(m['alunos_total']),
        alunosAtivos: _n(m['alunos_ativos']),
        alunosSemProfessor: _n(m['alunos_sem_professor']),
        treinaramHoje: _n(m['treinaram_hoje']),
        treinaram7d: _n(m['treinaram_7d']),
      );
}

class ResumoAcademia {
  const ResumoAcademia({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.professoresAtivos,
    required this.alunosAtivos,
    required this.treinaramHoje,
    required this.treinaram7d,
    this.logoPath,
  });

  final String id;
  final String nome;
  final bool ativo;
  final String? logoPath;
  final int professoresAtivos;
  final int alunosAtivos;
  final int treinaramHoje;
  final int treinaram7d;

  factory ResumoAcademia.fromMap(Map<String, dynamic> m) => ResumoAcademia(
        id: m['academia_id'] as String,
        nome: m['nome'] as String,
        ativo: m['ativo'] as bool,
        logoPath: m['logo_path'] as String?,
        professoresAtivos: _n(m['professores_ativos']),
        alunosAtivos: _n(m['alunos_ativos']),
        treinaramHoje: _n(m['treinaram_hoje']),
        treinaram7d: _n(m['treinaram_7d']),
      );
}

class ResumoProfessor {
  const ResumoProfessor({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.alunosAtivos,
    required this.treinaramHoje,
    required this.treinaram7d,
    this.academiaId,
    this.academiaNome,
  });

  final String id;
  final String nome;
  final bool ativo;
  final String? academiaId;
  final String? academiaNome;
  final int alunosAtivos;
  final int treinaramHoje;
  final int treinaram7d;

  factory ResumoProfessor.fromMap(Map<String, dynamic> m) => ResumoProfessor(
        id: m['professor_id'] as String,
        nome: m['nome'] as String,
        ativo: m['ativo'] as bool,
        academiaId: m['academia_id'] as String?,
        academiaNome: m['academia_nome'] as String?,
        alunosAtivos: _n(m['alunos_ativos']),
        treinaramHoje: _n(m['treinaram_hoje']),
        treinaram7d: _n(m['treinaram_7d']),
      );
}

class AlunoParado {
  const AlunoParado({
    required this.id,
    required this.nome,
    required this.diasParado,
    this.professorNome,
    this.academiaNome,
    this.ultimoTreino,
  });

  final String id;
  final String nome;
  final String? professorNome;
  final String? academiaNome;

  /// Data do último treino (texto "AAAA-MM-DD"); null = nunca treinou.
  final String? ultimoTreino;
  final int diasParado;

  bool get nuncaTreinou => ultimoTreino == null;

  factory AlunoParado.fromMap(Map<String, dynamic> m) => AlunoParado(
        id: m['aluno_id'] as String,
        nome: m['nome'] as String,
        professorNome: m['professor_nome'] as String?,
        academiaNome: m['academia_nome'] as String?,
        ultimoTreino: m['ultimo_treino'] as String?,
        diasParado: _n(m['dias_parado']),
      );
}
