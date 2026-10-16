import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Link TEMPORÁRIO (1 hora) para uma foto do bucket privado `exercicios`.
///
/// O bucket é privado: não existe link público. Quem pede o link é o app,
/// logado, e o banco só entrega se a pessoa for um usuário ativo (RLS).
final urlDaFotoProvider =
    FutureProvider.autoDispose.family<String, String>((ref, caminho) {
  return Supabase.instance.client.storage
      .from('exercicios')
      .createSignedUrl(caminho, 3600);
});

/// Mostra a foto de um exercício (formato 4:3), com "carregando" e uma
/// mensagem amigável se a foto não puder ser baixada.
class FotoExercicio extends ConsumerWidget {
  const FotoExercicio({super.key, required this.caminho});

  final String caminho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = Theme.of(context).colorScheme;
    final url = ref.watch(urlDaFotoProvider(caminho));

    Widget aviso(IconData icone, String texto) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 40, color: cores.outline),
              const SizedBox(height: 8),
              Text(texto, style: TextStyle(color: cores.onSurfaceVariant)),
            ],
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: cores.surfaceContainerHighest,
          child: url.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                aviso(Icons.broken_image_outlined, 'Não foi possível abrir a foto'),
            data: (endereco) => Image.network(
              endereco,
              fit: BoxFit.cover,
              loadingBuilder: (context, filho, progresso) => progresso == null
                  ? filho
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) =>
                  aviso(Icons.broken_image_outlined, 'Não foi possível abrir a foto'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quadro mostrado quando o exercício não tem foto.
class SemFoto extends StatelessWidget {
  const SemFoto({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: ColoredBox(
          color: cores.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 36, color: cores.outline),
                const SizedBox(height: 6),
                Text('Sem foto de exemplo',
                    style: TextStyle(color: cores.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
