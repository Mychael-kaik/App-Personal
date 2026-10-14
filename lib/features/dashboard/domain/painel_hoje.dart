import '../../auth/domain/profile.dart';

/// Em que pé está o aluno HOJE.
enum SituacaoHoje {
  emAndamento, // fez alguns exercícios, mas não todos
  concluiu, // fez todos
  naoComecou, // tem treino hoje, mas ainda não fez nada
  semTreino, // hoje é dia de descanso
}

/// A situação de um aluno no dia de hoje.
class AlunoHoje {
  const AlunoHoje({
    required this.aluno,
    this.tituloTreino,
    required this.total,
    required this.feitos,
  });

  final Profile aluno;

  /// null quando o aluno não tem treino hoje.
  final String? tituloTreino;

  /// Quantos exercícios o treino de hoje tem e quantos o aluno já concluiu.
  final int total;
  final int feitos;

  bool get temTreino => total > 0;

  SituacaoHoje get situacao {
    if (!temTreino) return SituacaoHoje.semTreino;
    if (feitos >= total) return SituacaoHoje.concluiu;
    if (feitos > 0) return SituacaoHoje.emAndamento;
    return SituacaoHoje.naoComecou;
  }

  double get progresso => temTreino ? (feitos / total).clamp(0.0, 1.0) : 0;
}

/// Todos os alunos ativos e a situação de cada um hoje.
class PainelDeHoje {
  const PainelDeHoje({required this.data, required this.alunos});

  final DateTime data;
  final List<AlunoHoje> alunos;

  int get comTreino => alunos.where((a) => a.temTreino).length;
  int get treinaram => alunos.where((a) => a.feitos > 0).length;
  int get concluiram =>
      alunos.where((a) => a.situacao == SituacaoHoje.concluiu).length;
}
