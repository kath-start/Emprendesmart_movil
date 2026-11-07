import 'package:flutter/material.dart' show DateUtils;

class Entrepreneur {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? country;
  final String? city;
  final String plan;
  final String status;

  /// Hasta cuándo está pagado el plan; null si no vence (Gratis o asignado por el equipo).
  final DateTime? planExpiresAt;

  Entrepreneur({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.country,
    this.city,
    required this.plan,
    required this.status,
    this.planExpiresAt,
  });

  String get fullName => '$firstName $lastName';

  bool get isFreePlan => plan == 'FREE';

  /// Días que faltan para que venza el plan (negativo si ya venció); null si no vence.
  int? get planDaysLeft {
    final expires = planExpiresAt;
    if (expires == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(expires.toLocal()).difference(today).inDays;
  }

  factory Entrepreneur.fromJson(Map<String, dynamic> json) {
    return Entrepreneur(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      plan: json['plan'] as String,
      status: json['status'] as String,
      planExpiresAt: json['planExpiresAt'] == null ? null : DateTime.parse(json['planExpiresAt'] as String),
    );
  }
}
