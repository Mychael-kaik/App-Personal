import 'package:flutter_test/flutter_test.dart';
import 'package:personal_trainer/core/rotas.dart';
import 'package:personal_trainer/core/router.dart';
import 'package:personal_trainer/features/admin/domain/exercise.dart';
import 'package:personal_trainer/features/auth/domain/profile.dart';

void main() {
  group('Exercise.fromMap (linha devolvida por listar_modelos)', () {
    test('lê todos os campos, inclusive foto e dono', () {
      final e = Exercise.fromMap({
        'id': 'e1',
        'nome': 'Supino reto',
        'grupo_muscular': 'Peito, Tríceps',
        'descricao': 'Barra',
        'foto_path': 'adm/modelo.jpg',
        'dono_id': 'adm',
      });
      expect(e.nome, 'Supino reto');
      expect(e.grupos, ['Peito', 'Tríceps']);
      expect(e.fotoPath, 'adm/modelo.jpg');
      expect(e.donoId, 'adm');
    });

    test('foto e descrição podem ser nulas', () {
      final e = Exercise.fromMap({
        'id': 'e2',
        'nome': 'Agachamento',
        'grupo_muscular': 'Pernas',
        'descricao': null,
        'foto_path': null,
        'dono_id': 'adm',
      });
      expect(e.fotoPath, isNull);
      expect(e.descricao, isNull);
    });
  });

  group('rota /admin/modelos', () {
    final professor = Profile(
      id: 'p1',
      nome: 'Prof',
      email: 'p@t.com',
      perfil: Perfil.professor,
      ativo: true,
      academiaId: 'g1',
    );
    final aluno = Profile(
      id: 'a1',
      nome: 'Aluno',
      email: 'a@t.com',
      perfil: Perfil.aluno,
      ativo: true,
      academiaId: 'g1',
    );

    test('professor logado pode abrir', () {
      expect(
        decidirRedirecionamento(
          carregando: false,
          perfil: professor,
          local: Rotas.modelos,
        ),
        isNull,
      );
    });
    test('aluno é mandado para a área do aluno', () {
      expect(
        decidirRedirecionamento(
          carregando: false,
          perfil: aluno,
          local: Rotas.modelos,
        ),
        Rotas.aluno,
      );
    });
    test('visitante vai para a escolha da academia', () {
      expect(
        decidirRedirecionamento(
          carregando: false,
          perfil: null,
          local: Rotas.modelos,
        ),
        Rotas.academias,
      );
    });
  });
}
