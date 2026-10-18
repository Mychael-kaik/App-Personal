import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../domain/painel_admin.dart';

/// Lê os números do painel do administrador geral.
///
/// Os cálculos são feitos no banco (funções SQL), que só aceitam o
/// administrador geral. "Hoje" é a data do aparelho, igual às marcações
/// dos alunos.
class PainelAdminRepository {
  PainelAdminRepository(this._client);

  final SupabaseClient _client;

  String get _hoje => dataParaBanco(DateTime.now());

  List<Map<String, dynamic>> _linhas(Object? dados) =>
      (dados as List).cast<Map<String, dynamic>>();

  Future<PainelGeral> geral() async {
    final dados = await _client.rpc('painel_geral', params: {'p_hoje': _hoje});
    return PainelGeral.fromMap(_linhas(dados).first);
  }

  Future<List<ResumoAcademia>> porAcademia() async {
    final dados =
        await _client.rpc('painel_por_academia', params: {'p_hoje': _hoje});
    return _linhas(dados).map(ResumoAcademia.fromMap).toList();
  }

  Future<List<ResumoProfessor>> porProfessor() async {
    final dados =
        await _client.rpc('painel_por_professor', params: {'p_hoje': _hoje});
    return _linhas(dados).map(ResumoProfessor.fromMap).toList();
  }

  Future<List<AlunoParado>> alunosParados(int dias) async {
    final dados = await _client
        .rpc('alunos_parados', params: {'p_hoje': _hoje, 'p_dias': dias});
    return _linhas(dados).map(AlunoParado.fromMap).toList();
  }
}

final painelAdminRepositoryProvider = Provider<PainelAdminRepository>((ref) {
  return PainelAdminRepository(Supabase.instance.client);
});

final painelGeralProvider = FutureProvider.autoDispose<PainelGeral>((ref) {
  return ref.watch(painelAdminRepositoryProvider).geral();
});

final painelAcademiasProvider =
    FutureProvider.autoDispose<List<ResumoAcademia>>((ref) {
  return ref.watch(painelAdminRepositoryProvider).porAcademia();
});

final painelProfessoresProvider =
    FutureProvider.autoDispose<List<ResumoProfessor>>((ref) {
  return ref.watch(painelAdminRepositoryProvider).porProfessor();
});

/// Alunos parados há [dias] dias ou mais (um provider para cada valor de dias).
final alunosParadosProvider =
    FutureProvider.autoDispose.family<List<AlunoParado>, int>((ref, dias) {
  return ref.watch(painelAdminRepositoryProvider).alunosParados(dias);
});

/// Atualiza o painel inteiro.
void atualizarPainelAdmin(WidgetRef ref) {
  ref.invalidate(painelGeralProvider);
  ref.invalidate(painelAcademiasProvider);
  ref.invalidate(painelProfessoresProvider);
  ref.invalidate(alunosParadosProvider);
}
