import 'package:flutter_test/flutter_test.dart';
import 'package:personal_trainer/core/rotas.dart';
import 'package:personal_trainer/core/router.dart';
import 'package:personal_trainer/core/validators.dart';
import 'package:personal_trainer/features/auth/domain/recuperacao.dart';

void main() {
  group('Validators.codigoDoEmail', () {
    test('aceita 6 a 10 dígitos', () {
      expect(Validators.codigoDoEmail('123456'), isNull);
      expect(Validators.codigoDoEmail(' 12345678 '), isNull);
    });
    test('recusa vazio, curto, longo e letras', () {
      expect(Validators.codigoDoEmail(''), isNotNull);
      expect(Validators.codigoDoEmail('12345'), isNotNull);
      expect(Validators.codigoDoEmail('12345678901'), isNotNull);
      expect(Validators.codigoDoEmail('12a456'), isNotNull);
    });
  });

  group('traduzirErroDeRecuperacao', () {
    test('código vencido', () {
      expect(
        traduzirErroDeRecuperacao(codigo: 'otp_expired'),
        contains('inválido ou vencido'),
      );
    });
    test('mesma senha', () {
      expect(
        traduzirErroDeRecuperacao(codigo: 'same_password'),
        contains('diferente'),
      );
    });
    test('limite de envios', () {
      expect(
        traduzirErroDeRecuperacao(mensagem: 'email rate limit exceeded'),
        contains('Muitas tentativas'),
      );
    });
    test('erro desconhecido cai na mensagem geral', () {
      expect(traduzirErroDeRecuperacao(), contains('conexão'));
    });
  });

  group('rota /recuperar', () {
    test('deslogado pode abrir a recuperação sem escolher academia', () {
      expect(
        decidirRedirecionamento(
          carregando: false,
          perfil: null,
          local: Rotas.recuperar,
        ),
        isNull,
      );
    });
  });
}
