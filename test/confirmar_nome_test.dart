import 'package:flutter_test/flutter_test.dart';
import 'package:personal_trainer/features/admin/presentation/confirmar_nome_dialog.dart';

void main() {
  group('nomeConfere', () {
    test('ignora maiúsculas e espaços sobrando', () {
      expect(nomeConfere('  maria   SILVA ', 'Maria Silva'), isTrue);
    });
    test('recusa nome diferente ou vazio', () {
      expect(nomeConfere('Maria', 'Maria Silva'), isFalse);
      expect(nomeConfere('', 'Maria Silva'), isFalse);
    });
  });
}
