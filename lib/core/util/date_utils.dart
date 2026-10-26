import 'package:intl/intl.dart';

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(parts[0]) ?? 1970,
    int.tryParse(parts[1]) ?? 1,
    int.tryParse(parts[2]) ?? 1,
  );
}

String todayKey([DateTime? now]) => dateKey(now ?? DateTime.now());

String addDaysKey(String key, int days) {
  final date = parseDateKey(key).add(Duration(days: days));
  return dateKey(date);
}

List<String> dateRange(String start, String end) {
  final out = <String>[];
  var current = parseDateKey(start);
  final last = parseDateKey(end);
  while (!current.isAfter(last)) {
    out.add(dateKey(current));
    current = current.add(const Duration(days: 1));
  }
  return out;
}

String weekKey(String dateKeyValue) {
  final date = parseDateKey(dateKeyValue);
  final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week = 1 +
      ((thursday.difference(firstThursday).inDays) / 7).floor();
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String monthKey(String dateKeyValue) => dateKeyValue.substring(0, 7);

String formatDate(String key) {
  final date = parseDateKey(key);
  return DateFormat('M 月 d 日', 'zh_CN').format(date);
}

String formatDateWithWeekday(String key) {
  final date = parseDateKey(key);
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${DateFormat('M 月 d 日', 'zh_CN').format(date)} · 周${weekdays[date.weekday - 1]}';
}

String formatMonth(String key) {
  final date = parseDateKey('$key-01');
  return DateFormat('yyyy 年 M 月', 'zh_CN').format(date);
}

String formatWeekRange(String anyDate) {
  final date = parseDateKey(anyDate);
  final monday = date.subtract(Duration(days: date.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  return '${DateFormat('M/d', 'zh_CN').format(monday)} – ${DateFormat('M/d', 'zh_CN').format(sunday)}';
}

String relativeDayLabel(String key) {
  final today = parseDateKey(todayKey());
  final target = parseDateKey(key);
  final diff = target.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return '今天';
  if (diff == -1) return '昨天';
  if (diff == 1) return '明天';
  if (diff < -1 && diff >= -6) return '${-diff} 天前';
  if (diff > 1 && diff <= 6) return '$diff 天后';
  return formatDate(key);
}

int minutesSinceMidnight(DateTime time) => time.hour * 60 + time.minute;

String slotForTime(DateTime time) {
  final hour = time.hour;
  if (hour < 10) return 'breakfast';
  if (hour < 15) return 'lunch';
  if (hour < 21) return 'dinner';
  return 'snack';
}
