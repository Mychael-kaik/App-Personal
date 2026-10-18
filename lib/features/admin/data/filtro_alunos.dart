import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatusAluno { todos, ativos, inativos }

/// Filtros da aba "Alunos". Ficam num provider para o Painel poder abrir a
/// lista já filtrada (ex.: tocar em uma academia mostra só os alunos dela).
class FiltroAlunos {
  const FiltroAlunos({
    this.busca = '',
    this.academiaId,
    this.professorId,
    this.status = StatusAluno.todos,
  });

  final String busca;

  /// null = todas as academias.
  final String? academiaId;

  /// null = todos; '' = alunos sem professor; outro valor = id do professor.
  final String? professorId;
  final StatusAluno status;

  bool get temFiltro =>
      busca.isNotEmpty ||
      academiaId != null ||
      professorId != null ||
      status != StatusAluno.todos;
}

class FiltroAlunosNotifier extends Notifier<FiltroAlunos> {
  @override
  FiltroAlunos build() => const FiltroAlunos();

  void definirBusca(String v) => state = FiltroAlunos(
        busca: v,
        academiaId: state.academiaId,
        professorId: state.professorId,
        status: state.status,
      );

  /// Trocar de academia zera o professor (ele pode ser de outra academia).
  void definirAcademia(String? id) => state = FiltroAlunos(
        busca: state.busca,
        academiaId: id,
        status: state.status,
      );

  void definirProfessor(String? id) => state = FiltroAlunos(
        busca: state.busca,
        academiaId: state.academiaId,
        professorId: id,
        status: state.status,
      );

  void definirStatus(StatusAluno s) => state = FiltroAlunos(
        busca: state.busca,
        academiaId: state.academiaId,
        professorId: state.professorId,
        status: s,
      );

  /// Atalho usado pelo Painel: começa uma lista nova só com estes filtros.
  void abrir({String? academiaId, String? professorId}) => state =
      FiltroAlunos(academiaId: academiaId, professorId: professorId);

  void limpar() => state = const FiltroAlunos();
}

final filtroAlunosProvider =
    NotifierProvider<FiltroAlunosNotifier, FiltroAlunos>(
        FiltroAlunosNotifier.new);
