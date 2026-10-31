class Recommendation {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String source;
  final DateTime generatedAt;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.source,
    required this.generatedAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      source: json['source'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}
