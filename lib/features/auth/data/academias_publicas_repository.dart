import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/academia_publica.dart';

/// Lê a lista de academias para a tela de escolha (antes do login).
/// Usa a função `listar_academias_publicas` do banco: ela devolve só id, nome
/// e logo das academias ativas, e funciona sem estar logado.
final academiasPublicasProvider =
    FutureProvider.autoDispose<List<AcademiaPublica>>((ref) async {
  final dados = await Supabase.instance.client.rpc('listar_academias_publicas');
  return (dados as List)
      .map<AcademiaPublica>(
        (linha) => AcademiaPublica.fromMap(linha as Map<String, dynamic>),
      )
      .toList();
});
