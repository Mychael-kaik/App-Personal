import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mensagens.dart';
import '../../../core/widgets/estados.dart';
import '../data/admin_providers.dart';
import '../domain/exercise.dart';

/// Biblioteca-modelo (professor): exercícios prontos do administrador geral.
/// Tocar em "Copiar" cria um exercício NOVO na biblioteca do professor
/// (com a foto, se tiver); depois ele pode editar a cópia à vontade.
class ModelosPage extends ConsumerStatefulWidget {
  const ModelosPage({super.key});

  @override
  ConsumerState<ModelosPage> createState() => _ModelosPageState();
}

class _ModelosPageState extends ConsumerState<ModelosPage> {
  String? _grupo; // null = todos
  final Set<String> _copiando = {};
  final Set<String> _copiados = {};

  Future<void> _atualizar() async {
    ref.invalidate(modelosProvider);
    try {
      await ref.read(modelosProvider.future);
    } catch (_) {
      // O erro aparece na própria tela.
    }
  }

  Future<void> _copiar(Exercise modelo) async {
    if (_copiando.contains(modelo.id)) return;

    // Já tem um exercício com esse nome? Pergunta antes de duplicar.
    final meus = ref.read(exerciciosProvider).value ?? const <Exercise>[];
    final nome = modelo.nome.trim().toLowerCase();
    final jaTem = meus.any(
      (e) => e.id != modelo.id && e.nome.trim().toLowerCase() == nome,
    );
    if (jaTem) {
      final ok = await confirmar(
        context,
        titulo: 'Já existe um exercício com esse nome',
        mensagem:
            'Você já tem "${modelo.nome}" na sua biblioteca. Copiar mesmo assim?',
        textoConfirmar: 'Copiar',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _copiando.add(modelo.id));
    try {
      await ref.read(adminRepositoryProvider).copiarModelo(modelo);
      ref.invalidate(exerciciosProvider);
      if (!mounted) return;
      setState(() => _copiados.add(modelo.id));
      mostrarMensagem(context, '"${modelo.nome}" foi para a sua biblioteca.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _copiando.remove(modelo.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelos = ref.watch(modelosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca-modelo')),
      body: modelos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => ErroView(
          mensagem: mensagemDeErro(erro),
          onTentarNovamente: () => ref.invalidate(modelosProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVazio(
              icone: Icons.collections_bookmark_outlined,
              titulo: 'Nenhum modelo ainda',
              mensagem:
                  'Quando o administrador geral cadastrar exercícios-modelo, '
                  'eles aparecem aqui para você copiar.',
            );
          }
          final grupos = lista.expand((e) => e.grupos).toSet().toList()..sort();
          final grupoAtivo = grupos.contains(_grupo) ? _grupo : null;
          final filtrados = grupoAtivo == null
              ? lista
              : lista.where((e) => e.grupos.contains(grupoAtivo)).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: grupoAtivo == null,
                      onSelected: (_) => setState(() => _grupo = null),
                    ),
                    for (final g in grupos)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: grupoAtivo == g,
                          onSelected: (_) => setState(() => _grupo = g),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _atualizar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) {
                      final e = filtrados[i];
                      final descricao = (e.descricao ?? '').trim();
                      final copiando = _copiando.contains(e.id);
                      final copiado = _copiados.contains(e.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          leading: Icon(
                            (e.fotoPath ?? '').isNotEmpty
                                ? Icons.image_outlined
                                : Icons.fitness_center,
                          ),
                          title: Text(
                            e.nome,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            descricao.isEmpty
                                ? e.grupoMuscular
                                : '${e.grupoMuscular} · $descricao',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: copiando
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: () => _copiar(e),
                                  icon: Icon(
                                    copiado ? Icons.check : Icons.copy_outlined,
                                  ),
                                  label: Text(copiado ? 'Copiado' : 'Copiar'),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
