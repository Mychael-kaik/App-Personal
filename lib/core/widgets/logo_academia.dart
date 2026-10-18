import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Logo de uma academia (bucket público `logos`). Sem logo, ou se a imagem
/// não carregar, mostra um círculo com a inicial do nome.
class LogoAcademia extends StatelessWidget {
  const LogoAcademia({
    super.key,
    required this.nome,
    this.logoPath,
    this.tamanho = 56,
  });

  final String nome;
  final String? logoPath;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final inicial = nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();

    final alternativa = Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        inicial,
        style: TextStyle(
          fontSize: tamanho * 0.42,
          fontWeight: FontWeight.w800,
          color: cores.onPrimaryContainer,
        ),
      ),
    );

    final caminho = logoPath;
    if (caminho == null || caminho.isEmpty) return alternativa;

    final url =
        Supabase.instance.client.storage.from('logos').getPublicUrl(caminho);
    return ClipOval(
      child: Image.network(
        url,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => alternativa,
        loadingBuilder: (context, filho, progresso) =>
            progresso == null ? filho : alternativa,
      ),
    );
  }
}
