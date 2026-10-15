import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_home_page.dart';
import '../features/admin/presentation/student_detail_page.dart';
import '../features/admin/presentation/student_form_page.dart';
import '../features/admin/presentation/workout_editor_page.dart';
import '../features/auth/domain/profile.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/student/presentation/exercise_detail_page.dart';
import '../features/student/presentation/student_home_page.dart';
import 'rotas.dart';
import '../features/professor/presentation/professor_home_page.dart';

/// Decide para qual área cada perfil pode acessar.
String? decidirRedirecionamento({
  required bool carregando,
  required Profile? perfil,
  required String local,
}) {
  if (carregando) {
    return local == Rotas.splash ? null : Rotas.splash;
  }

  if (perfil == null) {
    return local == Rotas.login ? null : Rotas.login;
  }

  switch (perfil.perfil) {
    case Perfil.admin:
      final lugarCerto = local.startsWith('${Rotas.admin}/') ||
          local == Rotas.admin;
      return lugarCerto ? null : Rotas.admin;

    case Perfil.professor:
      final lugarCerto = local.startsWith('${Rotas.professor}/') ||
          local == Rotas.professor;
      return lugarCerto ? null : Rotas.professor;

    case Perfil.aluno:
      final lugarCerto = local.startsWith('${Rotas.aluno}/') ||
          local == Rotas.aluno;
      return lugarCerto ? null : Rotas.aluno;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final aviso = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (anterior, atual) {
    aviso.value++;
  });

  final router = GoRouter(
    initialLocation: Rotas.splash,
    refreshListenable: aviso,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);

      return decidirRedirecionamento(
        carregando: auth.isLoading && !auth.hasValue,
        perfil: auth.hasValue ? auth.value : null,
        local: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: Rotas.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Rotas.login,
        builder: (context, state) => const LoginPage(),
      ),

      // Área provisória do professor.
      GoRoute(
        path: Rotas.professor,
        builder: (context, state) => const ProfessorHomePage(),
      ),

      // Área do administrador.
      GoRoute(
        path: Rotas.admin,
        builder: (context, state) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'aluno/novo',
            builder: (context, state) => const StudentFormPage(),
          ),
          GoRoute(
            path: 'aluno/:id',
            builder: (context, state) => StudentDetailPage(
              alunoId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'progresso',
                builder: (context, state) => ProgressPage(
                  alunoId: state.pathParameters['id']!,
                  titulo: state.uri.queryParameters['nome'] == null
                      ? 'Progresso do aluno'
                      : 'Progresso de ${state.uri.queryParameters['nome']}',
                ),
              ),
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    StudentFormPage(alunoId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'treino/:dia',
                builder: (context, state) {
                  final dia =
                      int.tryParse(state.pathParameters['dia'] ?? '');

                  return WorkoutEditorPage(
                    alunoId: state.pathParameters['id']!,
                    dia: (dia != null && dia >= 0 && dia <= 6) ? dia : 1,
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // Área do aluno.
      GoRoute(
        path: Rotas.aluno,
        builder: (context, state) => const StudentHomePage(),
        routes: [
          GoRoute(
            path: 'progresso',
            builder: (context, state) => const ProgressPage(),
          ),
          GoRoute(
            path: 'exercicio/:itemId',
            builder: (context, state) => ExerciseDetailPage(
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    aviso.dispose();
  });

  return router;
});
