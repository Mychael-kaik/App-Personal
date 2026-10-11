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
