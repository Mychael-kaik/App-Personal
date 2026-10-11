import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/domain/workout.dart';
import '../../auth/presentation/auth_controller.dart';
import 'student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(Supabase.instance.client);
});

/// Os treinos do aluno logado (todos os dias da semana).
///
/// `ref.watch(currentProfileProvider)` faz o dado ser buscado de novo se
/// outra pessoa entrar no mesmo aparelho (assim nunca sobra dado do usuário
/// anterior na memória).
final meusTreinosProvider = FutureProvider.autoDispose<List<Workout>>((ref) {
  ref.watch(currentProfileProvider);
  return ref.watch(studentRepositoryProvider).meusTreinos();
});

/// Quais exercícios o aluno já concluiu HOJE (conjunto de ids de itens).
///
/// É um Notifier (e não um FutureProvider simples) porque além de LER ele
/// também MUDA: ao tocar num exercício, a tela atualiza na hora e o banco é
/// atualizado em seguida. Se o banco falhar, voltamos ao estado anterior.
class ConclusoesController extends AsyncNotifier<Set<String>> {
  // O dia em que as marcações foram carregadas. Todas as marcações desta
  // sessão usam este mesmo dia.
  late DateTime _hoje;

  @override
  Future<Set<String>> build() {
    ref.watch(currentProfileProvider);
    _hoje = DateTime.now();
    return ref.watch(studentRepositoryProvider).concluidosEm(_hoje);
  }

  /// Marca (true) ou desmarca (false) um item. Em caso de erro, desfaz a
  /// mudança na tela e repassa o erro para a tela avisar o aluno.
  Future<void> alternar(String itemId, bool concluido) async {
    _aplicar(itemId, concluido); // 1) atualiza a tela imediatamente
    try {
      await ref.read(studentRepositoryProvider).marcar(
            itemId: itemId,
            dia: _hoje,
            concluido: concluido,
          ); // 2) grava no banco
    } catch (_) {
      _aplicar(itemId, !concluido); // 3) deu erro: volta como estava
      rethrow;
    }
  }

  void _aplicar(String itemId, bool concluido) {
    final novo = {...(state.value ?? <String>{})};
    if (concluido) {
      novo.add(itemId);
    } else {
      novo.remove(itemId);
    }
    state = AsyncData(novo);
  }
}

final conclusoesDeHojeProvider =
    AsyncNotifierProvider<ConclusoesController, Set<String>>(
  ConclusoesController.new,
);
