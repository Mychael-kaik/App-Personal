/// Uma academia como aparece na tela de escolha, ANTES do login.
/// Tem só o que o banco entrega a visitantes: id, nome e logo (nada mais).
class AcademiaPublica {
  const AcademiaPublica({
    required this.id,
    required this.nome,
    this.logoPath,
  });

  final String id;
  final String nome;

  /// Caminho da logo no bucket público `logos` (ou null se não tiver).
  final String? logoPath;

  factory AcademiaPublica.fromMap(Map<String, dynamic> map) {
    return AcademiaPublica(
      id: map['id'] as String,
      nome: map['nome'] as String,
      logoPath: map['logo_path'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is AcademiaPublica && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
