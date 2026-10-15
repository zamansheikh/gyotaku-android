import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'when.dart';

/// A stretch of time the screenshots are narrowed to, written as the core's
/// own date filters (`date:`, `after:`, `before:`), so it means on the phone
/// exactly what it means on the desktop.
class DateSpan {
  const DateSpan._(
    this.label,
    this.filter,
    this.nothing, {
    this.month,
    this.range,
  });

  /// On its chip.
  final String label;

  /// Added to the query.
  final String filter;

  /// What the page says when nothing is in it.
  final String nothing;

  /// The month it is, when it is one, for the strip to show as chosen.
  final DateTime? month;

  /// The days it runs over, when they were picked, to open the picker on.
  final DateTimeRange? range;

  static const today = DateSpan._(
    'Today',
    'date:today',
    'No screenshots from today.',
  );
  static const yesterday = DateSpan._(
    'Yesterday',
    'date:yesterday',
    'No screenshots from yesterday.',
  );
  static const week = DateSpan._(
    'This week',
    'date:week',
    'No screenshots from this week.',
  );
  static const thisMonth = DateSpan._(
    'This month',
    'date:month',
    'No screenshots from this month.',
  );

  /// The quick ones, with a chip each.
  static const quick = [today, yesterday, week, thisMonth];

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// One calendar month.
  factory DateSpan.month(int year, int month, DateTime now) {
    final name = monthName(year, month, now);
    return DateSpan._(
      name,
      'date:$year-${month.toString().padLeft(2, '0')}',
      'No screenshots from $name.',
      month: DateTime(year, month),
    );
  }

  /// The days from `range.start` to `range.end`, both included.
  factory DateSpan.days(DateTimeRange range, DateTime now) {
    final first = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final last = DateTime(range.end.year, range.end.month, range.end.day);
    if (first == last) {
      final label = dayShort(first, now);
      return DateSpan._(
        label,
        'date:${_iso(first)}',
        'No screenshots from $label.',
        range: DateTimeRange(start: first, end: last),
      );
    }
    // "5 to 14 Oct" within a month, "28 Sep to 3 Oct" across two.
    final label = first.year == last.year && first.month == last.month
        ? '${first.day} to ${dayShort(last, now)}'
        : '${dayShort(first, now)} to ${dayShort(last, now)}';
    // `before:` is the day after, as the core counts it: up to its start.
    final after = DateTime(last.year, last.month, last.day + 1);
    return DateSpan._(
      label,
      'after:${_iso(first)} before:${_iso(after)}',
      'No screenshots from $label.',
      range: DateTimeRange(start: first, end: last),
    );
  }

  @override
  bool operator ==(Object other) => other is DateSpan && other.filter == filter;

  @override
  int get hashCode => filter.hashCode;
}

/// The system's calendar for picking a run of days, opened on `current`.
/// Null when it is closed without a choice.
Future<DateSpan?> pickDays(BuildContext context, DateSpan? current) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2005),
    lastDate: today,
    initialDateRange: current?.range,
    helpText: 'Screenshots taken',
    saveText: 'Show',
  );
  if (picked == null) return null;
  return DateSpan.days(picked, now);
}

/// Which months the matches of a search fall in, one bar a month, newest
/// first. A search can find a thousand screenshots; this says where they
/// are, and a tap narrows the results to that month. Tapped again, it lets
/// go.
class MonthStrip extends StatelessWidget {
  const MonthStrip({
    super.key,
    required this.times,
    required this.chosen,
    required this.onChoose,
  });

  /// When each match was taken, in seconds since the epoch.
  final List<int> times;

  final DateSpan? chosen;
  final ValueChanged<DateSpan?> onChoose;

  /// Matches by month, newest first.
  static List<(DateTime, int)> monthsOf(List<int> times) {
    final counts = <DateTime, int>{};
    for (final t in times) {
      final d = taken(t);
      final m = DateTime(d.year, d.month);
      counts[m] = (counts[m] ?? 0) + 1;
    }
    final months = counts.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final m in months) (m, counts[m]!)];
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();
    final months = monthsOf(times);
    final most = months.fold(1, (most, m) => m.$2 > most ? m.$2 : most);

    final cells = <Widget>[];
    int? year = now.year;
    for (final (month, count) in months) {
      // A year's months are marked with the year once, before the first.
      if (month.year != year) {
        year = month.year;
        cells.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 4, 4),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                '${month.year}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
            ),
          ),
        );
      }
      final span = DateSpan.month(month.year, month.month, now);
      final on = chosen == span;
      cells.add(
        Semantics(
          button: true,
          selected: on,
          label:
              '${monthName(month.year, month.month, now)}, '
              '${count == 1 ? '1 match' : '${counted(count)} matches'}',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onChoose(on ? null : span);
            },
            child: Container(
              width: 50,
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              decoration: BoxDecoration(
                // Chosen, its bar is ink on a tile.
                color: on ? p.tile : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 16,
                    height: 4 + 22 * count / most,
                    decoration: BoxDecoration(
                      color: on ? p.text : p.faint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    monthShort(month.month),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: p.text,
                    ),
                  ),
                  Text(
                    counted(count),
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: MediaQuery.withNoTextScaling(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: cells,
        ),
      ),
    );
  }
}
