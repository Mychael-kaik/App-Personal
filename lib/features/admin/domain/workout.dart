import '../../../core/formatters.dart';

/// Um item do treino: "Supino reto, 3 x 12, descanso 60 s, 20 kg".
/// Corresponde a uma linha da tabela `workout_items`.
class WorkoutItem {
  const WorkoutItem({
    this.id,
    required this.exerciseId,
    required this.exerciseNome,
    this.grupoMuscular,
    required this.series,
    this.repeticoes,
    this.tempoSegundos,
    this.descansoSerieSegundos,
    this.descansoSegundos,
    this.carga,
    this.observacao,
    this.ordem = 0,
    this.exercicioDescricao,
    this.fotoPath,
  });

  /// null enquanto o item ainda não foi salvo no banco.
  final String? id;
  final String exerciseId;
  final String exerciseNome;
  final String? grupoMuscular;
  final int series;
  final int? repeticoes;
  final int? tempoSegundos;

  /// Descanso entre uma série e outra (segundos). null/0 = sem cronômetro.
  final int? descansoSerieSegundos;

  /// Descanso ao terminar o exercício todo (segundos). null/0 = sem cronômetro.
  final int? descansoSegundos;
  final double? carga;
  final String? observacao;
  final int ordem;

  /// Texto geral do exercício (biblioteca) e caminho da foto de exemplo.
  final String? exercicioDescricao;
  final String? fotoPath;

  /// O Supabase devolve o item com o exercício "embutido":
  /// { id, series, ..., exercises: { nome, grupo_muscular } }
  factory WorkoutItem.fromMap(Map<String, dynamic> map) {
    final exercicio = map['exercises'] as Map<String, dynamic>?;
    return WorkoutItem(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      exerciseNome: (exercicio?['nome'] as String?) ?? 'Exercício',
      grupoMuscular: exercicio?['grupo_muscular'] as String?,
      series: (map['series'] as num).toInt(),
      repeticoes: (map['repeticoes'] as num?)?.toInt(),
      tempoSegundos: (map['tempo_segundos'] as num?)?.toInt(),
      descansoSerieSegundos: (map['descanso_serie_segundos'] as num?)?.toInt(),
      descansoSegundos: (map['descanso_segundos'] as num?)?.toInt(),
      carga: (map['carga'] as num?)?.toDouble(),
      observacao: map['observacao'] as String?,
      ordem: (map['ordem'] as num).toInt(),
      exercicioDescricao: exercicio?['descricao'] as String?,
      fotoPath: exercicio?['foto_path'] as String?,
    );
  }

  /// Formato enviado para a função SQL `salvar_treino`.
  /// (A ordem não vai: ela é a posição do item na lista.)
  Map<String, dynamic> paraRpc() => {
        'id': id,
        'exercise_id': exerciseId,
        'series': series,
        'repeticoes': repeticoes,
        'tempo_segundos': tempoSegundos,
        'descanso_serie_segundos': descansoSerieSegundos,
        'descanso_segundos': descansoSegundos,
        'carga': carga,
        'observacao': observacao,
      };

  /// Texto curto: "3 x 12 · 1 min · 20 kg".
  String get resumo {
    final partes = <String>[];
    if (repeticoes != null) {
      partes.add('$series x $repeticoes');
    } else {
      partes.add(series == 1 ? '1 série' : '$series séries');
    }
    if (tempoSegundos != null) partes.add(formatarTempo(tempoSegundos!));
    if (carga != null) partes.add(formatarCarga(carga!));
    return partes.join(' · ');
  }
}

/// Um treino de um aluno em um dia da semana (tabela `workouts`).
class Workout {
  const Workout({
    required this.id,
    required this.alunoId,
    required this.dia,
    required this.titulo,
    required this.itens,
  });

  final String id;
  final String alunoId;

  /// 0 = domingo ... 6 = sábado
  final int dia;
  final String titulo;
  final List<WorkoutItem> itens;

  factory Workout.fromMap(Map<String, dynamic> map) {
    final lista = ((map['workout_items'] as List<dynamic>?) ?? const [])
        .map((e) => WorkoutItem.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    return Workout(
      id: map['id'] as String,
      alunoId: map['aluno_id'] as String,
      dia: (map['dia_da_semana'] as num).toInt(),
      titulo: map['titulo'] as String,
      itens: lista,
    );
  }
}
