/// Dias da semana, no MESMO número usado no banco:
/// 0 = domingo, 1 = segunda, ... 6 = sábado.
const List<String> nomesDosDias = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

/// Ordem para MOSTRAR na tela: a semana começa na segunda-feira.
const List<int> ordemDaSemana = [1, 2, 3, 4, 5, 6, 0];

String nomeDoDia(int dia) => nomesDosDias[dia];

/// Dia de hoje no formato do banco (domingo = 0).
/// O Dart usa DateTime.weekday com segunda = 1 ... domingo = 7,
/// então "% 7" converte o domingo (7) em 0.
int diaDeHoje() => DateTime.now().weekday % 7;
