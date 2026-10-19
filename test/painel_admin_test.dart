import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_trainer/features/admin/data/filtro_alunos.dart';
import 'package:personal_trainer/features/dashboard/domain/painel_admin.dart';

void main() {
  group('PainelGeral / modelos do painel', () {
    test('converte a linha do banco', () {
      final g = PainelGeral.fromMap({
        'academias_total': 3,
        'academias_ativas': 2,
        'professores_total': 5,
        'professores_ativos': 4,
        'alunos_total': 40,
        'alunos_ativos': 38,
        'alunos_sem_professor': 2,
        'treinaram_hoje': 9,
        'treinaram_7d': 25,
      });
      expect(g.academiasAtivas, 2);
      expect(g.alunosSemProfessor, 2);
      expect(g.treinaram7d, 25);
    });

    test('valores nulos viram 0 (nunca quebram a tela)', () {
      final g = PainelGeral.fromMap({});
      expect(g.alunosAtivos, 0);
      expect(g.treinaramHoje, 0);
    });

    test('aluno parado: quem nunca treinou', () {
      final a = AlunoParado.fromMap({
        'aluno_id': 'a1',
        'nome': 'Ana',
        'professor_nome': null,
        'academia_nome': null,
        'ultimo_treino': null,
        'dias_parado': 26,
      });
      expect(a.nuncaTreinou, isTrue);
      expect(a.diasParado, 26);
      expect(a.professorNome, isNull);
    });

    test('resumo da academia', () {
      final r = ResumoAcademia.fromMap({
        'academia_id': 'g1',
        'nome': 'Academia 1',
        'ativo': true,
        'logo_path': null,
        'professores_ativos': 2,
        'alunos_ativos': 12,
        'treinaram_hoje': 3,
        'treinaram_7d': 8,
      });
      expect(r.alunosAtivos, 12);
      expect(r.logoPath, isNull);
    });
  });

  group('FiltroAlunos', () {
    ProviderContainer novo() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('começa sem filtro', () {
      final c = novo();
      expect(c.read(filtroAlunosProvider).temFiltro, isFalse);
    });

    test('trocar de academia zera o professor', () {
      final c = novo();
      final n = c.read(filtroAlunosProvider.notifier);
      n.definirProfessor('p1');
      n.definirAcademia('g1');
      final f = c.read(filtroAlunosProvider);
      expect(f.academiaId, 'g1');
      expect(f.professorId, isNull);
    });

    test('abrir (atalho do painel) começa uma lista nova', () {
      final c = novo();
      final n = c.read(filtroAlunosProvider.notifier);
      n.definirBusca('maria');
      n.definirStatus(StatusAluno.inativos);
      n.abrir(professorId: '');
      final f = c.read(filtroAlunosProvider);
      expect(f.busca, '');
      expect(f.status, StatusAluno.todos);
      expect(f.professorId, ''); // '' = sem professor
    });

    test('limpar remove tudo', () {
      final c = novo();
      final n = c.read(filtroAlunosProvider.notifier);
      n.definirBusca('x');
      n.limpar();
      expect(c.read(filtroAlunosProvider).temFiltro, isFalse);
    });
  });
}
