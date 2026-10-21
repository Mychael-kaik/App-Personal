/// Endereços das telas.
class Rotas {
  const Rotas._();

  static const splash = '/splash';
  static const academias = '/academias';
  static const login = '/login';
  static const recuperar = '/recuperar';
  static const admin = '/admin';
  static const aluno = '/aluno';

  // Tela do exercício do aluno (começa com /aluno: protegida pela mesma regra).
  static const progresso = '/aluno/progresso';
  static String exercicio(String itemId) => '/aluno/exercicio/$itemId';

  // Telas internas do admin (todas começam com /admin, então ficam
  // protegidas pela mesma regra de redirecionamento).
  static const alunoNovo = '/admin/aluno/novo';
  static const professorNovo = '/admin/professor/novo';
  static const modelos = '/admin/modelos';
  static String alunoDetalhe(String id) => '/admin/aluno/$id';
  static String alunoEditar(String id) => '/admin/aluno/$id/editar';
  static String alunoProgresso(String id) => '/admin/aluno/$id/progresso';
  static String treinoEditar(String alunoId, int dia) =>
      '/admin/aluno/$alunoId/treino/$dia';
}
