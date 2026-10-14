/// Um exercício que o aluno concluiu em um dia (uma linha de `completions`
/// com os dados do exercício junto).
class RegistroTreino {
  const RegistroTreino({
    required this.data,
    required this.exercicio,
    this.grupo,
    required this.series,
    this.repeticoes,
    this.carga,
    this.tituloTreino,
  });

  /// Só a data (sem hora), no calendário local.
  final DateTime data;
  final String exercicio;
  final String? grupo;
  final int series;
  final int? repeticoes;
  final double? carga;
  final String? tituloTreino;

  factory RegistroTreino.fromMap(Map<String, dynamic> map) {
    final item = (map['workout_items'] as Map<String, dynamic>?) ?? const {};
    final ex = item['exercises'] as Map<String, dynamic>?;
    final treino = item['workouts'] as Map<String, dynamic>?;

    // "2026-10-13" -> 13/10/2026, montando a data na mão (sem fuso horário).
    final partes = (map['data'] as String).split('-');
    final data = DateTime(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );

    return RegistroTreino(
      data: data,
      exercicio: (ex?['nome'] as String?) ?? 'Exercício',
      grupo: ex?['grupo_muscular'] as String?,
      series: (item['series'] as num?)?.toInt() ?? 0,
      repeticoes: (item['repeticoes'] as num?)?.toInt(),
      carga: (item['carga'] as num?)?.toDouble(),
      tituloTreino: treino?['titulo'] as String?,
    );
  }
}
