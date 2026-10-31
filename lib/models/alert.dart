class Alert {
  final String id;
  final String type;
  final String severity;
  final String message;
  final String? status;
  final DateTime? triggeredAt;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.status,
    this.triggeredAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      status: json['status'] as String?,
      triggeredAt: json['triggeredAt'] == null ? null : DateTime.parse(json['triggeredAt'] as String),
    );
  }
}
