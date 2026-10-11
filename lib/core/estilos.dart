import 'package:flutter/material.dart';

// O tema do app deixa os botões preenchidos/contornados com largura
// "infinita" (ocupam a linha toda). Isso é ótimo em formulários, mas
// QUEBRA dentro de Row, diálogos e ListTile. Nesses lugares usamos estes
// estilos, que mantêm a altura confortável (48) mas deixam a largura livre.

ButtonStyle compactoPreenchido() =>
    FilledButton.styleFrom(minimumSize: const Size(0, 48));

ButtonStyle compactoContorno() =>
    OutlinedButton.styleFrom(minimumSize: const Size(0, 48));
