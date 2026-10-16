import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/profile.dart';
import '../domain/academia.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';
import 'admin_repository.dart';

/// Providers = "fábricas" de dados que o Riverpod entrega para as telas.
///
/// FutureProvider: busca algo de forma assíncrona e a tela recebe
/// "carregando", "erro" ou "dados" automaticamente.
/// autoDispose: libera a memória quando nenhuma tela está usando.
/// family: um provider para cada parâmetro (ex.: um por aluno).
///
/// Depois de gravar algo, chamamos ref.invalidate(...) e o Riverpod busca
/// de novo, atualizando as telas sozinho.

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(Supabase.instance.client);
});

/// Lista de alunos (sem o admin).
final alunosProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(adminRepositoryProvider).listarAlunos();
});

/// Um aluno pelo id.
final alunoProvider =
    FutureProvider.autoDispose.family<Profile, String>((ref, alunoId) {
  return ref.watch(adminRepositoryProvider).buscarAluno(alunoId);
});

/// Biblioteca de exercícios.
final exerciciosProvider = FutureProvider.autoDispose<List<Exercise>>((ref) {
  return ref.watch(adminRepositoryProvider).listarExercicios();
});

/// Treinos de um aluno (todos os dias da semana).
final treinosDoAlunoProvider =
    FutureProvider.autoDispose.family<List<Workout>, String>((ref, alunoId) {
  return ref.watch(adminRepositoryProvider).listarTreinos(alunoId);
});

/// Exercícios que podem entrar no treino de um aluno (biblioteca do professor dele).
final exerciciosDoAlunoProvider =
    FutureProvider.autoDispose.family<List<Exercise>, String>((ref, alunoId) {
  return ref.watch(adminRepositoryProvider).listarExerciciosDoAluno(alunoId);
});

/// Academias (o administrador geral vê todas; o professor, só a dele).
final academiasProvider = FutureProvider.autoDispose<List<Academia>>((ref) {
  return ref.watch(adminRepositoryProvider).listarAcademias();
});

/// Professores (só o administrador geral enxerga todos).
final professoresProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(adminRepositoryProvider).listarProfessores();
});
