/// Validadores reutilizáveis para os campos de formulário.
/// Cada função devolve `null` quando está tudo certo,
/// ou o texto do erro quando o valor é inválido.
class Validators {
  const Validators._();

  static String? obrigatorio(String? valor, {String campo = 'Este campo'}) {
    if (valor == null || valor.trim().isEmpty) {
      return '$campo é obrigatório.';
    }
    return null;
  }

  /// Nome de pessoa ou de exercício: obrigatório, de 2 a [max] caracteres.
  static String? nome(String? valor, {String campo = 'O nome', int max = 100}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return '$campo é obrigatório.';
    if (texto.length < 2) return '$campo precisa ter pelo menos 2 letras.';
    if (texto.length > max) return '$campo pode ter no máximo $max caracteres.';
    return null;
  }

  static String? email(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe o e-mail.';
    final formatoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto);
    if (!formatoValido) return 'Informe um e-mail válido.';
    return null;
  }

  /// Usada ao CRIAR uma senha (o Supabase exige no mínimo 6 caracteres).
  static String? senhaNova(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Informe a senha.';
    if (texto.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
    return null;
  }

  /// Campo opcional com limite de tamanho (descrições, observações).
  static String? tamanhoMaximo(String? valor, int max) {
    if ((valor ?? '').trim().length > max) {
      return 'Use no máximo $max caracteres.';
    }
    return null;
  }

  /// Número inteiro entre [min] e [max]. Se [obrigatorio] for false,
  /// o campo pode ficar vazio.
  static String? inteiro(
    String? valor, {
    required String campo,
    int min = 1,
    int max = 999,
    bool obrigatorio = true,
  }) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) {
      return obrigatorio ? '$campo é obrigatório.' : null;
    }
    final numero = int.tryParse(texto);
    if (numero == null) return 'Use apenas números inteiros.';
    if (numero < min || numero > max) {
      return '$campo deve ficar entre $min e $max.';
    }
    return null;
  }

  /// Número decimal opcional (aceita vírgula ou ponto), de 0 a [max].
  static String? decimalOpcional(
    String? valor, {
    required String campo,
    double max = 999.99,
  }) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    if (texto.isEmpty) return null;
    final numero = double.tryParse(texto);
    if (numero == null) return 'Número inválido.';
    if (numero < 0 || numero > max) {
      final limite = max.toString().replaceAll('.', ',');
      return '$campo deve ficar entre 0 e $limite.';
    }
    return null;
  }
}
