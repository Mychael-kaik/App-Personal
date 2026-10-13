import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validators.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/picker_field.dart';
import '../data/admin_providers.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';

/// Abre a folha para adicionar (inicial == null) ou editar um item do treino.
/// Devolve o [WorkoutItem] preenchido, ou null se o personal cancelar.
/// (Aqui NADA é gravado no banco: o treino inteiro é salvo de uma vez,
/// no botão "Salvar treino".)
Future<WorkoutItem?> abrirFormularioItem(
  BuildContext context, {
  WorkoutItem? inicial,
}) {
  return showModalBottomSheet<WorkoutItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WorkoutItemSheet(inicial: inicial),
  );
}

class WorkoutItemSheet extends ConsumerStatefulWidget {
  const WorkoutItemSheet({super.key, this.inicial});

  final WorkoutItem? inicial;

  @override
  ConsumerState<WorkoutItemSheet> createState() => _WorkoutItemSheetState();
}

class _WorkoutItemSheetState extends ConsumerState<WorkoutItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seriesCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _descSerieCtrl;
  late final TextEditingController _descFinalCtrl;
  late final TextEditingController _cargaCtrl;
  late final TextEditingController _obsCtrl;

  String? _exercicioId;
  String _exercicioNome = '';
  String? _grupo;

  bool get _editando => widget.inicial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _seriesCtrl = TextEditingController(text: i != null ? '${i.series}' : '3');
    _repsCtrl = TextEditingController(text: i?.repeticoes?.toString() ?? '');
    _tempoCtrl = TextEditingController(text: i?.tempoSegundos?.toString() ?? '');
    _descSerieCtrl =
        TextEditingController(text: i?.descansoSerieSegundos?.toString() ?? '');
    _descFinalCtrl =
        TextEditingController(text: i?.descansoSegundos?.toString() ?? '');
    _cargaCtrl = TextEditingController(
      text: i?.carga == null ? '' : _formatarParaCampo(i!.carga!),
    );
    _obsCtrl = TextEditingController(text: i?.observacao ?? '');
    _exercicioId = i?.exerciseId;
    _exercicioNome = i?.exerciseNome ?? '';
    _grupo = i?.grupoMuscular;
  }

  @override
  void dispose() {
    _seriesCtrl.dispose();
    _repsCtrl.dispose();
    _tempoCtrl.dispose();
    _descSerieCtrl.dispose();
    _descFinalCtrl.dispose();
    _cargaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  /// 20.0 -> "20", 22.5 -> "22,5" (como o personal digitaria).
  String _formatarParaCampo(double valor) {
    final inteiro = valor == valor.roundToDouble();
    return inteiro
        ? valor.toInt().toString()
        : valor.toString().replaceAll('.', ',');
  }

  /// Regra: o item precisa ter repetições OU tempo (ou os dois).
  String? _repsOuTempo(String? _) {
    if (_repsCtrl.text.trim().isEmpty && _tempoCtrl.text.trim().isEmpty) {
      return 'Informe repetições ou tempo.';
    }
    return null;
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    final obs = _obsCtrl.text.trim();
    final cargaTexto = _cargaCtrl.text.trim().replaceAll(',', '.');
    final carga = cargaTexto.isEmpty ? null : double.tryParse(cargaTexto);

    final item = WorkoutItem(
      id: widget.inicial?.id, // mantém o id: preserva as marcações do aluno
      exerciseId: _exercicioId!,
      exerciseNome: _exercicioNome,
      grupoMuscular: _grupo,
      series: int.parse(_seriesCtrl.text.trim()),
      repeticoes: int.tryParse(_repsCtrl.text.trim()),
      tempoSegundos: int.tryParse(_tempoCtrl.text.trim()),
      descansoSerieSegundos: int.tryParse(_descSerieCtrl.text.trim()),
      descansoSegundos: int.tryParse(_descFinalCtrl.text.trim()),
      carga: carga == null ? null : double.parse(carga.toStringAsFixed(2)),
      observacao: obs.isEmpty ? null : obs,
    );
    Navigator.of(context).pop(item);
  }

  InputDecoration _decoracao(String rotulo, {String? ajuda, String? sufixo}) {
    return InputDecoration(
      labelText: rotulo,
      helperText: ajuda,
      suffixText: sufixo,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final exercicios = ref.watch(exerciciosProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editando ? 'Editar exercício do treino' : 'Adicionar ao treino',
              style: tema.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            exercicios.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (erro, _) => SizedBox(
                height: 200,
                child: ErroView(
                  mensagem: 'Não foi possível carregar os exercícios.',
                  onTentarNovamente: () => ref.invalidate(exerciciosProvider),
                ),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Sua biblioteca de exercícios está vazia. Feche esta janela, '
                      'abra a aba "Exercícios" e cadastre alguns primeiro.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }
                return _formulario(lista);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario(List<Exercise> lista) {
    final selecionado = lista.where((e) => e.id == _exercicioId).firstOrNull;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField<Exercise>(
            rotulo: 'Exercício',
            opcoes: lista,
            rotuloDe: (e) => e.nome,
            subtituloDe: (e) => e.grupoMuscular,
            valorInicial: selecionado,
            buscavel: lista.length > 8,
            onChanged: (e) {
              _exercicioId = e.id;
              _exercicioNome = e.nome;
              _grupo = e.grupoMuscular;
            },
            validator: (v) => v == null ? 'Escolha o exercício.' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _seriesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao('Séries'),
                  validator: (v) => Validators.inteiro(
                    v,
                    campo: 'As séries',
                    min: 1,
                    max: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _repsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao('Repetições'),
                  validator: (v) =>
                      Validators.inteiro(
                        v,
                        campo: 'As repetições',
                        min: 1,
                        max: 999,
                        obrigatorio: false,
                      ) ??
                      _repsOuTempo(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _tempoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao(
                    'Tempo',
                    sufixo: 'seg',
                    ajuda: 'Duração (ex.: prancha)',
                  ),
                  validator: (v) =>
                      Validators.inteiro(
                        v,
                        campo: 'O tempo',
                        min: 1,
                        max: 7200,
                        obrigatorio: false,
                      ) ??
                      _repsOuTempo(v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cargaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao(
                    'Carga',
                    sufixo: 'kg',
                    ajuda: 'Opcional',
                  ),
                  validator: (v) =>
                      Validators.decimalOpcional(v, campo: 'A carga'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _descSerieCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao(
                    'Descanso entre séries',
                    sufixo: 'seg',
                    ajuda: 'Ex.: 30. Vazio = sem',
                  ),
                  validator: (v) => Validators.inteiro(
                    v,
                    campo: 'O descanso',
                    min: 1,
                    max: 3600,
                    obrigatorio: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _descFinalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: _decoracao(
                    'Descanso ao final',
                    sufixo: 'seg',
                    ajuda: 'Ex.: 120. Vazio = sem',
                  ),
                  validator: (v) => Validators.inteiro(
                    v,
                    campo: 'O descanso',
                    min: 1,
                    max: 3600,
                    obrigatorio: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _obsCtrl,
            minLines: 4,
            maxLines: 8,
            maxLength: 600,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17),
            decoration: _decoracao(
              'Orientações para o aluno (opcional)',
              ajuda: 'Como fazer o exercício e para que ele serve. '
                  'O aluno lê isso na tela do exercício.',
            ),
            validator: (v) => Validators.tamanhoMaximo(v, 600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _salvar,
            child: Text(_editando ? 'Salvar alterações' : 'Adicionar ao treino'),
          ),
        ],
      ),
    );
  }
}
