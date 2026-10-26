import 'dart:math';

import '../models/enums.dart';
import '../models/score.dart';

class PeriodScore {
  final String periodKey;
  final String label;
  final double? total;
  final Interval? interval;
  final int recordedDays;
  final int eligibleDays;
  final double? average;
  final double? trend;
  final Map<ScoreDomain, double> domains;
  final List<DayScore> days;

  const PeriodScore({
    required this.periodKey,
    required this.label,
    this.total,
    this.interval,
    required this.recordedDays,
    required this.eligibleDays,
    this.average,
    this.trend,
    this.domains = const {},
    this.days = const [],
  });

  bool get hasScore => total != null;
}

class ScoreAggregator {
  static PeriodScore week({
    required String weekKey,
    required String label,
    required List<DayScore> days,
    double? baseline28,
  }) {
    final eligible = days.where((e) => e.eligible && e.total != null).toList();
    if (eligible.isEmpty) {
      return PeriodScore(
        periodKey: weekKey,
        label: label,
        recordedDays: days.length,
        eligibleDays: 0,
        days: days,
      );
    }
    final scores = eligible.map((e) => e.total!).toList();
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final baseline = baseline28 ?? 60;
    final variance = scores.length <= 1
        ? 0.0
        : scores.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / scores.length;
    final sd = sqrt(variance);
    final total = (0.75 * mean + 0.25 * baseline - min(5, sd / 3)).clamp(0, 100).toDouble();
    final domains = <ScoreDomain, double>{};
    for (final domain in ScoreDomain.values) {
      final values = eligible.map((e) => e.domainScore(domain)).toList();
      domains[domain] = values.reduce((a, b) => a + b) / values.length;
    }
    return PeriodScore(
      periodKey: weekKey,
      label: label,
      total: total,
      interval: Interval(p10: (mean - sd).clamp(0, 100), p50: total, p90: (mean + sd).clamp(0, 100)),
      recordedDays: days.length,
      eligibleDays: eligible.length,
      average: mean,
      domains: domains,
      days: days,
    );
  }

  static PeriodScore month({
    required String monthKey,
    required String label,
    required List<PeriodScore> weeks,
    required List<DayScore> days,
  }) {
    final scored = weeks.where((e) => e.total != null).toList();
    if (scored.isEmpty) {
      return PeriodScore(
        periodKey: monthKey,
        label: label,
        recordedDays: days.length,
        eligibleDays: 0,
        days: days,
      );
    }
    final values = scored.map((e) => e.total!).toList()..sort();
    final median = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
    final trend = scored.length >= 2
        ? scored.last.total! - scored.first.total!
        : null;
    final domains = <ScoreDomain, double>{};
    for (final domain in ScoreDomain.values) {
      final vals = scored.map((e) => e.domains[domain] ?? 0).toList();
      domains[domain] = vals.reduce((a, b) => a + b) / vals.length;
    }
    return PeriodScore(
      periodKey: monthKey,
      label: label,
      total: median,
      interval: Interval(p10: values.first, p50: median, p90: values.last),
      recordedDays: days.length,
      eligibleDays: days.where((e) => e.eligible).length,
      trend: trend,
      domains: domains,
      days: days,
    );
  }
}
