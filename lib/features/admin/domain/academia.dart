/// Uma linha da tabela `academias`.
class Academia {
  const Academia({
    required this.id,
    required this.nome,
    required this.ativo,
  });

  final String id;
  final String nome;
  final bool ativo;

  factory Academia.fromMap(Map<String, dynamic> map) {
    return Academia(
      id: map['id'] as String,
      nome: map['nome'] as String,
      ativo: map['ativo'] as bool,
    );
  }

  // Igualdade por id: ajuda as listas de escolha a marcar o item selecionado.
  @override
  bool operator ==(Object other) => other is Academia && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
