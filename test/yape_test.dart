import 'package:emprende_smart/features/sales/new_sale_screen.dart';
import 'package:emprende_smart/models/product.dart';
import 'package:emprende_smart/models/yape_payment.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, double price, {int stock = 10}) => Product.fromJson({
  'id': id,
  'businessId': 'b1',
  'name': 'Producto $id',
  'price': price,
  'stock': stock,
  'status': 'ACTIVE',
});

void main() {
  group('lectura de la notificación de Yape', () {
    test('monto y nombre del pago típico', () {
      final p = YapePayment.fromNotification(
        id: '1',
        title: 'Confirmación de Pago',
        text: 'Yape! Ana R. Lopez te envió un pago por S/ 85',
        postedAt: DateTime(2026, 11, 4),
      );
      expect(p.amount, 85);
      expect(p.senderName, 'Ana R. Lopez');
      expect(p.saleNote, 'Cobro Yape · Ana R. Lopez · S/ 85.00');
    });

    test('formatos de monto', () {
      expect(parseYapeAmount('te envió un pago por S/ 19.90'), 19.90);
      expect(parseYapeAmount('te envió un pago por S/. 19,90'), 19.90);
      expect(parseYapeAmount('te envió un pago por S/ 1,250.50'), 1250.50);
      expect(parseYapeAmount('te envió un pago por S/1,250'), 1250);
      expect(parseYapeAmount('sin monto'), isNull);
    });

    test('nombre sin prefijo "Yape!"', () {
      expect(parseYapeSender('Luis M. te envio un pago por S/ 42'), 'Luis M.');
    });
  });

  group('sugerencia de productos por monto', () {
    final products = [_product('polo', 35), _product('gorra', 25), _product('taza', 18.5, stock: 0)];

    test('un producto con el precio exacto', () {
      expect(suggestProductsForAmount(25, products), {'gorra': 1});
    });

    test('varias unidades del mismo producto', () {
      expect(suggestProductsForAmount(70, products), {'polo': 2});
    });

    test('dos productos distintos', () {
      expect(suggestProductsForAmount(60, products), {'polo': 1, 'gorra': 1});
    });

    test('ignora productos sin stock y montos que no cuadran', () {
      expect(suggestProductsForAmount(18.5, products), isNull);
      expect(suggestProductsForAmount(13, products), isNull);
    });
  });
}
