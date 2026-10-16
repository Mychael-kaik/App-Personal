import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Se você ainda não colou a chave em lib/core/env.dart, mostramos um aviso
  // claro em vez de o app quebrar com um erro estranho.
  if (!Env.configurado) {
    runApp(const _ConfigPendenteApp());
    return;
  }

  // Liga o app ao seu projeto Supabase. A sessão de login fica salva no
  // aparelho, então o usuário não precisa logar toda vez que abre o app.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseKey,
  );

  // ProviderScope = "caixa" onde o Riverpod guarda o estado do app.
  //
  // retry: o Riverpod 3 tenta de novo, sozinho e várias vezes, quando uma
  // busca falha. Isso faria a tela ficar "carregando" por muitos segundos
  // antes de mostrar o erro. Aqui desligamos: o erro aparece na hora e o
  // usuário toca em "Tentar novamente" se quiser.
  runApp(
    ProviderScope(
      retry: (tentativa, erro) => null,
      child: const App(),
    ),
  );
}

class _ConfigPendenteApp extends StatelessWidget {
  const _ConfigPendenteApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Configuração pendente.\n\n'
                'Abra o arquivo lib/core/env.dart e cole a URL do projeto e a '
                'Publishable key do Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
