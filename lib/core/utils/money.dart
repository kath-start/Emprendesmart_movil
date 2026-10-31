/// Monto en soles con separador de miles: `S/ 1,240.50`.
String formatMoney(double value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${value < 0 ? '-' : ''}S/ $whole.${parts[1]}';
}
