import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/widgets/logo_academia.dart';
import '../data/admin_providers.dart';
import '../domain/academia.dart';

/// Cria (academia == null) ou edita uma academia. Só o administrador geral
/// consegue gravar (o banco recusa qualquer outra pessoa).
Future<void> abrirFormularioAcademia(
  BuildContext context, {
  Academia? academia,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AcademiaDialog(academia: academia),
  );
}

class _AcademiaDialog extends ConsumerStatefulWidget {
  const _AcademiaDialog({this.academia});

  final Academia? academia;

  @override
  ConsumerState<_AcademiaDialog> createState() => _AcademiaDialogState();
}

class _AcademiaDialogState extends ConsumerState<_AcademiaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late bool _ativo;
  bool _salvando = false;
  String? _erro;

  // Logo: nova escolhida (bytes) ou pedido para tirar a atual.
  Uint8List? _logoNova;
  String _logoNovaTipo = 'image/jpeg';
  bool _tirarLogo = false;

  static const _tiposAceitos = {'image/jpeg', 'image/png', 'image/webp'};
  static const _limiteBytes = 1024 * 1024; // 1 MB (igual ao do bucket)

  bool get _editando => widget.academia != null;

  /// Tem uma logo para mostrar (a nova escolhida ou a atual não removida)?
  bool get _temLogo =>
      _logoNova != null || (widget.academia?.logoPath != null && !_tirarLogo);

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.academia?.nome ?? '');
    _ativo = widget.academia?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherLogo() async {
    try {
      // Reduz (até 512 px) e comprime: fica bem abaixo de 1 MB.
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (arquivo == null) return;
      final bytes = await arquivo.readAsBytes();
      final tipo = _tipoDaImagem(arquivo.mimeType, arquivo.name);
      if (!mounted) return;
      if (tipo == null) {
        mostrarMensagem(context, 'Use uma imagem JPG, PNG ou WebP.', erro: true);
        return;
      }
      if (bytes.length > _limiteBytes) {
        mostrarMensagem(
          context,
          'A imagem é grande demais (máximo 1 MB). Escolha outra.',
          erro: true,
        );
        return;
      }
      setState(() {
        _logoNova = bytes;
        _logoNovaTipo = tipo;
        _tirarLogo = false;
      });
    } catch (_) {
      if (mounted) {
        mostrarMensagem(context, 'Não foi possível abrir a imagem.', erro: true);
      }
    }
  }

  String? _tipoDaImagem(String? mime, String nome) {
    if (mime != null && _tiposAceitos.contains(mime)) return mime;
    final n = nome.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (!_formKey.currentState!.validate()) return;

    // Suspender uma academia derruba o acesso de TODOS os professores e alunos dela.
    if (_editando && widget.academia!.ativo && !_ativo) {
      final ok = await confirmar(
        context,
        titulo: 'Suspender a academia?',
        mensagem:
            'Todos os professores e alunos de "${widget.academia!.nome}" perdem '
            'o acesso ao app até você reativar. Nada é apagado.',
        textoConfirmar: 'Suspender',
        perigo: true,
      );
      if (!ok || !mounted) return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final nome = _nomeCtrl.text.trim();
    try {
      final antiga = widget.academia?.logoPath;
      if (_editando) {
        final id = widget.academia!.id;
        String? novoCaminho;
        if (_logoNova != null) {
          novoCaminho = await repo.enviarLogo(
            academiaId: id,
            bytes: _logoNova!,
            contentType: _logoNovaTipo,
          );
        }
        await repo.atualizarAcademia(
          id,
          nome: nome,
          ativo: _ativo,
          logoPath: novoCaminho,
          removerLogo: _tirarLogo,
        );
        // Só apaga a logo antiga depois de gravar a nova com sucesso.
        if (antiga != null && (novoCaminho != null || _tirarLogo)) {
          await repo.removerLogo(antiga);
        }
      } else {
        final id = await repo.criarAcademia(nome);
        if (_logoNova != null) {
          try {
            final caminho = await repo.enviarLogo(
              academiaId: id,
              bytes: _logoNova!,
              contentType: _logoNovaTipo,
            );
            await repo.atualizarAcademia(
              id,
              nome: nome,
              ativo: true,
              logoPath: caminho,
            );
          } catch (_) {
            // A academia já foi criada: avisamos e não deixamos criar duas.
            ref.invalidate(academiasProvider);
            if (mounted) {
              Navigator.of(context).pop();
              mostrarMensagem(
                context,
                'Academia criada, mas a logo não foi enviada. '
                'Toque em editar para tentar de novo.',
                erro: true,
              );
            }
            return;
          }
        }
      }
      ref.invalidate(academiasProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(_editando ? 'Editar academia' : 'Nova academia'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _logoNova != null
                  ? ClipOval(
                      child: Image.memory(
                        _logoNova!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    )
                  : LogoAcademia(
                      nome: _nomeCtrl.text,
                      logoPath: _tirarLogo ? null : widget.academia?.logoPath,
                      tamanho: 72,
                    ),
            ),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _salvando ? null : _escolherLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_temLogo ? 'Trocar logo' : 'Adicionar logo'),
                  ),
                  if (_temLogo)
                    TextButton(
                      onPressed: _salvando
                          ? null
                          : () => setState(() {
                                _logoNova = null;
                                _tirarLogo = widget.academia?.logoPath != null;
                              }),
                      child: const Text('Tirar logo'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nomeCtrl,
              enabled: !_salvando,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(labelText: 'Nome da academia'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Informe o nome (2 a 100 letras).';
                return null;
              },
            ),
            if (_editando)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Academia ativa'),
                subtitle: Text(
                  _ativo
                      ? 'Professores e alunos podem entrar.'
                      : 'Todos perdem o acesso até reativar.',
                ),
                value: _ativo,
                onChanged: _salvando ? null : (v) => setState(() => _ativo = v),
              ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(
                _erro!,
                style: TextStyle(color: tema.colorScheme.error, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: compactoPreenchido(),
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
