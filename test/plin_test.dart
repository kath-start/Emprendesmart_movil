import 'package:flutter_test/flutter_test.dart';

import 'package:emprende_smart/models/yape_payment.dart';

void main() {
  group('lectura de notificaciones de Plin', () {
    test('"Recibiste un Plin de ... por S/ ..."', () {
      final p = YapePayment.fromNotification(
        id: '1',
        title: 'Plin',
        text: 'Recibiste un Plin de Carlos Ruiz por S/ 15.00',
        postedAt: DateTime(2026),
        source: 'plin',
      );
      expect(p.isPlin, isTrue);
      expect(p.senderName, 'Carlos Ruiz');
      expect(p.amount, 15.0);
      expect(p.saleNote, 'Cobro Plin · Carlos Ruiz · S/ 15.00');
    });

    test('"... te envió S/ ... por Plin"', () {
      expect(parseYapeSender('Ana Torres te envió S/ 30.50 por Plin'), 'Ana Torres');
      expect(parseYapeAmount('Ana Torres te envió S/ 30.50 por Plin'), 30.5);
    });

    test('"Recibiste S/ ... de ..."', () {
      expect(parseYapeSender('Recibiste S/ 12.00 de Luis Vega.'), 'Luis Vega');
    });

    test('los cobros guardados sin método siguen siendo Yape', () {
      final p = YapePayment.fromJson({'id': 'x', 'message': 'm', 'receivedAt': '2026-01-01T00:00:00.000'});
      expect(p.method, 'yape');
    });
  });
}
