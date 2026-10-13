import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/estilos.dart';
import '../../../core/mensagens.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/foto_exercicio.dart';
import '../data/admin_providers.dart';
import '../domain/exercise.dart';

/// Abre a folha inferior para criar (exercicio == null) ou editar um exercício.
Future<void> abrirFormularioExercicio(
  BuildContext context, {
  Exercise? exercicio,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ExerciseSheet(exercicio: exercicio),
  );
}

class ExerciseSheet extends ConsumerStatefulWidget {
  const ExerciseSheet({super.key, this.exercicio});

  final Exercise? exercicio;

  @override
  ConsumerState<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends ConsumerState<ExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descricaoCtrl;
  // Grupos escolhidos (pode ser mais de um).
  List<String> _grupos = [];
  // Opções mostradas: os grupos padrão + algum grupo antigo que o exercício
  // já tinha e que não está na lista padrão (assim ele não se perde).
  late final List<String> _opcoes;
  bool _salvando = false;
  String? _erro;

  // Foto: a que já está salva, a nova escolhida (ainda não enviada) e se o
  // admin pediu para tirar a foto.
  String? _fotoAtual;
  Uint8List? _fotoNova;
  String _fotoNovaTipo = 'image/jpeg';
  bool _tirarFoto = false;

  bool get _editando => widget.exercicio != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercicio;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _descricaoCtrl = TextEditingController(text: e?.descricao ?? '');
    _grupos = e?.grupos ?? [];
    _fotoAtual = e?.fotoPath;
    _opcoes = [
      ...gruposMusculares,
      ..._grupos.where((g) => !gruposMusculares.contains(g)),
    ];
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  static const _tiposAceitos = {'image/jpeg', 'image/png', 'image/webp'};
  static const _limiteBytes = 2 * 1024 * 1024; // 2 MB (igual ao do bucket)

  Future<void> _escolherFoto() async {
    try {
      // Reduz a foto (até 1280 px) e comprime: fica bem abaixo de 2 MB.
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (arquivo == null) return; // cancelou
      final bytes = await arquivo.readAsBytes();
      final tipo = _tipoDaImagem(arquivo.mimeType, arquivo.name);
      if (!mounted) return;
      if (tipo == null) {
        mostrarMensagem(context, 'Use uma foto JPG, PNG ou WebP.', erro: true);
        return;
      }
      if (bytes.length > _limiteBytes) {
        mostrarMensagem(
          context,
          'A foto é grande demais (máximo 2 MB). Escolha outra.',
          erro: true,
        );
        return;
      }
      setState(() {
        _fotoNova = bytes;
        _fotoNovaTipo = tipo;
        _tirarFoto = false;
      });
    } catch (_) {
      if (mounted) {
        mostrarMensagem(context, 'Não foi possível abrir a foto.', erro: true);
      }
    }
  }

  /// Descobre o tipo da imagem pelo tipo informado ou pela extensão.
  String? _tipoDaImagem(String? mime, String nome) {
    if (mime != null && _tiposAceitos.contains(mime)) return mime;
    final n = nome.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final nome = _nomeCtrl.text.trim();
    final descricao =
        _descricaoCtrl.text.trim().isEmpty ? null : _descricaoCtrl.text.trim();

    final grupoMuscular = Exercise.juntarGrupos(_grupos);

    String? enviada; // foto nova já enviada ao Storage
    var gravou = false;
    try {
      if (_fotoNova != null) {
        enviada = await repo.enviarFoto(
          bytes: _fotoNova!,
          contentType: _fotoNovaTipo,
        );
      }
      final fotoFinal = enviada ?? (_tirarFoto ? null : _fotoAtual);

      if (_editando) {
        await repo.atualizarExercicio(
          widget.exercicio!.id,
          nome: nome,
          grupoMuscular: grupoMuscular,
          descricao: descricao,
          fotoPath: fotoFinal,
        );
      } else {
        await repo.criarExercicio(
          nome: nome,
          grupoMuscular: grupoMuscular,
          descricao: descricao,
          fotoPath: fotoFinal,
        );
      }
      gravou = true;

      // Só agora que o banco apontou para a foto nova é seguro apagar a antiga.
      if (_fotoAtual != null && fotoFinal != _fotoAtual) {
        await repo.removerFoto(_fotoAtual!);
      }
      ref.invalidate(exerciciosProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Falhou ao gravar: não deixa a foto nova "órfã" no Storage.
      if (!gravou && enviada != null) await repo.removerFoto(enviada);
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Foto de exemplo do exercício: mostra a atual/nova e os botões.
  Widget _campoFoto(ThemeData tema) {
    final temFoto = _fotoNova != null || (_fotoAtual != null && !_tirarFoto);

    Widget imagem;
    if (_fotoNova != null) {
      imagem = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.memory(_fotoNova!, fit: BoxFit.cover),
        ),
      );
    } else if (_fotoAtual != null && !_tirarFoto) {
      imagem = FotoExercicio(caminho: _fotoAtual!);
    } else {
      imagem = const SemFoto();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto de exemplo',
          style:
              tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Aparece para o aluno na tela do exercício. JPG, PNG ou WebP, até 2 MB.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        imagem,
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: compactoContorno(),
              onPressed: _salvando ? null : _escolherFoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(temFoto ? 'Trocar foto' : 'Escolher foto'),
            ),
            if (temFoto)
              TextButton.icon(
                onPressed: _salvando
                    ? null
                    : () => setState(() {
                          if (_fotoNova != null) {
                            // Só descarta a foto recém-escolhida.
                            _fotoNova = null;
                          } else {
                            _tirarFoto = true;
                          }
                        }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover foto'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      // Sobe a folha quando o teclado abre.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando ? 'Editar exercício' : 'Novo exercício',
                style: tema.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                enabled: !_salvando,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  labelText: 'Nome do exercício',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => Validators.nome(v, campo: 'O nome'),
              ),
              const SizedBox(height: 16),
              // Seleção múltipla: cada botão liga/desliga um grupo.
              FormField<List<String>>(
                initialValue: _grupos,
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Escolha pelo menos um grupo muscular.'
                    : null,
                builder: (campo) {
                  final escolhidos = campo.value ?? <String>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grupos musculares',
                        style: tema.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Toque para escolher um ou mais.',
                        style: tema.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final g in _opcoes)
                            FilterChip(
                              label: Text(g, style: const TextStyle(fontSize: 15)),
                              selected: escolhidos.contains(g),
                              onSelected: _salvando
                                  ? null
                                  : (marcado) {
                                      final novo = [...escolhidos];
                                      if (marcado) {
                                        novo.add(g);
                                      } else {
                                        novo.remove(g);
                                      }
                                      _grupos = novo;
                                      campo.didChange(novo);
                                    },
                            ),
                        ],
                      ),
                      if (campo.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            campo.errorText!,
                            style: TextStyle(
                              fontSize: 13,
                              color: tema.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _campoFoto(tema),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoCtrl,
                enabled: !_salvando,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  helperText: 'Como executar, dicas de postura...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => Validators.tamanhoMaximo(v, 300),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _erro!,
                    style: TextStyle(
                      fontSize: 15,
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
