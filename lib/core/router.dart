import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_home_page.dart';
import '../features/admin/presentation/student_detail_page.dart';
import '../features/admin/presentation/student_form_page.dart';
import '../features/admin/presentation/workout_editor_page.dart';
import '../features/auth/domain/profile.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/entrada_state.dart';
import '../features/auth/presentation/escolha_academia_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/student/presentation/exercise_detail_page.dart';
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
  bool temEscolha = false,
}) {
  // Ainda descobrindo se existe login salvo.
  if (carregando) {
    return local == Rotas.splash ? null : Rotas.splash;
  }

  // Ninguém logado: primeiro a escolha da academia; o login só abre depois
  // de escolher uma academia (ou "Sou administrador").
  if (perfil == null) {
    if (local == Rotas.academias) return null;
    if (local == Rotas.login) return temEscolha ? null : Rotas.academias;
    return Rotas.academias;
  }

  // Logado como EQUIPE (administrador geral ou professor): só as telas /admin.
  // O que cada um enxerga lá dentro é decidido pelo banco (RLS).
  if (perfil.isEquipe) {
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
  ref.listen(splashProntoProvider, (anterior, atual) => aviso.value++);
  ref.listen(entradaProvider, (anterior, atual) => aviso.value++);

  final router = GoRouter(
    initialLocation: Rotas.splash,
    refreshListenable: aviso,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final splashPronto = ref.read(splashProntoProvider).hasValue;
      return decidirRedirecionamento(
        // Mostra a logo do app por um instante ao abrir.
        carregando: (auth.isLoading && !auth.hasValue) || !splashPronto,
        temEscolha: ref.read(entradaProvider).temEscolha,
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
        path: Rotas.academias,
        builder: (context, state) => const EscolhaAcademiaPage(),
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
            builder: (context, state) => StudentFormPage(
              // Atalho: o painel pode abrir o formulário já com um professor escolhido.
              professorIdInicial: state.uri.queryParameters['professor'],
            ),
          ),
          // Só o administrador geral: a própria tela confere (e o banco/servidor também).
          GoRoute(
            path: 'professor/novo',
            builder: (context, state) =>
                const StudentFormPage(tipo: Perfil.professor),
          ),
          GoRoute(
            path: 'aluno/:id',
            builder: (context, state) =>
                StudentDetailPage(alunoId: state.pathParameters['id']!),
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
        routes: [
          GoRoute(
            path: 'progresso',
            builder: (context, state) => const ProgressPage(),
          ),
          GoRoute(
            path: 'exercicio/:itemId',
            builder: (context, state) =>
                ExerciseDetailPage(itemId: state.pathParameters['itemId']!),
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
