import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dia_semana.dart';
import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../admin/domain/workout.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/student_providers.dart';
import 'workout_item_tile.dart';

/// Tela inicial do aluno: o treino de HOJE, com marcação de concluídos,
/// e botões para ver os treinos dos outros dias da semana.
class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage>
    with WidgetsBindingObserver {
  /// Dia que o aluno escolheu olhar. null = "hoje" (acompanha o calendário:
  /// se o app ficar aberto até depois da meia-noite, passa para o novo dia).
  int? _escolhido;

  int get _dia => _escolhido ?? diaDeHoje();

  @override
  void initState() {
    super.initState();
    // Para saber quando o app volta do segundo plano.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ao voltar para o app (ex.: abriu de novo no dia seguinte), busca tudo
  /// de novo, para nunca mostrar o treino ou as marcações de ontem.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _recarregar();
  }

  void _recarregar() {
    ref.invalidate(meusTreinosProvider);
    ref.invalidate(conclusoesDeHojeProvider);
  }

  Future<void> _puxarParaAtualizar() async {
    _recarregar();
    try {
      await Future.wait([
        ref.read(meusTreinosProvider.future),
        ref.read(conclusoesDeHojeProvider.future),
      ]);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  Future<void> _sair() async {
    final sair = await confirmar(
      context,
      titulo: 'Sair do app?',
      mensagem: 'Você precisará entrar de novo com e-mail e senha.',
      textoConfirmar: 'Sair',
    );
    if (!sair || !mounted) return;
    await ref.read(authControllerProvider.notifier).sair();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final perfil = ref.watch(currentProfileProvider);
    final treinos = ref.watch(meusTreinosProvider);

    final hoje = diaDeHoje();
    final dia = _dia;
    final nome = primeiroNome(perfil?.nome ?? '');
    final diasComTreino = treinos.value?.map((t) => t.dia).toSet() ?? <int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu treino'),
        actions: [
          IconButton(
            tooltip: 'Meu progresso',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => context.push(Rotas.progresso),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _sair,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: _puxarParaAtualizar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  nome.isEmpty ? 'Olá!' : 'Olá, $nome!',
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatarDataLonga(DateTime.now()),
                  style: tema.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _SeletorDeDias(
                  selecionado: dia,
                  hoje: hoje,
                  diasComTreino: diasComTreino,
                  onSelecionar: (d) =>
                      setState(() => _escolhido = d == hoje ? null : d),
                ),
                const SizedBox(height: 16),
                treinos.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (erro, _) => SizedBox(
                    height: 240,
                    child: ErroView(
                      mensagem: mensagemDeErro(erro),
                      onTentarNovamente: _recarregar,
                    ),
                  ),
                  data: (lista) =>
                      _TreinoDoDia(lista: lista, dia: dia, ehHoje: dia == hoje),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Os 7 botões "Seg, Ter, Qua...". O de hoje tem um ícone de calendário e
/// os dias que têm treino aparecem em negrito.
class _SeletorDeDias extends StatelessWidget {
  const _SeletorDeDias({
    required this.selecionado,
    required this.hoje,
    required this.diasComTreino,
    required this.onSelecionar,
  });

  final int selecionado;
  final int hoje;
  final Set<int> diasComTreino;
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final d in ordemDaSemana)
          ChoiceChip(
            showCheckmark: false,
            avatar: d == hoje ? const Icon(Icons.today, size: 18) : null,
            label: Text(
              nomeCurtoDoDia(d),
              style: TextStyle(
                fontSize: 15,
                fontWeight: diasComTreino.contains(d)
                    ? FontWeight.w800
                    : FontWeight.w400,
              ),
            ),
            selected: d == selecionado,
            onSelected: (_) => onSelecionar(d),
          ),
      ],
    );
  }
}

/// O conteúdo do dia escolhido: o treino, ou uma mensagem amigável.
class _TreinoDoDia extends ConsumerWidget {
  const _TreinoDoDia({
    required this.lista,
    required this.dia,
    required this.ehHoje,
  });

  final List<Workout> lista;
  final int dia;
  final bool ehHoje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final treino = lista.where((t) => t.dia == dia).firstOrNull;

    // ---- Sem treino neste dia: mensagens amigáveis ----
    if (treino == null) {
      if (lista.isEmpty) {
        return const EstadoVazio(
          icone: Icons.hourglass_empty,
          titulo: 'Seu treino ainda não está pronto',
          mensagem:
              'Seu personal ainda não montou os seus treinos. Assim que ele '
              'montar, eles aparecem aqui.',
        );
      }
      if (ehHoje) {
        return const EstadoVazio(
          icone: Icons.self_improvement,
          titulo: 'Hoje é dia de descanso',
          mensagem:
              'Seu personal não passou treino para hoje. Aproveite para '
              'recuperar as energias!',
        );
      }
      return EstadoVazio(
        icone: Icons.event_busy,
        titulo: 'Sem treino neste dia',
        mensagem: 'Nada programado para ${nomeDoDia(dia).toLowerCase()}.',
      );
    }

    if (treino.itens.isEmpty) {
      return const EstadoVazio(
        icone: Icons.hourglass_empty,
        titulo: 'Treino sem exercícios',
        mensagem:
            'Este treino ainda não tem exercícios. Fale com o seu personal.',
      );
    }

    // ---- Com treino ----
    final conclusoes = ref.watch(conclusoesDeHojeProvider);
    final concluidos = conclusoes.value ?? <String>{};
    final total = treino.itens.length;
    final feitos = treino.itens.where((i) => concluidos.contains(i.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: cores.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treino.titulo,
                            style: tema.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$total ${total == 1 ? 'exercício' : 'exercícios'}'
                            ' · ${nomeDoDia(dia)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (ehHoje) ...[
                  const SizedBox(height: 16),
                  Text(
                    '$feitos de $total concluídos',
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: feitos / total,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (ehHoje && feitos == total)
          _Aviso(
            icone: Icons.emoji_events,
            texto: 'Treino concluído! Parabéns, bom trabalho hoje!',
            fundo: cores.primaryContainer,
            corDoTexto: cores.onPrimaryContainer,
          ),
        if (!ehHoje)
          _Aviso(
            icone: Icons.info_outline,
            texto:
                'Este é o treino de outro dia. Toque num exercício para ver '
                'os detalhes. Você conclui no próprio dia do treino.',
            fundo: cores.secondaryContainer,
            corDoTexto: cores.onSecondaryContainer,
          ),
        if (ehHoje && feitos < total)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              'Toque em um exercício para ver como fazer e concluir.',
              style: tema.textTheme.bodyMedium,
            ),
          ),
        if (ehHoje && conclusoes.hasError)
          _Aviso(
            icone: Icons.error_outline,
            texto: 'Não foi possível carregar as suas marcações.',
            fundo: cores.errorContainer,
            corDoTexto: cores.onErrorContainer,
            acao: TextButton(
              onPressed: () => ref.invalidate(conclusoesDeHojeProvider),
              child: const Text('Tentar de novo'),
            ),
          ),
        for (var i = 0; i < treino.itens.length; i++)
          WorkoutItemTile(
            posicao: i + 1,
            item: treino.itens[i],
            concluido: concluidos.contains(treino.itens[i].id),
            ehHoje: ehHoje,
            onAbrir: () => context.push(Rotas.exercicio(treino.itens[i].id!)),
          ),
      ],
    );
  }
}

/// Faixa colorida com um ícone e uma frase (aviso, erro ou parabéns).
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.texto,
    required this.fundo,
    required this.corDoTexto,
    this.acao,
  });

  final IconData icone;
  final String texto;
  final Color fundo;
  final Color corDoTexto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, color: corDoTexto),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 15, color: corDoTexto),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}
