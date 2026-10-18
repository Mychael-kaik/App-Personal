/// Uma linha da tabela `academias`.
class Academia {
  const Academia({
    required this.id,
    required this.nome,
    required this.ativo,
    this.logoPath,
  });

  final String id;
  final String nome;
  final bool ativo;

  /// Caminho da logo no bucket público `logos` (null = sem logo).
  final String? logoPath;

  factory Academia.fromMap(Map<String, dynamic> map) {
    return Academia(
      id: map['id'] as String,
      nome: map['nome'] as String,
      ativo: map['ativo'] as bool,
      logoPath: map['logo_path'] as String?,
    );
  }

  // Igualdade por id: ajuda as listas de escolha a marcar o item selecionado.
  @override
  bool operator ==(Object other) => other is Academia && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
