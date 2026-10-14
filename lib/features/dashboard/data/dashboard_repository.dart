import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../auth/domain/profile.dart';
import '../domain/painel_hoje.dart';

/// Monta o painel "Hoje" do professor com 3 consultas:
///   1) os alunos ativos;
///   2) os treinos de hoje (dia da semana) e os ids dos exercícios deles;
///   3) o que foi concluído hoje.
/// Depois cruza tudo aqui no app.
///
/// Segurança: só o admin enxerga os dados de todos os alunos (RLS). Se um
/// aluno chamasse isto, o banco devolveria só as linhas dele.
class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<PainelDeHoje> painelDeHoje() async {
    final hoje = DateTime.now();
    final diaDaSemana = hoje.weekday % 7; // 0 = domingo ... 6 = sábado

    final resultados = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('profiles')
          .select()
          .eq('perfil', 'aluno')
          .eq('ativo', true)
          .order('nome', ascending: true),
      _client
          .from('workouts')
          .select('id, aluno_id, titulo, workout_items(id)')
          .eq('dia_da_semana', diaDaSemana),
      _client
          .from('completions')
          .select('aluno_id, workout_item_id')
          .eq('data', dataParaBanco(hoje))
          .eq('concluido', true),
    ]);

    final alunos = resultados[0].map<Profile>(Profile.fromMap).toList();

    // aluno -> (título, ids dos exercícios de hoje)
    final treinos = <String, ({String titulo, Set<String> itens})>{};
    for (final w in resultados[1]) {
      final itens = ((w['workout_items'] as List<dynamic>?) ?? const [])
          .map((i) => (i as Map<String, dynamic>)['id'] as String)
          .toSet();
      treinos[w['aluno_id'] as String] =
          (titulo: w['titulo'] as String, itens: itens);
    }

    // aluno -> ids dos itens que ele concluiu hoje
    final feitos = <String, Set<String>>{};
    for (final c in resultados[2]) {
      feitos
          .putIfAbsent(c['aluno_id'] as String, () => {})
          .add(c['workout_item_id'] as String);
    }

    final lista = alunos.map((a) {
      final treino = treinos[a.id];
      if (treino == null) {
        return AlunoHoje(aluno: a, total: 0, feitos: 0);
      }
      // Só conta o que pertence ao treino de hoje.
      final feitosHoje = (feitos[a.id] ?? const <String>{})
          .where(treino.itens.contains)
          .length;
      return AlunoHoje(
        aluno: a,
        tituloTreino: treino.titulo,
        total: treino.itens.length,
        feitos: feitosHoje,
      );
    }).toList();

    return PainelDeHoje(data: hoje, alunos: lista);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(Supabase.instance.client);
});

final painelDeHojeProvider = FutureProvider.autoDispose<PainelDeHoje>((ref) {
  return ref.watch(dashboardRepositoryProvider).painelDeHoje();
});
