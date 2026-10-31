/// Textos en español para los valores internos (enums) que envía el backend.
/// Los valores se siguen enviando en inglés a la API; solo cambia lo que ve el usuario.
class Labels {
  Labels._();

  static const _businessStages = {
    'IDEA': 'Idea',
    'EARLY': 'Inicio',
    'GROWTH': 'Crecimiento',
    'ESTABLISHED': 'Consolidado',
  };

  static const _statuses = {'ACTIVE': 'Activo', 'INACTIVE': 'Inactivo', 'CLOSED': 'Cerrado', 'SUSPENDED': 'Suspendido'};

  static const _plans = {'FREE': 'Gratis', 'EMPRENDE': 'Emprende', 'CRECIMIENTO': 'Crecimiento', 'PRO': 'Pro'};

  static const _movementTypes = {
    'RESTOCK': 'Reposición',
    'SALE': 'Venta',
    'ADJUSTMENT': 'Ajuste',
    'RETURN': 'Devolución',
  };

  static const _alertTypes = {
    'STOCK_BAJO': 'Stock bajo',
    'CAIDA_INGRESOS': 'Caída de ingresos',
    'GASTOS_ELEVADOS': 'Gastos elevados',
    'INACTIVIDAD': 'Inactividad',
    'META_ALCANZADA': 'Meta alcanzada',
    'FLUJO_CAJA': 'Flujo de caja',
  };

  static const _alertStatuses = {'OPEN': 'Abierta', 'ACKNOWLEDGED': 'Vista', 'RESOLVED': 'Resuelta'};

  static const _recommendationStatuses = {
    'PENDING': 'Pendiente',
    'SENT': 'Enviada',
    'ACCEPTED': 'Aceptada',
    'DISMISSED': 'Descartada',
  };

  static String businessStage(String value) => _businessStages[value] ?? _humanize(value);
  static String status(String value) => _statuses[value] ?? _humanize(value);
  static String plan(String value) => _plans[value] ?? _humanize(value);
  static String movementType(String value) => _movementTypes[value] ?? _humanize(value);
  static String alertType(String value) => _alertTypes[value] ?? _humanize(value);
  static String alertStatus(String value) => _alertStatuses[value] ?? _humanize(value);
  static String recommendationStatus(String value) => _recommendationStatuses[value] ?? _humanize(value);

  /// Para valores nuevos que aún no estén en las tablas: "ALGO_NUEVO" -> "Algo nuevo".
  static String _humanize(String value) {
    final text = value.replaceAll('_', ' ').toLowerCase();
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }
}
