import 'package:flutter_test/flutter_test.dart';
import 'package:personal_trainer/core/router.dart';
import 'package:personal_trainer/core/rotas.dart';
import 'package:personal_trainer/features/auth/domain/profile.dart';
import 'package:personal_trainer/features/auth/domain/regra_de_entrada.dart';

Profile _perfil(Perfil tipo, {String? academia}) => Profile(
      id: 'u1',
      nome: 'Teste',
      email: 't@t.com',
      perfil: tipo,
      ativo: true,
      academiaId: academia,
    );

void main() {
  group('verificarEntrada (porta da academia)', () {
    test('aluno da academia escolhida entra', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.aluno, academia: 'A1'),
          academiaId: 'A1',
          modoAdmin: false,
        ),
        isNull,
      );
    });

    test('aluno de OUTRA academia é recusado', () {
      final erro = verificarEntrada(
        perfil: _perfil(Perfil.aluno, academia: 'A2'),
        academiaId: 'A1',
        modoAdmin: false,
      );
      expect(erro, 'Você não é um aluno cadastrado nesta academia.');
    });

    test('aluno sem academia (ainda sem professor) é recusado', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.aluno),
          academiaId: 'A1',
          modoAdmin: false,
        ),
        isNotNull,
      );
    });

    test('professor da academia entra; de outra, não', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.professor, academia: 'A1'),
          academiaId: 'A1',
          modoAdmin: false,
        ),
        isNull,
      );
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.professor, academia: 'A2'),
          academiaId: 'A1',
          modoAdmin: false,
        ),
        'Você não é um professor cadastrado nesta academia.',
      );
    });

    test('administrador geral não entra pela porta de uma academia', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.admin),
          academiaId: 'A1',
          modoAdmin: false,
        ),
        isNotNull,
      );
    });

    test('porta do administrador: só admin entra', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.admin),
          academiaId: null,
          modoAdmin: true,
        ),
        isNull,
      );
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.aluno, academia: 'A1'),
          academiaId: null,
          modoAdmin: true,
        ),
        isNotNull,
      );
    });

    test('sem porta escolhida: recusa', () {
      expect(
        verificarEntrada(
          perfil: _perfil(Perfil.aluno, academia: 'A1'),
          academiaId: null,
          modoAdmin: false,
        ),
        isNotNull,
      );
    });
  });

  group('decidirRedirecionamento', () {
    test('carregando: fica na splash', () {
      expect(
        decidirRedirecionamento(
            carregando: true, perfil: null, local: Rotas.academias),
        Rotas.splash,
      );
      expect(
        decidirRedirecionamento(
            carregando: true, perfil: null, local: Rotas.splash),
        isNull,
      );
    });

    test('sem login: splash e rotas internas vão para a escolha da academia', () {
      for (final local in [Rotas.splash, Rotas.admin, Rotas.aluno, '/x']) {
        expect(
          decidirRedirecionamento(
              carregando: false, perfil: null, local: local),
          Rotas.academias,
        );
      }
    });

    test('sem login: login só abre depois de escolher a academia', () {
      expect(
        decidirRedirecionamento(
            carregando: false, perfil: null, local: Rotas.login),
        Rotas.academias,
      );
      expect(
        decidirRedirecionamento(
            carregando: false,
            perfil: null,
            local: Rotas.login,
            temEscolha: true),
        isNull,
      );
    });

    test('sem login: a escolha da academia sempre abre', () {
      expect(
        decidirRedirecionamento(
            carregando: false, perfil: null, local: Rotas.academias),
        isNull,
      );
    });

    test('logado: equipe vai para /admin e aluno para /aluno', () {
      expect(
        decidirRedirecionamento(
            carregando: false,
            perfil: _perfil(Perfil.professor, academia: 'A1'),
            local: Rotas.academias),
        Rotas.admin,
      );
      expect(
        decidirRedirecionamento(
            carregando: false,
            perfil: _perfil(Perfil.aluno, academia: 'A1'),
            local: Rotas.login),
        Rotas.aluno,
      );
      expect(
        decidirRedirecionamento(
            carregando: false,
            perfil: _perfil(Perfil.aluno, academia: 'A1'),
            local: Rotas.admin),
        Rotas.aluno,
      );
    });
  });
}
