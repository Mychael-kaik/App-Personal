import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/registro_treino.dart';

/// Lê o histórico de exercícios concluídos.
///
/// Segurança: quem decide o que cada pessoa pode ler é o banco (RLS).
/// O aluno só recebe as próprias marcações; o admin recebe as de qualquer
/// aluno. Mesmo que o app pedisse o histórico de outra pessoa, o aluno
/// receberia uma lista vazia.
class ProgressRepository {
  ProgressRepository(this._client);

  final SupabaseClient _client;

  /// Tudo que [alunoId] concluiu no mês [mes] (1 a 12) de [ano].
  Future<List<RegistroTreino>> doMes(String alunoId, int ano, int mes) async {
    final inicio = DateTime(ano, mes, 1);
    final proximo = DateTime(ano, mes + 1, 1); // dezembro + 1 vira janeiro
    final dados = await _client
        .from('completions')
        .select(
          'data, workout_items(series, repeticoes, carga, '
          'exercises(nome, grupo_muscular), workouts(titulo))',
        )
        .eq('aluno_id', alunoId)
        .eq('concluido', true)
        .gte('data', dataParaBanco(inicio))
        .lt('data', dataParaBanco(proximo))
        .order('data', ascending: true);
    return dados.map<RegistroTreino>(RegistroTreino.fromMap).toList();
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(Supabase.instance.client);
});

/// Chave do pedido: de quem e de qual mês.
class MesDoAluno {
  const MesDoAluno(this.alunoId, this.ano, this.mes);

  final String alunoId;
  final int ano;
  final int mes;

  @override
  bool operator ==(Object other) =>
      other is MesDoAluno &&
      other.alunoId == alunoId &&
      other.ano == ano &&
      other.mes == mes;

  @override
  int get hashCode => Object.hash(alunoId, ano, mes);
}

final progressoDoMesProvider = FutureProvider.autoDispose
    .family<List<RegistroTreino>, MesDoAluno>((ref, chave) {
  // Se outra pessoa entrar no mesmo aparelho, busca tudo de novo.
  ref.watch(currentProfileProvider);
  return ref
      .watch(progressRepositoryProvider)
      .doMes(chave.alunoId, chave.ano, chave.mes);
});
