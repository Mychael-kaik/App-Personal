import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dia_semana.dart';
import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/foto_exercicio.dart';
import '../../admin/domain/workout.dart';
import '../data/student_providers.dart';
import 'rest_timer.dart';

/// Qual descanso está rodando agora.
enum _TipoDescanso { entreSeries, aoFinal }

/// Tela de UM exercício: nome, séries, repetições, foto, orientações do
/// professor, botões para ir marcando as séries e o cronômetro de descanso.
class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  /// Séries já feitas nesta visita à tela (não é gravado no banco: só o
  /// "exercício concluído" é gravado).
  int _seriesFeitas = 0;

  _TipoDescanso? _descanso;
  int _descansoSegundos = 0;
  // Muda a cada descanso novo, para o cronômetro recomeçar.
  int _descansoNumero = 0;

  bool _gravando = false;

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Abriu direto pelo endereço (ex.: recarregou a página): sem tela anterior.
      context.go(Rotas.aluno);
    }
  }

  void _iniciarDescanso(_TipoDescanso tipo, int segundos) {
    setState(() {
      _descanso = tipo;
      _descansoSegundos = segundos;
      _descansoNumero++;
    });
  }

  void _terminarSerie(WorkoutItem item) {
    final feitas = _seriesFeitas + 1;
    setState(() => _seriesFeitas = feitas);
    // Última série: o exercício é concluído automaticamente (grava no banco
    // e começa o descanso final, se o professor configurou).
    if (feitas >= item.series) {
      _concluir(item);
      return;
    }
    // Depois da última série não tem descanso de série: o descanso final
    // começa quando o aluno tocar em "Exercício concluído".
    final segundos = item.descansoSerieSegundos ?? 0;
    if (feitas < item.series && segundos > 0) {
      _iniciarDescanso(_TipoDescanso.entreSeries, segundos);
    }
  }

  Future<void> _concluir(WorkoutItem item) async {
    if (_gravando) return;
    setState(() => _gravando = true);
    try {
      await ref
          .read(conclusoesDeHojeProvider.notifier)
          .alternar(item.id!, true);
      if (!mounted) return;
      setState(() {
        _gravando = false;
        _seriesFeitas = item.series;
      });
      final segundos = item.descansoSegundos ?? 0;
      if (segundos > 0) {
        _iniciarDescanso(_TipoDescanso.aoFinal, segundos);
      } else {
        mostrarMensagem(context, 'Exercício concluído! 💪');
        _voltar();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _gravando = false);
      mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  Future<void> _desmarcar(WorkoutItem item) async {
    if (_gravando) return;
    setState(() => _gravando = true);
    try {
      await ref
          .read(conclusoesDeHojeProvider.notifier)
          .alternar(item.id!, false);
      if (!mounted) return;
      setState(() {
        _gravando = false;
        _seriesFeitas = 0;
        _descanso = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gravando = false);
      mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final treinos = ref.watch(meusTreinosProvider);

    Widget moldura(Widget corpo) => Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _voltar),
            title: const Text('Exercício'),
          ),
          body: corpo,
        );

    return treinos.when(
      loading: () => moldura(const Center(child: CircularProgressIndicator())),
      error: (erro, _) => moldura(
        ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () => ref.invalidate(meusTreinosProvider),
        ),
      ),
      data: (lista) {
        Workout? treino;
        WorkoutItem? item;
        for (final t in lista) {
          for (final i in t.itens) {
            if (i.id == widget.itemId) {
              treino = t;
              item = i;
            }
          }
        }
        if (treino == null || item == null) {
          return moldura(
            const EstadoVazio(
              icone: Icons.search_off,
              titulo: 'Exercício não encontrado',
              mensagem: 'Ele pode ter sido removido do seu treino. '
                  'Volte e puxe a tela para atualizar.',
            ),
          );
        }
        return moldura(_conteudo(treino, item));
      },
    );
  }

  Widget _conteudo(Workout treino, WorkoutItem item) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;

    final ehHoje = treino.dia == diaDeHoje();
    final conclusoes = ref.watch(conclusoesDeHojeProvider);
    final concluido = conclusoes.value?.contains(item.id) ?? false;
    final podeMarcar = ehHoje && conclusoes.hasValue;

    final observacao = (item.observacao ?? '').trim();
    final descricao = (item.exercicioDescricao ?? '').trim();
    final temFoto = (item.fotoPath ?? '').isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    item.exerciseNome,
                    style: tema.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if ((item.grupoMuscular ?? '').isNotEmpty)
                    Text(item.grupoMuscular!, style: tema.textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  _Numeros(item: item),
                  const SizedBox(height: 16),
                  if (temFoto)
                    FotoExercicio(caminho: item.fotoPath!)
                  else
                    const SemFoto(),
                  const SizedBox(height: 16),
                  _Texto(
                    icone: Icons.record_voice_over_outlined,
                    titulo: 'Orientações do professor',
                    texto: observacao.isEmpty
                        ? 'Seu professor não deixou orientações para este exercício.'
                        : observacao,
                    apagado: observacao.isEmpty,
                  ),
                  if (descricao.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Texto(
                      icone: Icons.info_outline,
                      titulo: 'Sobre o exercício',
                      texto: descricao,
                    ),
                  ],
                  if (!ehHoje) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cores.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Este exercício é do treino de ${nomeDoDia(treino.dia).toLowerCase()}. '
                        'Você conclui os exercícios no próprio dia do treino.',
                        style: TextStyle(
                          fontSize: 15,
                          color: cores.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (podeMarcar || concluido)
              _AreaDeAcao(
                child: _acao(item, concluido: concluido, podeMarcar: podeMarcar),
              ),
          ],
        ),
      ),
    );
  }

  /// A parte de baixo da tela: muda conforme o momento do aluno.
  Widget _acao(
    WorkoutItem item, {
    required bool concluido,
    required bool podeMarcar,
  }) {
    final cores = Theme.of(context).colorScheme;

    // 1) Cronômetro de descanso rodando (ou recém-terminado).
    if (_descanso == _TipoDescanso.entreSeries) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RestTimer(
            key: ValueKey('descanso$_descansoNumero'),
            segundos: _descansoSegundos,
            titulo: 'Descanse. Próxima: série ${_seriesFeitas + 1} de ${item.series}',
            // Terminou: volta para os botões (o aviso sonoro/vibração já tocou).
            onTerminou: () {
              if (mounted) setState(() => _descanso = null);
            },
            onPular: () => setState(() => _descanso = null),
          ),
        ],
      );
    }
    if (_descanso == _TipoDescanso.aoFinal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RestTimer(
            key: ValueKey('descanso$_descansoNumero'),
            segundos: _descansoSegundos,
            titulo: 'Exercício concluído! Descanse antes do próximo',
            onTerminou: () {},
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _voltar,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para o treino'),
          ),
        ],
      );
    }

    // 2) Já concluído (e sem descanso na tela).
    if (concluido) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: cores.primary),
              const SizedBox(width: 8),
              const Text(
                'Exercício concluído',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _voltar,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para o treino'),
          ),
          if (podeMarcar)
            TextButton(
              onPressed: _gravando ? null : () => _desmarcar(item),
              child: const Text('Desmarcar como concluído'),
            ),
        ],
      );
    }

    // 3) Fazendo o exercício: séries + botão concluir.
    final faltamSeries = _seriesFeitas < item.series;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeriesFeitas(
          feitas: _seriesFeitas,
          total: item.series,
          repeticoes: item.repeticoes,
        ),
        const SizedBox(height: 10),
        if (faltamSeries) ...[
          OutlinedButton.icon(
            onPressed: _gravando ? null : () => _terminarSerie(item),
            icon: const Icon(Icons.done),
            label: Text(
              _seriesFeitas + 1 >= item.series
                  ? 'Terminei a última série'
                  : 'Terminei a série ${_seriesFeitas + 1}',
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _gravando ? null : () => _concluir(item),
          child: _gravando
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Text('Exercício concluído'),
        ),
      ],
    );
  }
}

/// Faixa fixa na parte de baixo da tela.
class _AreaDeAcao extends StatelessWidget {
  const _AreaDeAcao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cores.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

/// Os números do exercício em "etiquetas": séries, repetições, carga...
class _Numeros extends StatelessWidget {
  const _Numeros({required this.item});

  final WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    final etiquetas = <(String, String)>[
      ('Séries', '${item.series}'),
      if (item.repeticoes != null) ('Repetições', '${item.repeticoes}'),
      if (item.tempoSegundos != null && item.tempoSegundos! > 0)
        ('Duração', formatarTempo(item.tempoSegundos!)),
      if (item.carga != null) ('Carga', formatarCarga(item.carga!)),
      if ((item.descansoSerieSegundos ?? 0) > 0)
        ('Descanso entre séries', formatarTempo(item.descansoSerieSegundos!)),
      if ((item.descansoSegundos ?? 0) > 0)
        ('Descanso ao final', formatarTempo(item.descansoSegundos!)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (rotulo, valor) in etiquetas) _Etiqueta(rotulo, valor),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo,
            style: TextStyle(fontSize: 12, color: cores.onPrimaryContainer),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cores.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão com título e um texto corrido (orientações, descrição).
class _Texto extends StatelessWidget {
  const _Texto({
    required this.icone,
    required this.titulo,
    required this.texto,
    this.apagado = false,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: cores.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                fontStyle: apagado ? FontStyle.italic : FontStyle.normal,
                color: apagado ? cores.onSurfaceVariant : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bolinhas das séries: cheia = feita. "Série 2 de 4".
class _SeriesFeitas extends StatelessWidget {
  const _SeriesFeitas({
    required this.feitas,
    required this.total,
    this.repeticoes,
  });

  final int feitas;
  final int total;
  final int? repeticoes;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          [
            'Série ${feitas < total ? feitas + 1 : total} de $total',
            if (repeticoes != null) '$repeticoes repetições',
          ].join(' · '),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < total; i++)
              Icon(
                i < feitas ? Icons.circle : Icons.circle_outlined,
                size: 18,
                color: i < feitas ? cores.primary : cores.outline,
              ),
          ],
        ),
      ],
    );
  }
}
