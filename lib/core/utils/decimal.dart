/// Los campos Decimal de Prisma (price, cost, total, ...) llegan como String en el JSON.
num parseNum(dynamic value, {num fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? fallback;
}
