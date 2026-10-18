import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mensagens.dart';
import '../../../core/rotas.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/logo_academia.dart';
import '../data/academias_publicas_repository.dart';
import '../domain/academia_publica.dart';
import 'entrada_state.dart';

/// Tela de escolha da academia (aparece antes do login).
class EscolhaAcademiaPage extends ConsumerStatefulWidget {
  const EscolhaAcademiaPage({super.key});

  @override
  ConsumerState<EscolhaAcademiaPage> createState() =>
      _EscolhaAcademiaPageState();
}

class _EscolhaAcademiaPageState extends ConsumerState<EscolhaAcademiaPage> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _escolher(AcademiaPublica academia) {
    ref.read(entradaProvider.notifier).escolherAcademia(academia);
    context.go(Rotas.login);
  }

  void _souAdmin() {
    ref.read(entradaProvider.notifier).entrarComoAdmin();
    context.go(Rotas.login);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lista = ref.watch(academiasPublicasProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          size: 36,
                          color: tema.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Escolha a sua academia',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toque na academia onde você treina para entrar.',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: lista.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErroView(
                      mensagem: mensagemDeErro(e),
                      onTentarNovamente: () =>
                          ref.invalidate(academiasPublicasProvider),
                    ),
                    data: (academias) {
                      if (academias.isEmpty) {
                        return const EstadoVazio(
                          icone: Icons.storefront_outlined,
                          titulo: 'Nenhuma academia disponível',
                          mensagem:
                              'Peça ao responsável pela sua academia para '
                              'cadastrá-la no app.',
                        );
                      }
                      final termo = _busca.trim().toLowerCase();
                      final filtradas = termo.isEmpty
                          ? academias
                          : academias
                              .where((a) => a.nome.toLowerCase().contains(termo))
                              .toList();
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(academiasPublicasProvider);
                          await ref.read(academiasPublicasProvider.future);
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            if (academias.length > 6) ...[
                              TextField(
                                controller: _buscaCtrl,
                                onChanged: (v) => setState(() => _busca = v),
                                decoration: const InputDecoration(
                                  hintText: 'Buscar academia',
                                  prefixIcon: Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (filtradas.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhuma academia com esse nome.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            for (final a in filtradas)
                              Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  minVerticalPadding: 14,
                                  leading: LogoAcademia(
                                    nome: a.nome,
                                    logoPath: a.logoPath,
                                  ),
                                  title: Text(
                                    a.nome,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _escolher(a),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton(
                    onPressed: _souAdmin,
                    child: const Text('Sou administrador'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
