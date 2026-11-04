import 'package:flutter_test/flutter_test.dart';
import 'package:suq_admin/core/formatters.dart';

void main() {
  group('formatters', () {
    test('money uses birr and two decimals', () {
      expect(money(1234.5), 'Br 1,234.50');
      expect(money(0), 'Br 0.00');
    });

    test('moneyCompact shortens large amounts', () {
      expect(moneyCompact(500), 'Br 500');
      expect(moneyCompact(12500), 'Br 12.5k');
      expect(moneyCompact(2500000), 'Br 2.5M');
    });

    test('qty drops unnecessary decimals', () {
      expect(qty(2), '2');
      expect(qty(2.5), '2.5');
      expect(qty(2.50), '2.5');
    });

    test('percent keeps one decimal', () {
      expect(percent(12.345), '12.3%');
    });

    test('daysLeftLabel handles a missing end date', () {
      expect(daysLeftLabel(null), 'No end date');
    });
  });
}
