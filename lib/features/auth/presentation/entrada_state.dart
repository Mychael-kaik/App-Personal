import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/academia_publica.dart';

/// Por qual "porta" a pessoa está entrando: uma academia OU o administrador geral.
class EscolhaDeEntrada {
  const EscolhaDeEntrada({this.academia, this.modoAdmin = false});

  final AcademiaPublica? academia;
  final bool modoAdmin;

  /// Já escolheu alguma porta? (sem isso a tela de login não abre)
  bool get temEscolha => academia != null || modoAdmin;
}

class EntradaNotifier extends Notifier<EscolhaDeEntrada> {
  @override
  EscolhaDeEntrada build() => const EscolhaDeEntrada();

  void escolherAcademia(AcademiaPublica academia) =>
      state = EscolhaDeEntrada(academia: academia);

  void entrarComoAdmin() => state = const EscolhaDeEntrada(modoAdmin: true);

  void limpar() => state = const EscolhaDeEntrada();
}

final entradaProvider =
    NotifierProvider<EntradaNotifier, EscolhaDeEntrada>(EntradaNotifier.new);

/// Fica `true` depois de ~1,5 s: tempo de mostrar a logo do app ao abrir.
final splashProntoProvider = FutureProvider<bool>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  return true;
});
