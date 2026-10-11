import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../data/admin_providers.dart';

/// Aba "Alunos": lista com busca. Tocar em um aluno abre o treino dele.
class StudentsTab extends ConsumerStatefulWidget {
  const StudentsTab({super.key});

  @override
  ConsumerState<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<StudentsTab> {
  String _busca = '';

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
    final alunos = ref.watch(alunosProvider);

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

        final termo = _busca.trim().toLowerCase();
        final filtrados = termo.isEmpty
            ? lista
            : lista
                .where((a) =>
                    a.nome.toLowerCase().contains(termo) ||
                    (a.email ?? '').toLowerCase().contains(termo))
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar aluno por nome ou e-mail',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (v) => setState(() => _busca = v),
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
                              subtitle: Text(aluno.email ?? ''),
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
