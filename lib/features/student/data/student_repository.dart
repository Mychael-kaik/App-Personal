import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_exception.dart';
import '../../../core/formatters.dart';
import '../../admin/domain/workout.dart';

/// Tudo que o ALUNO faz no banco passa por aqui: ler os próprios treinos
/// e marcar exercícios como concluídos.
///
/// Segurança: quem garante que o aluno só vê e altera o que é DELE é o banco
/// (RLS, Etapa 1). Mesmo que este código pedisse treinos de outra pessoa,
/// o banco devolveria uma lista vazia.
class StudentRepository {
  StudentRepository(this._client);

  final SupabaseClient _client;

  /// Id do aluno logado.
  String get _meuId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }
    return id;
  }

  /// Todos os treinos do aluno (os 7 dias), com os exercícios.
  Future<List<Workout>> meusTreinos() async {
    final dados = await _client
        .from('workouts')
        .select(
          'id, aluno_id, dia_da_semana, titulo, '
          'workout_items(id, workout_id, exercise_id, series, repeticoes, '
          'tempo_segundos, descanso_serie_segundos, descanso_segundos, '
          'carga, observacao, ordem, '
          'exercises(nome, grupo_muscular, descricao, foto_path))',
        )
        .eq('aluno_id', _meuId)
        .order('dia_da_semana', ascending: true);
    return dados.map<Workout>(Workout.fromMap).toList();
  }

  /// Ids dos itens que o aluno JÁ concluiu no dia [dia].
  Future<Set<String>> concluidosEm(DateTime dia) async {
    final dados = await _client
        .from('completions')
        .select('workout_item_id')
        .eq('aluno_id', _meuId)
        .eq('data', dataParaBanco(dia))
        .eq('concluido', true);
    return dados.map((linha) => linha['workout_item_id'] as String).toSet();
  }

  /// Marca ou desmarca um item no dia [dia].
  ///
  /// "upsert" = "insira; se já existir, atualize". A tabela `completions` tem
  /// uma regra de unicidade (item + aluno + data), então tocar várias vezes
  /// no mesmo exercício nunca cria linhas repetidas: sempre atualiza a mesma.
  Future<void> marcar({
    required String itemId,
    required DateTime dia,
    required bool concluido,
  }) async {
    await _client.from('completions').upsert(
      {
        'workout_item_id': itemId,
        'aluno_id': _meuId,
        'data': dataParaBanco(dia),
        'concluido': concluido,
      },
      onConflict: 'workout_item_id,aluno_id,data',
    );
  }
}
