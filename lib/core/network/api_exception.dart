/// Error de la API con el mensaje ya listo para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  final List<Map<String, dynamic>>? details;

  ApiException(this.message, {this.details});

  @override
  String toString() => message;
}
