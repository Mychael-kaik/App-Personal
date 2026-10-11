import 'package:flutter/material.dart';

/// Campo de formulário "escolha uma opção" com validação.
///
/// Ao tocar, abre uma lista numa folha inferior (fácil de usar no celular).
/// Substitui o DropdownButtonFormField, que muda de API entre versões do Flutter.
///
/// O tipo [T] é o da opção: String, int, um objeto Exercise, etc.
class PickerField<T> extends FormField<T> {
  PickerField({
    super.key,
    required String rotulo,
    required List<T> opcoes,
    required String Function(T opcao) rotuloDe,
    String? Function(T opcao)? subtituloDe,
    T? valorInicial,
    ValueChanged<T>? onChanged,
    super.validator,
    IconData? icone,
    bool buscavel = false,
  }) : super(
          initialValue: valorInicial,
          builder: (FormFieldState<T> estado) {
            final valor = estado.value;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final escolhido = await _abrirSeletor<T>(
                  context: estado.context,
                  titulo: rotulo,
                  opcoes: opcoes,
                  rotuloDe: rotuloDe,
                  subtituloDe: subtituloDe,
                  selecionado: valor,
                  buscavel: buscavel,
                );
                if (escolhido != null) {
                  estado.didChange(escolhido);
                  onChanged?.call(escolhido);
                }
              },
              child: InputDecorator(
                isEmpty: valor == null,
                decoration: InputDecoration(
                  labelText: rotulo,
                  prefixIcon: icone == null ? null : Icon(icone),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  errorText: estado.errorText,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  valor == null ? '' : rotuloDe(valor),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            );
          },
        );
}

Future<T?> _abrirSeletor<T>({
  required BuildContext context,
  required String titulo,
  required List<T> opcoes,
  required String Function(T opcao) rotuloDe,
  required String? Function(T opcao)? subtituloDe,
  required T? selecionado,
  required bool buscavel,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SeletorSheet<T>(
      titulo: titulo,
      opcoes: opcoes,
      rotuloDe: rotuloDe,
      subtituloDe: subtituloDe,
      selecionado: selecionado,
      buscavel: buscavel,
    ),
  );
}

class _SeletorSheet<T> extends StatefulWidget {
  const _SeletorSheet({
    required this.titulo,
    required this.opcoes,
    required this.rotuloDe,
    required this.subtituloDe,
    required this.selecionado,
    required this.buscavel,
  });

  final String titulo;
  final List<T> opcoes;
  final String Function(T opcao) rotuloDe;
  final String? Function(T opcao)? subtituloDe;
  final T? selecionado;
  final bool buscavel;

  @override
  State<_SeletorSheet<T>> createState() => _SeletorSheetState<T>();
}

class _SeletorSheetState<T> extends State<_SeletorSheet<T>> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final termo = _busca.trim().toLowerCase();
    final filtradas = widget.opcoes
        .where((o) => widget.rotuloDe(o).toLowerCase().contains(termo))
        .toList();
    final alturaDaTela = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaDaTela * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                widget.titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (widget.buscavel)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
            Flexible(
              child: filtradas.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nada encontrado.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtradas.length,
                      itemBuilder: (ctx, i) {
                        final opcao = filtradas[i];
                        final subtitulo = widget.subtituloDe?.call(opcao);
                        return ListTile(
                          minVerticalPadding: 12,
                          title: Text(
                            widget.rotuloDe(opcao),
                            style: const TextStyle(fontSize: 17),
                          ),
                          subtitle: subtitulo == null ? null : Text(subtitulo),
                          trailing: opcao == widget.selecionado
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(opcao),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
