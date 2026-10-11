import 'dia_semana.dart';

/// Segundos -> texto legível. Ex.: 45 -> "45 s", 90 -> "1 min 30 s", 120 -> "2 min".
String formatarTempo(int segundos) {
  if (segundos < 60) return '$segundos s';
  final minutos = segundos ~/ 60;
  final resto = segundos % 60;
  return resto == 0 ? '$minutos min' : '$minutos min $resto s';
}

/// Carga em kg. Ex.: 20.0 -> "20 kg", 22.5 -> "22,5 kg".
String formatarCarga(double kg) {
  final inteiro = kg == kg.roundToDouble();
  final texto = inteiro ? kg.toInt().toString() : kg.toString().replaceAll('.', ',');
  return '$texto kg';
}

/// Primeira letra do nome, para o "avatar" redondo.
String inicial(String nome) {
  final texto = nome.trim();
  return texto.isEmpty ? '?' : texto.substring(0, 1).toUpperCase();
}

/// "Maria da Silva" -> "Maria". Se o nome estiver vazio, devolve vazio.
String primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.first;
}

const List<String> _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Data por extenso. Ex.: "Sábado, 10 de outubro".
String formatarDataLonga(DateTime data) {
  // DateTime.weekday: segunda = 1 ... domingo = 7. "% 7" deixa domingo = 0.
  return '${nomeDoDia(data.weekday % 7)}, ${data.day} de ${_meses[data.month - 1]}';
}

/// Data no formato da coluna `date` do banco. Ex.: "2026-10-10".
/// Usamos a data LOCAL do aparelho do aluno (evita erro de fuso horário).
String dataParaBanco(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mes-$dia';
}
