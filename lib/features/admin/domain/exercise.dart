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
    this.fotoPath,
  });

  final String id;
  final String nome;

  /// Todos os grupos juntos num texto só, separados por vírgula
  /// (ex.: "Peito, Tríceps"). É assim que fica guardado no banco.
  final String grupoMuscular;
  final String? descricao;

  /// Caminho da foto no Storage (bucket `exercicios`). null = sem foto.
  final String? fotoPath;

  /// Os grupos separados, em lista (ex.: ["Peito", "Tríceps"]).
  List<String> get grupos => separarGrupos(grupoMuscular);

  /// Junta uma lista de grupos no texto que vai para o banco.
  /// Os grupos padrão saem sempre na mesma ordem da lista [gruposMusculares];
  /// grupos antigos que não estão nela vão no final.
  static String juntarGrupos(Iterable<String> grupos) {
    final unicos = grupos.map((g) => g.trim()).where((g) => g.isNotEmpty).toSet();
    final padrao = gruposMusculares.where(unicos.contains);
    final outros = unicos.where((g) => !gruposMusculares.contains(g));
    return [...padrao, ...outros].join(', ');
  }

  /// Faz o caminho inverso: "Peito, Tríceps" -> ["Peito", "Tríceps"].
  static List<String> separarGrupos(String texto) {
    return texto
        .split(',')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      nome: map['nome'] as String,
      grupoMuscular: map['grupo_muscular'] as String,
      descricao: map['descricao'] as String?,
      fotoPath: map['foto_path'] as String?,
    );
  }

  // Dois exercícios são "o mesmo" se tiverem o mesmo id.
  // Isso ajuda a lista de escolha a marcar o item selecionado.
  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
