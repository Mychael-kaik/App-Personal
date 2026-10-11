/// Grupos musculares oferecidos ao cadastrar um exercício.
const List<String> gruposMusculares = [
  'Peito',
  'Costas',
  'Ombros',
  'Bíceps',
  'Tríceps',
  'Pernas',
  'Glúteos',
  'Abdômen',
  'Cardio',
  'Corpo inteiro',
  'Outro',
];

/// Uma linha da tabela `exercises` (biblioteca de exercícios).
class Exercise {
  const Exercise({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    this.descricao,
  });

  final String id;
  final String nome;
  final String grupoMuscular;
  final String? descricao;

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      nome: map['nome'] as String,
      grupoMuscular: map['grupo_muscular'] as String,
      descricao: map['descricao'] as String?,
    );
  }

  // Dois exercícios são "o mesmo" se tiverem o mesmo id.
  // Isso ajuda a lista de escolha a marcar o item selecionado.
  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
