import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'estilos.dart';

/// Transforma QUALQUER erro em uma frase amigável em português.
/// As telas nunca mostram erro técnico para o usuário.
String mensagemDeErro(Object erro) {
  if (erro is AppException) return erro.message;

  if (erro is PostgrestException) {
    switch (erro.code) {
      case 'P0001':
        // Erro lançado de propósito pelas nossas funções SQL
        // (raise exception '...'): a mensagem já está em português.
        return erro.message;
      case '42501':
        return 'Você não tem permissão para fazer isso.';
      case '23505':
        return 'Já existe um registro com esses dados.';
      case '23503':
        return 'Este item está ligado a outros dados e não pode ser removido.';
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  if (erro is FunctionException) {
    final detalhes = erro.details;
    if (detalhes is Map && detalhes['error'] is String) {
      return detalhes['error'] as String;
    }
    if (erro.status == 404) {
      return 'Esta função ainda não foi publicada no Supabase (Edge Functions).';
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  if (erro is StorageException) {
    if ('${erro.statusCode}' == '413') {
      return 'A foto é grande demais (máximo 2 MB).';
    }
    if ('${erro.statusCode}' == '403' || '${erro.statusCode}' == '401') {
      return 'Você não tem permissão para enviar fotos.';
    }
    return 'Não foi possível enviar a foto. Tente novamente.';
  }

  if (erro is AuthException) {
    return 'Sua sessão expirou. Entre novamente.';
  }

  return 'Algo deu errado. Verifique sua conexão e tente novamente.';
}

/// Aviso rápido na parte de baixo da tela.
void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  final cores = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        backgroundColor: erro ? cores.error : null,
      ),
    );
}

/// Pergunta "tem certeza?" antes de uma ação importante.
/// Devolve true se o usuário confirmou.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String textoConfirmar = 'Confirmar',
  bool perigo = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cores = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: perigo
                ? compactoPreenchido().copyWith(
                    backgroundColor: WidgetStatePropertyAll(cores.error),
                    foregroundColor: WidgetStatePropertyAll(cores.onError),
                  )
                : compactoPreenchido(),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  );
  return resultado ?? false;
}
