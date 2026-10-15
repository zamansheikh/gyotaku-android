// Dates as the app words them. Kept here rather than pulling in a
// localisation package for a dozen month names.

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _short = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "August", or "August 2025" when it is not this year's.
String monthName(int year, int month, DateTime now) =>
    year == now.year ? _months[month - 1] : '${_months[month - 1]} $year';

/// "Aug"
String monthShort(int month) => _short[month - 1];

/// "3 Aug", or "3 Aug 2025" when it is not this year's.
String dayShort(DateTime day, DateTime now) {
  final d = '${day.day} ${_short[day.month - 1]}';
  return day.year == now.year ? d : '$d ${day.year}';
}

/// "1,034"
String counted(int n) {
  final digits = '$n';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

DateTime taken(int mtime) => DateTime.fromMillisecondsSinceEpoch(mtime * 1000);

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// The heading a screenshot is listed under: Today, Yesterday, then by month.
String sectionOf(int mtime, DateTime now) {
  final t = taken(mtime);
  final days = _day(now).difference(_day(t)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  final month = _months[t.month - 1];
  return t.year == now.year ? month : '$month ${t.year}';
}

/// "9 October 2026, 00:27"
String stamp(int mtime) {
  final t = taken(mtime);
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year}, $hh:$mm';
}

/// The folder a screenshot sits in, which is what `in:` filters on.
String folderOf(String path) {
  final parts = path.split('/');
  return parts.length >= 2 ? parts[parts.length - 2] : '';
}
