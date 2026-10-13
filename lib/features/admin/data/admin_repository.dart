import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_exception.dart';
import '../../auth/domain/profile.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';

/// Tudo que o ADMIN faz no banco passa por aqui:
/// alunos, biblioteca de exercícios e treinos.
///
/// As telas nunca falam com o Supabase direto. Vantagem: se a forma de
/// guardar os dados mudar, só este arquivo muda.
///
/// Segurança: este código roda no app, mas quem realmente DECIDE o que é
/// permitido é o banco (RLS). Se um aluno tentasse chamar estes métodos,
/// o banco recusaria.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  // ===================================================================
  // ALUNOS
  // ===================================================================

  Future<List<Profile>> listarAlunos() async {
    // ATENÇÃO: no supabase_flutter, order() é DECRESCENTE por padrão.
    // Por isso sempre passamos ascending: true.
    final dados = await _client
        .from('profiles')
        .select()
        .eq('perfil', 'aluno')
        .order('nome', ascending: true);
    return dados.map<Profile>(Profile.fromMap).toList();
  }

  Future<Profile> buscarAluno(String id) async {
    final dados =
        await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (dados == null) throw const AppException('Aluno não encontrado.');
    return Profile.fromMap(dados);
  }

  /// Cria login + perfil do aluno chamando a Edge Function `admin-create-student`
  /// (que roda no servidor e confere se quem chamou é admin).
  Future<void> criarAluno({
    required String nome,
    required String email,
    required String senha,
    String? observacoes,
  }) async {
    // Mandamos o login (token) do admin; a função confere se ele é admin.
    // Se a função responder com erro (ex.: e-mail já cadastrado), o pacote do
    // Supabase lança uma FunctionException, e a mensagem amigável é montada em
    // mensagemDeErro (core/mensagens.dart).
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }

    final resposta = await _client.functions.invoke(
      'admin-create-student',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'nome': nome,
        'email': email,
        'senha': senha,
        'observacoes': observacoes,
      },
    );
    final dados = resposta.data;
    if (dados is Map && dados['error'] is String) {
      throw AppException(dados['error'] as String);
    }
  }

  Future<void> atualizarAluno(
    String id, {
    required String nome,
    String? observacoes,
  }) async {
    await _client
        .from('profiles')
        .update({'nome': nome, 'observacoes': observacoes}).eq('id', id);
  }

  /// Desativar = o aluno perde o acesso, mas o histórico dele continua guardado.
  Future<void> definirAtivo(String id, bool ativo) async {
    await _client.from('profiles').update({'ativo': ativo}).eq('id', id);
  }

  /// Define uma NOVA senha para o aluno, chamando a Edge Function
  /// `admin-reset-student-password` (roda no servidor, confere se quem chamou é
  /// admin e só aceita alunos). A senha antiga deixa de valer na hora.
  Future<void> redefinirSenha({
    required String alunoId,
    required String senha,
  }) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }

    final resposta = await _client.functions.invoke(
      'admin-reset-student-password',
      headers: {'Authorization': 'Bearer $token'},
      body: {'aluno_id': alunoId, 'senha': senha},
    );
    final dados = resposta.data;
    if (dados is Map && dados['error'] is String) {
      throw AppException(dados['error'] as String);
    }
  }

  // ===================================================================
  // EXERCÍCIOS
  // ===================================================================

  Future<List<Exercise>> listarExercicios() async {
    final dados = await _client
        .from('exercises')
        .select()
        .order('grupo_muscular', ascending: true)
        .order('nome', ascending: true);
    return dados.map<Exercise>(Exercise.fromMap).toList();
  }

  Future<void> criarExercicio({
    required String nome,
    required String grupoMuscular,
    String? descricao,
    String? fotoPath,
  }) async {
    await _client.from('exercises').insert({
      'nome': nome,
      'grupo_muscular': grupoMuscular,
      'descricao': descricao,
      'foto_path': fotoPath,
    });
  }

  Future<void> atualizarExercicio(
    String id, {
    required String nome,
    required String grupoMuscular,
    String? descricao,
    String? fotoPath,
  }) async {
    await _client.from('exercises').update({
      'nome': nome,
      'grupo_muscular': grupoMuscular,
      'descricao': descricao,
      'foto_path': fotoPath,
    }).eq('id', id);
  }

  /// Envia a foto para o Storage (bucket privado `exercicios`) e devolve o
  /// caminho a guardar em `exercises.foto_path`.
  /// Cada envio usa um nome NOVO, então trocar a foto nunca mostra a antiga
  /// guardada em cache. Quem barra alunos é o RLS do Storage (só admin envia).
  Future<String> enviarFoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extensao = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final nome =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    final caminho = 'fotos/$nome.$extensao';
    await _client.storage.from('exercicios').uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return caminho;
  }

  /// Apaga uma foto do Storage. Se falhar, ignora: sobrar um arquivo
  /// esquecido não atrapalha o app.
  Future<void> removerFoto(String caminho) async {
    try {
      await _client.storage.from('exercicios').remove([caminho]);
    } catch (_) {}
  }

  Future<void> removerExercicio(String id) async {
    try {
      await _client.from('exercises').delete().eq('id', id);
    } on PostgrestException catch (e) {
      // 23503 = chave estrangeira: o exercício ainda é usado em algum treino.
      if (e.code == '23503') {
        throw const AppException(
          'Este exercício está em algum treino. Remova-o dos treinos antes de excluir.',
        );
      }
      rethrow;
    }
  }

  // ===================================================================
  // TREINOS
  // ===================================================================

  /// Todos os treinos de um aluno, já com os itens e o nome dos exercícios.
  Future<List<Workout>> listarTreinos(String alunoId) async {
    final dados = await _client
        .from('workouts')
        .select(
          'id, aluno_id, dia_da_semana, titulo, '
          'workout_items(id, workout_id, exercise_id, series, repeticoes, '
          'tempo_segundos, descanso_serie_segundos, descanso_segundos, '
          'carga, observacao, ordem, '
          'exercises(nome, grupo_muscular, descricao, foto_path))',
        )
        .eq('aluno_id', alunoId)
        .order('dia_da_semana', ascending: true);
    return dados.map<Workout>(Workout.fromMap).toList();
  }

  /// Cria ou atualiza um treino inteiro (função SQL `salvar_treino`).
  /// [treinoId] null = treino novo.
  Future<void> salvarTreino({
    String? treinoId,
    required String alunoId,
    required int dia,
    required String titulo,
    required List<WorkoutItem> itens,
  }) async {
    try {
      await _client.rpc(
        'salvar_treino',
        params: {
          'p_workout_id': treinoId,
          'p_aluno_id': alunoId,
          'p_dia': dia,
          'p_titulo': titulo,
          'p_itens': itens.map((i) => i.paraRpc()).toList(),
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppException(
          'Esse dia já tem um treino. Volte, atualize a tela e edite o treino existente.',
        );
      }
      rethrow;
    }
  }

  /// Copia um treino para outro dia e/ou outro aluno (função SQL `duplicar_treino`).
  Future<void> duplicarTreino({
    required String treinoId,
    required String alunoDestinoId,
    required int diaDestino,
  }) async {
    try {
      await _client.rpc(
        'duplicar_treino',
        params: {
          'p_workout_id': treinoId,
          'p_aluno_destino': alunoDestinoId,
          'p_dia_destino': diaDestino,
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppException(
          'O destino já tem treino nesse dia. Remova-o antes ou escolha outro dia.',
        );
      }
      rethrow;
    }
  }

  /// Os itens do treino são apagados junto (ON DELETE CASCADE no banco).
  Future<void> removerTreino(String treinoId) async {
    await _client.from('workouts').delete().eq('id', treinoId);
  }
}
