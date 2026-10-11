/// Erro "amigável": a mensagem já está pronta para mostrar ao usuário.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
