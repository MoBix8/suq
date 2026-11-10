import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat('#,##0.00', 'en');
final NumberFormat _compact = NumberFormat('#,##0', 'en');
final DateFormat _date = DateFormat('d MMM yyyy');
final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');

String money(num value) => 'Br ${_money.format(value)}';

String moneyCompact(num value) {
  if (value >= 1000000) {
    return 'Br ${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 10000) {
    return 'Br ${(value / 1000).toStringAsFixed(1)}k';
  }
  return 'Br ${_compact.format(value)}';
}

String formatDate(DateTime date) => _date.format(date.toLocal());
String formatDateTime(DateTime date) => _dateTime.format(date.toLocal());

String qty(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String weightLabel(num kg) => '${qty(kg)} kg';
String volumeLabel(num m3) => '${qty(m3)} m³';

String distanceLabel(num? km) {
  if (km == null) return 'Distance not set';
  return '${km.toStringAsFixed(1)} km away';
}
