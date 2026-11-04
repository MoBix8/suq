import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat('#,##0.00', 'en');
final NumberFormat _compact = NumberFormat('#,##0', 'en');
final DateFormat _date = DateFormat('d MMM yyyy');
final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
final DateFormat _time = DateFormat('HH:mm');
final DateFormat _weekday = DateFormat('EEE');
final DateFormat _dayMonth = DateFormat('d MMM');

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
String formatTime(DateTime date) => _time.format(date.toLocal());
String formatWeekday(DateTime date) => _weekday.format(date.toLocal());
String formatDayMonth(DateTime date) => _dayMonth.format(date.toLocal());

String qty(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String percent(num value) => '${value.toStringAsFixed(1)}%';
