import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dia_semana.dart';
import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/progress_repository.dart';
import '../domain/registro_treino.dart';

const List<String> _nomesDosMeses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Histórico e progresso: calendário do mês com os dias treinados e a lista
/// dos exercícios concluídos no dia escolhido.
///
/// Usada pelo ALUNO (alunoId == null: mostra o próprio histórico) e pelo
/// ADMIN (alunoId do aluno que ele está acompanhando).
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key, this.alunoId, this.titulo});

  final String? alunoId;
  final String? titulo;

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  late DateTime _mes; // sempre dia 1 do mês mostrado
  int? _diaEscolhido; // dia do mês (1..31)

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month, 1);
  }

  bool get _ehMesAtual {
    final agora = DateTime.now();
    return _mes.year == agora.year && _mes.month == agora.month;
  }

  void _mudarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta, 1);
      _diaEscolhido = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alunoId = widget.alunoId ?? ref.watch(currentProfileProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo ?? 'Meu progresso')),
      body: alunoId == null
          ? const ErroView(mensagem: 'Sua sessão expirou. Entre novamente.')
          : _corpo(alunoId),
    );
  }

  Widget _corpo(String alunoId) {
    final chave = MesDoAluno(alunoId, _mes.year, _mes.month);
    final dados = ref.watch(progressoDoMesProvider(chave));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(progressoDoMesProvider(chave));
            try {
              await ref.read(progressoDoMesProvider(chave).future);
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _CabecalhoDoMes(
                titulo: '${_nomesDosMeses[_mes.month - 1]} de ${_mes.year}',
                onAnterior: () => _mudarMes(-1),
                onProximo: _ehMesAtual ? null : () => _mudarMes(1),
              ),
              const SizedBox(height: 8),
              dados.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (erro, _) => SizedBox(
                  height: 260,
                  child: ErroView(
                    mensagem: mensagemDeErro(erro),
                    onTentarNovamente: () =>
                        ref.invalidate(progressoDoMesProvider(chave)),
                  ),
                ),
                data: _conteudo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo(List<RegistroTreino> registros) {
    final tema = Theme.of(context);
    final hoje = DateTime.now();

    // Agrupa por dia do mês: {13: [exercício, exercício...]}
    final porDia = <int, List<RegistroTreino>>{};
    for (final r in registros) {
      porDia.putIfAbsent(r.data.day, () => []).add(r);
    }

    // Sem escolha do aluno: no mês atual abre em "hoje".
    final escolhido = _diaEscolhido ?? (_ehMesAtual ? hoje.day : null);
    final doDia = escolhido == null ? null : porDia[escolhido];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Resumo(
                valor: '${porDia.length}',
                rotulo: porDia.length == 1 ? 'dia treinado' : 'dias treinados',
                icone: Icons.event_available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Resumo(
                valor: '${registros.length}',
                rotulo: registros.length == 1
                    ? 'exercício concluído'
                    : 'exercícios concluídos',
                icone: Icons.fitness_center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Calendario(
          mes: _mes,
          diasTreinados: porDia.keys.toSet(),
          escolhido: escolhido,
          onEscolher: (d) => setState(() => _diaEscolhido = d),
        ),
        const SizedBox(height: 16),
        if (escolhido == null)
          Text(
            'Toque num dia marcado para ver o que foi feito.',
            style: tema.textTheme.bodyMedium,
          )
        else ...[
          Text(
            formatarDataLonga(DateTime(_mes.year, _mes.month, escolhido)),
            style: tema.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (doDia == null || doDia.isEmpty)
            Text(
              'Nenhum exercício concluído neste dia.',
              style: tema.textTheme.bodyLarge,
            )
          else
            for (final r in doDia) _LinhaDoDia(registro: r),
        ],
      ],
    );
  }
}

class _CabecalhoDoMes extends StatelessWidget {
  const _CabecalhoDoMes({
    required this.titulo,
    required this.onAnterior,
    required this.onProximo,
  });

  final String titulo;
  final VoidCallback onAnterior;
  final VoidCallback? onProximo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: onProximo,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.valor,
    required this.rotulo,
    required this.icone,
  });

  final String valor;
  final String rotulo;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icone, color: cores.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cores.onPrimaryContainer,
                  ),
                ),
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 13,
                    color: cores.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendário do mês (semana de segunda a domingo). Dia treinado = bolinha
/// preenchida; hoje = contorno; dia escolhido = contorno grosso.
class _Calendario extends StatelessWidget {
  const _Calendario({
    required this.mes,
    required this.diasTreinados,
    required this.escolhido,
    required this.onEscolher,
  });

  final DateTime mes;
  final Set<int> diasTreinados;
  final int? escolhido;
  final ValueChanged<int> onEscolher;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final diasNoMes = DateTime(mes.year, mes.month + 1, 0).day;
    // weekday: segunda = 1 ... domingo = 7. Semana começando na segunda.
    final vazios = mes.weekday - 1;

    final celulas = <Widget>[
      for (final d in ordemDaSemana)
        Center(
          child: Text(
            nomeCurtoDoDia(d),
            style: TextStyle(fontSize: 13, color: cores.onSurfaceVariant),
          ),
        ),
      for (var i = 0; i < vazios; i++) const SizedBox.shrink(),
      for (var dia = 1; dia <= diasNoMes; dia++)
        _celula(context, dia, agora),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: celulas,
        ),
      ),
    );
  }

  Widget _celula(BuildContext context, int dia, DateTime agora) {
    final cores = Theme.of(context).colorScheme;
    final treinou = diasTreinados.contains(dia);
    final ehHoje =
        mes.year == agora.year && mes.month == agora.month && dia == agora.day;
    final selecionado = dia == escolhido;

    return Semantics(
      button: true,
      label: 'Dia $dia${treinou ? ', treinou' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onEscolher(dia),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: treinou ? cores.primary : null,
            border: selecionado
                ? Border.all(color: cores.tertiary, width: 3)
                : ehHoje
                    ? Border.all(color: cores.primary, width: 1.5)
                    : null,
          ),
          child: Text(
            '$dia',
            style: TextStyle(
              fontSize: 15,
              fontWeight: treinou ? FontWeight.w800 : FontWeight.w400,
              color: treinou ? cores.onPrimary : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinhaDoDia extends StatelessWidget {
  const _LinhaDoDia({required this.registro});

  final RegistroTreino registro;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final partes = <String>[
      registro.repeticoes != null
          ? '${registro.series} x ${registro.repeticoes}'
          : (registro.series == 1 ? '1 série' : '${registro.series} séries'),
      if (registro.carga != null) formatarCarga(registro.carga!),
      if ((registro.tituloTreino ?? '').isNotEmpty) registro.tituloTreino!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.check_circle, color: tema.colorScheme.primary),
        title: Text(
          registro.exercicio,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(partes.join(' · ')),
      ),
    );
  }
}
