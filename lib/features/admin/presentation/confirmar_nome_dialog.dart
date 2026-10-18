import 'package:flutter/material.dart';

import '../../../core/estilos.dart';

/// Compara nomes ignorando maiúsculas e espaços sobrando.
bool nomeConfere(String digitado, String esperado) =>
    digitado.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
    esperado.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Pede para a pessoa DIGITAR o nome para confirmar uma exclusão definitiva.
/// Devolve o texto digitado (já conferido) ou null se cancelou.
Future<String?> pedirNomeParaExcluir(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String nomeEsperado,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmarNomeDialog(
      titulo: titulo,
      mensagem: mensagem,
      nomeEsperado: nomeEsperado,
    ),
  );
}

class _ConfirmarNomeDialog extends StatefulWidget {
  const _ConfirmarNomeDialog({
    required this.titulo,
    required this.mensagem,
    required this.nomeEsperado,
  });

  final String titulo;
  final String mensagem;
  final String nomeEsperado;

  @override
  State<_ConfirmarNomeDialog> createState() => _ConfirmarNomeDialogState();
}

class _ConfirmarNomeDialogState extends State<_ConfirmarNomeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final confere = nomeConfere(_ctrl.text, widget.nomeEsperado);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.mensagem),
            const SizedBox(height: 12),
            Text('Para confirmar, digite: ${widget.nomeEsperado}'),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido().merge(
            FilledButton.styleFrom(backgroundColor: tema.colorScheme.error),
          ),
          onPressed: confere
              ? () => Navigator.of(context).pop(_ctrl.text.trim())
              : null,
          child: const Text('Excluir de vez'),
        ),
      ],
    );
  }
}
