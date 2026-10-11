import 'package:flutter/foundation.dart';
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
import '../features/student/presentation/student_home_page.dart';
import 'rotas.dart';

/// Regra de proteção das rotas. Devolve:
///  - null  → pode ficar onde está;
///  - texto → manda o usuário para essa rota.
///
/// Está separada numa função simples para ficar fácil de entender e testar.
String? decidirRedirecionamento({
  required bool carregando,
  required Profile? perfil,
  required String local,
}) {
  // Ainda descobrindo se existe login salvo.
  if (carregando) {
    return local == Rotas.splash ? null : Rotas.splash;
  }

  // Ninguém logado: só a tela de login é permitida.
  if (perfil == null) {
    return local == Rotas.login ? null : Rotas.login;
  }

  // Logado como ADMIN: só as telas /admin.
  if (perfil.isAdmin) {
    final lugarCerto = local.startsWith(Rotas.admin);
    return lugarCerto ? null : Rotas.admin;
  }

  // Logado como ALUNO: só as telas /aluno.
  final lugarCerto = local.startsWith(Rotas.aluno);
  return lugarCerto ? null : Rotas.aluno;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Sempre que o estado de login mudar, avisamos o GoRouter para reavaliar
  // o redirecionamento.
  final aviso = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (anterior, atual) => aviso.value++);

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
      GoRoute(
        path: Rotas.admin,
        builder: (context, state) => const AdminHomePage(),
        // Rotas "filhas": abrem EMPILHADAS sobre o painel (o botão voltar
        // funciona). Aqui o caminho não começa com "/".
        routes: [
          // "aluno/novo" precisa vir ANTES de "aluno/:id",
          // senão "novo" seria entendido como o id de um aluno.
          GoRoute(
            path: 'aluno/novo',
            builder: (context, state) => const StudentFormPage(),
          ),
          GoRoute(
            path: 'aluno/:id',
            builder: (context, state) =>
                StudentDetailPage(alunoId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    StudentFormPage(alunoId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'treino/:dia',
                builder: (context, state) {
                  final dia = int.tryParse(state.pathParameters['dia'] ?? '');
                  return WorkoutEditorPage(
                    alunoId: state.pathParameters['id']!,
                    // Se alguém digitar um dia inválido na barra de endereço,
                    // usamos segunda-feira em vez de quebrar.
                    dia: (dia != null && dia >= 0 && dia <= 6) ? dia : 1,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rotas.aluno,
        builder: (context, state) => const StudentHomePage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    aviso.dispose();
  });

  return router;
});
