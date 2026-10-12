import 'dart:math';

/// Senha aleatória (8 caracteres por padrão), sem letras que se confundem
/// na hora de ler ou ditar (0/O, 1/l/I). Usa o sorteio seguro do aparelho.
String gerarSenhaAleatoria({int tamanho = 8}) {
  const caracteres = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final sorteio = Random.secure();
  return List.generate(
    tamanho,
    (_) => caracteres[sorteio.nextInt(caracteres.length)],
  ).join();
}
