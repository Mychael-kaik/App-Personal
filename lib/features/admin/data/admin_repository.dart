import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_exception.dart';
import '../../auth/domain/profile.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';


class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  // ALUNOS E PROFESSORES

Future<List<Profile>> listarAlunos() async {
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

    if (dados == null) {
      throw const AppException('Aluno não encontrado.');
    }

    return Profile.fromMap(dados);
  }

 Future<void> criarAluno({
    required String nome,
    required String email,
    required String senha,
    String? observacoes,
  }) {
    return _criarUsuario(
      nome: nome,
      email: email,
      senha: senha,
      observacoes: observacoes,
      perfil: 'aluno',
    );
  }

  Future<void> criarProfessor({
    required String nome,
    required String email,
    required String senha,
    String? observacoes,
  }) {
    return _criarUsuario(
      nome: nome,
      email: email,
      senha: senha,
      observacoes: observacoes,
      perfil: 'professor',
    );
  }

  Future<void> _criarUsuario({
    required String nome,
    required String email,
    required String senha,
    required String perfil,
    String? observacoes,
}) async {
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
        'perfil': perfil,
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
        .update({'nome': nome, 'observacoes': observacoes})
        .eq('id', id);
  }

Future<void> definirAtivo(String id, bool ativo) async {
    await _client.from('profiles').update({'ativo': ativo}).eq('id', id);
  }

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

// EXERCÍCIOS
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

Future<void> removerFoto(String caminho) async {
    try {
      await _client.storage.from('exercicios').remove([caminho]);
    } catch (_) {}
  }

  Future<void> removerExercicio(String id) async {
    try {
      await _client.from('exercises').delete().eq('id', id);
  } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const AppException(
          'Este exercício está em algum treino. '
          'Remova-o dos treinos antes de excluir.',
        );
      }
      rethrow;
    }
  }

// TREINOS
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
          'Esse dia já tem um treino. '
          'Volte, atualize a tela e edite o treino existente.',
        );
      }
      rethrow;
    }
  }

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
          'O destino já tem treino nesse dia. '
          'Remova-o antes ou escolha outro dia.',
        );
      }
      rethrow;
    }
  }

Future<void> removerTreino(String treinoId) async {
    await _client.from('workouts').delete().eq('id', treinoId);
  }
}
