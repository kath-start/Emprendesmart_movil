import 'idea_plan.dart';

/// Rol del emprendedor en un negocio: dueño o parte del equipo (plan Pro).
enum BusinessRole {
  owner('Dueño'),
  partner('Socio'),
  cashier('Cajero(a)');

  final String label;

  const BusinessRole(this.label);

  static BusinessRole fromApi(String? value) => switch (value) {
    'PARTNER' => BusinessRole.partner,
    'CASHIER' => BusinessRole.cashier,
    _ => BusinessRole.owner,
  };
}

class Business {
  final String id;
  final String entrepreneurId;
  final String name;
  final String? logoUrl;
  final String category;
  final String? description;
  final String stage;
  final String status;
  final int employeesCount;
  final BusinessRole role;

  /// Nombre del dueño; se muestra cuando el negocio es compartido.
  final String? ownerName;

  /// Plan de lanzamiento (solo se usa mientras el negocio está en etapa IDEA).
  final IdeaPlan ideaPlan;

  Business({
    required this.id,
    required this.entrepreneurId,
    required this.name,
    this.logoUrl,
    required this.category,
    this.description,
    required this.stage,
    required this.status,
    required this.employeesCount,
    this.role = BusinessRole.owner,
    this.ownerName,
    this.ideaPlan = const IdeaPlan(),
  });

  bool get isIdea => stage == 'IDEA';
  bool get isOwner => role == BusinessRole.owner;
  bool get isShared => !isOwner;
  bool get canManageProducts => role != BusinessRole.cashier;
  bool get canDeleteProducts => isOwner;
  bool get canSeeInsights => role != BusinessRole.cashier;
  bool get canSeeDashboard => role != BusinessRole.cashier;

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      entrepreneurId: json['entrepreneurId'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      category: json['category'] as String,
      description: json['description'] as String?,
      stage: json['stage'] as String,
      status: json['status'] as String,
      employeesCount: (json['employeesCount'] as num?)?.toInt() ?? 0,
      role: BusinessRole.fromApi(json['role'] as String?),
      ownerName: json['ownerName'] as String?,
      ideaPlan: IdeaPlan.fromJson(json['ideaPlan'] as Map<String, dynamic>?),
    );
  }
}
