/// Endereços das telas.
class Rotas {
  const Rotas._();

  static const splash = '/splash';
  static const login = '/login';
  static const admin = '/admin';
  static const aluno = '/aluno';

  // Telas internas do admin (todas começam com /admin, então ficam
  // protegidas pela mesma regra de redirecionamento).
  static const alunoNovo = '/admin/aluno/novo';
  static String alunoDetalhe(String id) => '/admin/aluno/$id';
  static String alunoEditar(String id) => '/admin/aluno/$id/editar';
  static String treinoEditar(String alunoId, int dia) =>
      '/admin/aluno/$alunoId/treino/$dia';
}
