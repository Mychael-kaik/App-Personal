import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/estilos.dart';

/// Cronômetro regressivo de descanso.
///
/// Guarda a HORA em que o descanso termina (e não "vai diminuindo 1 por
/// segundo"). Assim, se o celular travar a tela ou o app ficar em segundo
/// plano, o tempo continua certo quando o aluno voltar.
///
/// Use uma `key` diferente para cada descanso novo, para o cronômetro
/// recomeçar do zero.
class RestTimer extends StatefulWidget {
  const RestTimer({
    super.key,
    required this.segundos,
    required this.titulo,
    required this.onTerminou,
    this.onPular,
  });

  final int segundos;
  final String titulo;

  /// Chamado UMA vez, quando chega em 0 (sem o aluno pular).
  final VoidCallback onTerminou;

  /// Chamado quando o aluno toca em "Pular descanso". Se null, sem botão.
  final VoidCallback? onPular;

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late DateTime _fim;
  late int _total;
  Timer? _relogio;
  bool _acabou = false;

  @override
  void initState() {
    super.initState();
    _total = widget.segundos;
    _fim = DateTime.now().add(Duration(seconds: widget.segundos));
    _relogio = Timer.periodic(const Duration(milliseconds: 250), (_) => _tique());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  /// Segundos que faltam (arredondado para cima: 0,2 s ainda mostra 1).
  int get _faltam {
    final ms = _fim.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _tique() {
    if (!mounted) return;
    if (_faltam <= 0 && !_acabou) {
      _acabou = true;
      _relogio?.cancel();
      // Aviso de que acabou: vibra e toca (nos aparelhos que permitem).
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {});
      widget.onTerminou();
      return;
    }
    setState(() {});
  }

  void _maisTempo() {
    setState(() {
      _fim = _fim.add(const Duration(seconds: 15));
      _total += 15;
    });
  }

  String _relogioTexto(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final faltam = _faltam;
    final progresso = _total == 0 ? 0.0 : (faltam / _total).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: false,
      label: '${widget.titulo}: faltam ${_relogioTexto(faltam)}',
      child: Card(
        color: cores.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cores.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: CircularProgressIndicator(
                        value: progresso,
                        strokeWidth: 10,
                        backgroundColor: cores.surface,
                      ),
                    ),
                    Text(
                      _relogioTexto(faltam),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: cores.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_acabou)
                Text(
                  'Descanso terminado!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cores.onPrimaryContainer,
                  ),
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: compactoContorno(),
                      onPressed: _maisTempo,
                      icon: const Icon(Icons.add),
                      label: const Text('15 s'),
                    ),
                    if (widget.onPular != null)
                      FilledButton.icon(
                        style: compactoPreenchido(),
                        onPressed: widget.onPular,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Pular descanso'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
