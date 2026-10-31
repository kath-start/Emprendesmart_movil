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
  });

  String get fullName => '$firstName $lastName';

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
    );
  }
}
