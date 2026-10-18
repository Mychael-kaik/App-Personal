import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/logo_academia.dart';
import '../../admin/data/filtro_alunos.dart';
import '../data/painel_admin_repository.dart';
import '../domain/painel_admin.dart';

enum _Visao { academias, professores }

/// Aba "Painel" (só o administrador geral): números do app inteiro.
/// [onAbrirAlunos] troca para a aba "Alunos" (os filtros já foram definidos).
class PainelAdminTab extends ConsumerStatefulWidget {
  const PainelAdminTab({super.key, required this.onAbrirAlunos});

  final VoidCallback onAbrirAlunos;

  @override
  ConsumerState<PainelAdminTab> createState() => _PainelAdminTabState();
}

class _PainelAdminTabState extends ConsumerState<PainelAdminTab> {
  _Visao _visao = _Visao.academias;
  int _dias = 7;

  Future<void> _atualizar() async {
    atualizarPainelAdmin(ref);
    try {
      await ref.read(painelGeralProvider.future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  void _abrirAlunos({String? academiaId, String? professorId}) {
    ref
        .read(filtroAlunosProvider.notifier)
        .abrir(academiaId: academiaId, professorId: professorId);
    widget.onAbrirAlunos();
  }

  @override
  Widget build(BuildContext context) {
    final geral = ref.watch(painelGeralProvider);

    return geral.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => atualizarPainelAdmin(ref),
      ),
      data: (g) => RefreshIndicator(
        onRefresh: _atualizar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _titulo(context, 'Visão geral'),
                _Indicadores(
                  geral: g,
                  onSemProfessor: () => _abrirAlunos(professorId: ''),
                ),
                const SizedBox(height: 24),
                _titulo(context, 'Por academia e por professor'),
                SegmentedButton<_Visao>(
                  segments: const [
                    ButtonSegment(
                      value: _Visao.academias,
                      icon: Icon(Icons.business_outlined),
                      label: Text('Academias'),
                    ),
                    ButtonSegment(
                      value: _Visao.professores,
                      icon: Icon(Icons.badge_outlined),
                      label: Text('Professores'),
                    ),
                  ],
                  selected: {_visao},
                  onSelectionChanged: (s) => setState(() => _visao = s.first),
                ),
                const SizedBox(height: 12),
                if (_visao == _Visao.academias)
                  _ListaAcademias(
                    onAbrir: (a) => _abrirAlunos(academiaId: a.id),
                  )
                else
                  _ListaProfessores(
                    onAbrir: (p) => _abrirAlunos(professorId: p.id),
                  ),
                const SizedBox(height: 24),
                _titulo(context, 'Alunos parados'),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 dias')),
                    ButtonSegment(value: 14, label: Text('14 dias')),
                    ButtonSegment(value: 30, label: Text('30 dias')),
                  ],
                  selected: {_dias},
                  onSelectionChanged: (s) => setState(() => _dias = s.first),
                ),
                const SizedBox(height: 12),
                _ListaParados(dias: _dias),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          texto,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );
}

// ---------------------------------------------------------------------------
// Cartões de números
// ---------------------------------------------------------------------------
class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.geral, required this.onSemProfessor});

  final PainelGeral geral;
  final VoidCallback onSemProfessor;

  @override
  Widget build(BuildContext context) {
    final g = geral;
    return LayoutBuilder(
      builder: (context, c) {
        final largura = (c.maxWidth - 12) / 2;
        Widget cartao(_Indicador i) => SizedBox(width: largura, child: i);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            cartao(_Indicador(
              icone: Icons.business_outlined,
              valor: '${g.academiasAtivas}',
              rotulo: 'Academias ativas',
              detalhe: 'de ${g.academiasTotal} cadastradas',
            )),
            cartao(_Indicador(
              icone: Icons.badge_outlined,
              valor: '${g.professoresAtivos}',
              rotulo: 'Professores ativos',
              detalhe: 'de ${g.professoresTotal} cadastrados',
            )),
            cartao(_Indicador(
              icone: Icons.people_outline,
              valor: '${g.alunosAtivos}',
              rotulo: 'Alunos ativos',
              detalhe: 'de ${g.alunosTotal} cadastrados',
            )),
            cartao(_Indicador(
              icone: Icons.today_outlined,
              valor: '${g.treinaramHoje}',
              rotulo: 'Treinaram hoje',
              detalhe: 'de ${g.alunosAtivos} alunos ativos',
            )),
            cartao(_Indicador(
              icone: Icons.date_range_outlined,
              valor: '${g.treinaram7d}',
              rotulo: 'Treinaram em 7 dias',
              detalhe: 'de ${g.alunosAtivos} alunos ativos',
            )),
            cartao(_Indicador(
              icone: Icons.person_off_outlined,
              valor: '${g.alunosSemProfessor}',
              rotulo: 'Alunos sem professor',
              detalhe: g.alunosSemProfessor == 0
                  ? 'tudo certo'
                  : 'toque para ver e mover',
              alerta: g.alunosSemProfessor > 0,
              onTap: g.alunosSemProfessor > 0 ? onSemProfessor : null,
            )),
          ],
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.icone,
    required this.valor,
    required this.rotulo,
    required this.detalhe,
    this.alerta = false,
    this.onTap,
  });

  final IconData icone;
  final String valor;
  final String rotulo;
  final String detalhe;
  final bool alerta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: alerta ? cores.errorContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icone,
                color: alerta ? cores.onErrorContainer : cores.primary,
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: alerta ? cores.onErrorContainer : null,
                ),
              ),
              Text(
                rotulo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                detalhe,
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Por academia
// ---------------------------------------------------------------------------
class _ListaAcademias extends ConsumerWidget {
  const _ListaAcademias({required this.onAbrir});

  final void Function(ResumoAcademia) onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(painelAcademiasProvider);
    return lista.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErroView(
        mensagem: mensagemDeErro(e),
        onTentarNovamente: () => ref.invalidate(painelAcademiasProvider),
      ),
      data: (academias) {
        if (academias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhuma academia cadastrada ainda. Use a aba "Equipe".'),
          );
        }
        return Column(
          children: [
            for (final a in academias)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onAbrir(a),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LogoAcademia(
                              nome: a.nome,
                              logoPath: a.logoPath,
                              tamanho: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                a.nome,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!a.ativo) const Chip(label: Text('Suspensa')),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${a.professoresAtivos} ${a.professoresAtivos == 1 ? 'professor' : 'professores'}'
                          ' · ${a.alunosAtivos} ${a.alunosAtivos == 1 ? 'aluno' : 'alunos'}',
                        ),
                        const SizedBox(height: 8),
                        _BarraDeFrequencia(
                          treinaram: a.treinaram7d,
                          total: a.alunosAtivos,
                          hoje: a.treinaramHoje,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BarraDeFrequencia extends StatelessWidget {
  const _BarraDeFrequencia({
    required this.treinaram,
    required this.total,
    required this.hoje,
  });

  final int treinaram;
  final int total;
  final int hoje;

  @override
  Widget build(BuildContext context) {
    final fracao = total == 0 ? 0.0 : (treinaram / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: fracao, minHeight: 8),
        ),
        const SizedBox(height: 4),
        Text(
          'Treinaram em 7 dias: $treinaram de $total · hoje: $hoje',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Por professor
// ---------------------------------------------------------------------------
class _ListaProfessores extends ConsumerWidget {
  const _ListaProfessores({required this.onAbrir});

  final void Function(ResumoProfessor) onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(painelProfessoresProvider);
    return lista.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErroView(
        mensagem: mensagemDeErro(e),
        onTentarNovamente: () => ref.invalidate(painelProfessoresProvider),
      ),
      data: (professores) {
        if (professores.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum professor cadastrado ainda. Use a aba "Equipe".'),
          );
        }
        return Column(
          children: [
            for (final p in professores)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onAbrir(p),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(child: Text(inicial(p.nome))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nome,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(p.academiaNome ?? 'Sem academia'),
                                ],
                              ),
                            ),
                            if (!p.ativo) const Chip(label: Text('Desativado')),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${p.alunosAtivos} ${p.alunosAtivos == 1 ? 'aluno ativo' : 'alunos ativos'}',
                        ),
                        const SizedBox(height: 8),
                        _BarraDeFrequencia(
                          treinaram: p.treinaram7d,
                          total: p.alunosAtivos,
                          hoje: p.treinaramHoje,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Alunos parados
// ---------------------------------------------------------------------------
class _ListaParados extends ConsumerWidget {
  const _ListaParados({required this.dias});

  final int dias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(alunosParadosProvider(dias));
    return lista.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErroView(
        mensagem: mensagemDeErro(e),
        onTentarNovamente: () => ref.invalidate(alunosParadosProvider(dias)),
      ),
      data: (alunos) {
        if (alunos.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ninguém está parado há $dias dias ou mais.'),
            ),
          );
        }
        return Column(
          children: [
            for (final a in alunos)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Text(inicial(a.nome))),
                  title: Text(
                    a.nome,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      a.professorNome ?? 'sem professor',
                      if (a.academiaNome != null) a.academiaNome!,
                    ].join(' · ') +
                        '\n' +
                        (a.nuncaTreinou
                            ? 'Nunca treinou (cadastrado há ${a.diasParado} dias)'
                            : 'Último treino há ${a.diasParado} dias'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Rotas.alunoDetalhe(a.id)),
                ),
              ),
            if (alunos.length >= 100)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Mostrando os 100 mais parados.'),
              ),
          ],
        );
      },
    );
  }
}
