import '../../core/network/api_client.dart';

/// Consultas al asistente que le quedan hoy al emprendedor. `limit == null` = sin límite.
class AiUsage {
  final int? limit;
  final int used;
  final int? remaining;

  const AiUsage({this.limit, required this.used, this.remaining});

  bool get isLimited => limit != null;
  bool get isExhausted => remaining == 0;

  factory AiUsage.fromJson(Map<String, dynamic> json) =>
      AiUsage(limit: json['limit'] as int?, used: json['used'] as int? ?? 0, remaining: json['remaining'] as int?);
}

class AssistantReply {
  final String reply;
  final AiUsage? usage;

  const AssistantReply(this.reply, this.usage);
}

class AssistantService {
  /// Código que manda el backend cuando se acabaron las consultas del día.
  static const dailyLimitCode = 'AI_DAILY_LIMIT_REACHED';

  final ApiClient _apiClient;

  AssistantService(this._apiClient);

  Future<AiUsage> getUsage(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/ai/usage');
    return AiUsage.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<AssistantReply> sendMessage(
    String businessId,
    String message, {
    required List<Map<String, String>> history,
  }) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/ai/chat',
      data: {'message': message, if (history.isNotEmpty) 'history': history},
    );
    final data = response['data'] as Map<String, dynamic>;
    final usage = data['usage'] as Map<String, dynamic>?;
    return AssistantReply(data['reply'] as String, usage == null ? null : AiUsage.fromJson(usage));
  }
}
