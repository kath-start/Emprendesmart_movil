import '../../core/network/api_client.dart';
import '../../models/business.dart';

class TeamMember {
  final String id;
  final String email;
  final BusinessRole role;

  /// Nombre de su cuenta; null si todavía no se registró en la app con ese correo.
  final String? name;
  final bool registered;

  const TeamMember({required this.id, required this.email, required this.role, this.name, required this.registered});

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    email: json['email'] as String,
    role: BusinessRole.fromApi(json['role'] as String?),
    name: json['name'] as String?,
    registered: json['registered'] as bool? ?? false,
  );
}

class Team {
  final List<TeamMember> members;
  final int maxMembers;

  /// false si el dueño no tiene un plan que incluya equipo (Pro).
  final bool enabled;

  const Team({required this.members, required this.maxMembers, required this.enabled});
}

String _roleToApi(BusinessRole role) => role == BusinessRole.cashier ? 'CASHIER' : 'PARTNER';

/// Equipo de un negocio: el dueño con plan Pro suma socios y cajeros por su correo.
class TeamService {
  final ApiClient _apiClient;

  TeamService(this._apiClient);

  Future<Team> get(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/team');
    final data = response['data'] as Map<String, dynamic>;
    return Team(
      members: (data['members'] as List<dynamic>)
          .map((item) => TeamMember.fromJson(item as Map<String, dynamic>))
          .toList(),
      maxMembers: data['maxMembers'] as int,
      enabled: data['teamEnabled'] as bool,
    );
  }

  Future<TeamMember> add(String businessId, {required String email, required BusinessRole role}) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/team',
      data: {'email': email, 'role': _roleToApi(role)},
    );
    return TeamMember.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<TeamMember> changeRole(String businessId, String memberId, BusinessRole role) async {
    final response = await _apiClient.patch(
      '/app/businesses/$businessId/team/$memberId',
      data: {'role': _roleToApi(role)},
    );
    return TeamMember.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> remove(String businessId, String memberId) =>
      _apiClient.delete('/app/businesses/$businessId/team/$memberId');
}
