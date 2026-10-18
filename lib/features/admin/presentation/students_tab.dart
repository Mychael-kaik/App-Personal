import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_providers.dart';
import '../data/filtro_alunos.dart';

/// Aba "Alunos": lista com busca e filtros. Tocar em um aluno abre o treino dele.
/// Professor: vê só os próprios alunos (o banco já filtra) e filtra por situação.
/// Administrador geral: vê todos e filtra por academia, professor e situação.
class StudentsTab extends ConsumerStatefulWidget {
  const StudentsTab({super.key});

  @override
  ConsumerState<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<StudentsTab> {
  final _buscaCtrl = TextEditingController();

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizar() async {
    ref.invalidate(alunosProvider);
    try {
      await ref.read(alunosProvider.future);
    } catch (_) {
      // O erro aparece na própria tela (ErroView); aqui só terminamos o "puxar".
    }
  }

  @override
  Widget build(BuildContext context) {
    // Quando o Painel define filtros (ou limpa), o campo de busca acompanha.
    ref.listen(filtroAlunosProvider, (antes, depois) {
      if (_buscaCtrl.text != depois.busca) _buscaCtrl.text = depois.busca;
    });

    final filtro = ref.watch(filtroAlunosProvider);
    final alunos = ref.watch(alunosProvider);
    final ehAdmin = ref.watch(currentProfileProvider)?.isAdmin ?? false;
    final professores =
        ehAdmin ? (ref.watch(professoresProvider).value ?? const []) : const [];
    final academias =
        ehAdmin ? (ref.watch(academiasProvider).value ?? const []) : const [];

    String? nomeDoProfessor(String? id) {
      if (id == null) return null;
      for (final p in professores) {
        if (p.id == id) return p.nome;
      }
      return null;
    }

    String? nomeDaAcademia(String? id) {
      if (id == null) return null;
      for (final a in academias) {
        if (a.id == id) return a.nome;
      }
      return null;
    }

    // Só mostra professores da academia escolhida (se houver uma).
    final professoresDoFiltro = filtro.academiaId == null
        ? professores
        : professores.where((p) => p.academiaId == filtro.academiaId).toList();

    return alunos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => ErroView(
        mensagem: mensagemDeErro(erro),
        onTentarNovamente: () => ref.invalidate(alunosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const EstadoVazio(
            icone: Icons.group_add_outlined,
            titulo: 'Nenhum aluno ainda',
            mensagem: 'Toque em "Novo aluno" para cadastrar o primeiro.',
          );
        }

        final termo = filtro.busca.trim().toLowerCase();
        final filtrados = lista.where((a) {
          if (filtro.status == StatusAluno.ativos && !a.ativo) return false;
          if (filtro.status == StatusAluno.inativos && a.ativo) return false;
          if (ehAdmin) {
            if (filtro.academiaId != null &&
                a.academiaId != filtro.academiaId) {
              return false;
            }
            if (filtro.professorId != null) {
              final doFiltro = filtro.professorId == ''
                  ? a.professorId == null
                  : a.professorId == filtro.professorId;
              if (!doFiltro) return false;
            }
          }
          if (termo.isEmpty) return true;
          return a.nome.toLowerCase().contains(termo) ||
              (a.email ?? '').toLowerCase().contains(termo);
        }).toList();

        final notifier = ref.read(filtroAlunosProvider.notifier);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _buscaCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar aluno por nome ou e-mail',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: filtro.busca.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _buscaCtrl.clear();
                            notifier.definirBusca('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: notifier.definirBusca,
              ),
            ),
            if (ehAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _FiltroLista(
                        rotulo: 'Academia',
                        valor: filtro.academiaId,
                        opcoes: [
                          const (null, 'Todas'),
                          for (final a in academias) (a.id, a.nome),
                        ],
                        onChanged: notifier.definirAcademia,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FiltroLista(
                        rotulo: 'Professor',
                        valor: filtro.professorId,
                        opcoes: [
                          const (null, 'Todos'),
                          const ('', 'Sem professor'),
                          for (final p in professoresDoFiltro) (p.id, p.nome),
                        ],
                        onChanged: notifier.definirProfessor,
                      ),
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (final (s, rotulo) in const [
                    (StatusAluno.todos, 'Todos'),
                    (StatusAluno.ativos, 'Ativos'),
                    (StatusAluno.inativos, 'Inativos'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(rotulo),
                        selected: filtro.status == s,
                        onSelected: (_) => notifier.definirStatus(s),
                      ),
                    ),
                  if (filtro.temFiltro)
                    TextButton.icon(
                      onPressed: () {
                        _buscaCtrl.clear();
                        notifier.limpar();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpar filtros'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtrados.length} de ${lista.length} '
                  '${lista.length == 1 ? 'aluno' : 'alunos'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _atualizar,
                child: filtrados.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Nenhum aluno encontrado.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        // O espaço extra embaixo evita que o botão
                        // "Novo aluno" cubra o último item da lista.
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final aluno = filtrados[i];
                          final academia = nomeDaAcademia(aluno.academiaId);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 8, 12, 8),
                              leading: CircleAvatar(
                                radius: 24,
                                child: Text(inicial(aluno.nome)),
                              ),
                              title: Text(
                                aluno.nome,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                ehAdmin
                                    ? '${aluno.email ?? ''}\n'
                                        'Professor: ${nomeDoProfessor(aluno.professorId) ?? 'sem professor'}'
                                        '${academia == null ? '' : ' · $academia'}'
                                    : (aluno.email ?? ''),
                              ),
                              isThreeLine: ehAdmin,
                              trailing: aluno.ativo
                                  ? const Icon(Icons.chevron_right)
                                  : const Chip(label: Text('Inativo')),
                              onTap: () =>
                                  context.push(Rotas.alunoDetalhe(aluno.id)),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Caixa de seleção de um filtro. [opcoes] = (valor, texto); o valor pode ser null.
class _FiltroLista extends StatelessWidget {
  const _FiltroLista({
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
  });

  final String rotulo;
  final String? valor;
  final List<(String?, String)> opcoes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Se o valor escolhido não está mais nas opções (ex.: professor de outra
    // academia), mostramos a primeira opção para não dar erro.
    final existe = opcoes.any((o) => o.$1 == valor);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: existe ? valor : opcoes.first.$1,
          items: [
            for (final (v, texto) in opcoes)
              DropdownMenuItem<String?>(
                value: v,
                child: Text(texto, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
