import 'enums.dart';
import 'json_utils.dart';

class Interval {
  final double p10;
  final double p50;
  final double p90;

  const Interval({required this.p10, required this.p50, required this.p90});

  double get width => p90 - p10;

  String get display => '${p10.round()}–${p90.round()}';

  Map<String, Object?> toJson() => {'p10': p10, 'p50': p50, 'p90': p90};

  factory Interval.fromJson(Map<String, Object?> json) => Interval(
        p10: asDouble(json['p10']) ?? 0,
        p50: asDouble(json['p50']) ?? 0,
        p90: asDouble(json['p90']) ?? 0,
      );
}

class ScoreItemResult {
  final String code;
  final String label;
  final ScoreDomain domain;
  final double score;
  final double weight;
  final double intake;
  final double targetMin;
  final double targetMax;
  final String unit;
  final ScoreStatus status;
  final String note;
  final double? baseline;

  const ScoreItemResult({
    required this.code,
    required this.label,
    required this.domain,
    required this.score,
    required this.weight,
    required this.intake,
    required this.targetMin,
    required this.targetMax,
    required this.unit,
    required this.status,
    this.note = '',
    this.baseline,
  });

  double get lostPoints => (100 - score) * weight / 100.0;

  Map<String, Object?> toJson() => {
        'code': code,
        'label': label,
        'domain': domain.name,
        'score': score,
        'weight': weight,
        'intake': intake,
        'targetMin': targetMin,
        'targetMax': targetMax,
        'unit': unit,
        'status': status.name,
        'note': note,
        'baseline': baseline,
      };

  factory ScoreItemResult.fromJson(Map<String, Object?> json) => ScoreItemResult(
        code: asString(json['code']) ?? '',
        label: asString(json['label']) ?? '',
        domain: ScoreDomain.values.firstWhere(
          (e) => e.name == asString(json['domain']),
          orElse: () => ScoreDomain.nutrients,
        ),
        score: asDouble(json['score']) ?? 0,
        weight: asDouble(json['weight']) ?? 0,
        intake: asDouble(json['intake']) ?? 0,
        targetMin: asDouble(json['targetMin']) ?? 0,
        targetMax: asDouble(json['targetMax']) ?? 0,
        unit: asString(json['unit']) ?? '',
        status: ScoreStatus.values.firstWhere(
          (e) => e.name == asString(json['status']),
          orElse: () => ScoreStatus.unknown,
        ),
        note: asString(json['note']) ?? '',
        baseline: asDouble(json['baseline']),
      );
}

class DomainScore {
  final ScoreDomain domain;
  final double score;
  final double weight;

  const DomainScore({
    required this.domain,
    required this.score,
    required this.weight,
  });

  Map<String, Object?> toJson() => {
        'domain': domain.name,
        'score': score,
        'weight': weight,
      };

  factory DomainScore.fromJson(Map<String, Object?> json) => DomainScore(
        domain: ScoreDomain.values.firstWhere(
          (e) => e.name == asString(json['domain']),
          orElse: () => ScoreDomain.nutrients,
        ),
        score: asDouble(json['score']) ?? 0,
        weight: asDouble(json['weight']) ?? 0,
      );
}

class ScoreGate {
  final String code;
  final String label;
  final double cap;
  final bool triggered;

  const ScoreGate({
    required this.code,
    required this.label,
    required this.cap,
    required this.triggered,
  });

  Map<String, Object?> toJson() => {
        'code': code,
        'label': label,
        'cap': cap,
        'triggered': triggered,
      };

  factory ScoreGate.fromJson(Map<String, Object?> json) => ScoreGate(
        code: asString(json['code']) ?? '',
        label: asString(json['label']) ?? '',
        cap: asDouble(json['cap']) ?? 100,
        triggered: asBool(json['triggered']),
      );
}

class DayScore {
  final String date;
  final double? total;
  final Interval? interval;
  final List<ScoreItemResult> items;
  final List<DomainScore> domains;
  final bool eligible;
  final List<String> eligibilityReasons;
  final Map<String, double> totals;
  final Map<String, double> groupTotals;
  final List<ScoreGate> gates;
  final String topAction;
  final int entryCount;
  final int algoVersion;

  const DayScore({
    required this.date,
    this.total,
    this.interval,
    required this.items,
    required this.domains,
    required this.eligible,
    this.eligibilityReasons = const [],
    this.totals = const {},
    this.groupTotals = const {},
    this.gates = const [],
    required this.topAction,
    this.entryCount = 0,
    this.algoVersion = 1,
  });

  double domainScore(ScoreDomain domain) => domains
      .firstWhere(
        (e) => e.domain == domain,
        orElse: () => DomainScore(domain: domain, score: 0, weight: 0),
      )
      .score;

  List<ScoreItemResult> get sortedByLost =>
      [...items]..sort((a, b) => b.lostPoints.compareTo(a.lostPoints));

  List<ScoreItemResult> get lowItems =>
      items.where((e) => e.status == ScoreStatus.low).toList();

  List<ScoreItemResult> get highItems => items
      .where((e) => e.status == ScoreStatus.high || e.status == ScoreStatus.veryHigh)
      .toList();

  Map<String, Object?> toJson() => {
        'date': date,
        'total': total,
        'interval': interval?.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        'domains': domains.map((e) => e.toJson()).toList(),
        'eligible': eligible,
        'eligibilityReasons': eligibilityReasons,
        'totals': totals,
        'groupTotals': groupTotals,
        'gates': gates.map((e) => e.toJson()).toList(),
        'topAction': topAction,
        'entryCount': entryCount,
        'algoVersion': algoVersion,
      };

  factory DayScore.fromJson(Map<String, Object?> json) => DayScore(
        date: asString(json['date']) ?? '1970-01-01',
        total: asDouble(json['total']),
        interval: json['interval'] == null
            ? null
            : Interval.fromJson(jsonMap(json['interval'])),
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => ScoreItemResult.fromJson(jsonMap(e)))
            .toList(),
        domains: (json['domains'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => DomainScore.fromJson(jsonMap(e)))
            .toList(),
        eligible: asBool(json['eligible']),
        eligibilityReasons: asStringList(json['eligibilityReasons']),
        totals: asDoubleMap(json['totals']),
        groupTotals: asDoubleMap(json['groupTotals']),
        gates: (json['gates'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => ScoreGate.fromJson(jsonMap(e)))
            .toList(),
        topAction: asString(json['topAction']) ?? '',
        entryCount: asInt(json['entryCount']) ?? 0,
        algoVersion: asInt(json['algoVersion']) ?? 1,
      );
}

class ScoreSnapshot {
  final String id;
  final String profileId;
  final String periodType;
  final String periodKey;
  final int algoVersion;
  final double score;
  final Interval? interval;
  final String grade;
  final Map<String, double> breakdown;
  final Map<String, double> totals;
  final int entryCount;
  final bool eligible;
  final int computedAt;

  const ScoreSnapshot({
    required this.id,
    required this.profileId,
    required this.periodType,
    required this.periodKey,
    required this.algoVersion,
    required this.score,
    this.interval,
    required this.grade,
    this.breakdown = const {},
    this.totals = const {},
    this.entryCount = 0,
    this.eligible = true,
    required this.computedAt,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'profileId': profileId,
        'periodType': periodType,
        'periodKey': periodKey,
        'algoVersion': algoVersion,
        'score': score,
        'interval': interval?.toJson(),
        'grade': grade,
        'breakdown': breakdown,
        'totals': totals,
        'entryCount': entryCount,
        'eligible': eligible,
        'computedAt': computedAt,
      };

  factory ScoreSnapshot.fromJson(Map<String, Object?> json) => ScoreSnapshot(
        id: asString(json['id']) ?? '',
        profileId: asString(json['profileId']) ?? '',
        periodType: asString(json['periodType']) ?? 'day',
        periodKey: asString(json['periodKey']) ?? '',
        algoVersion: asInt(json['algoVersion']) ?? 1,
        score: asDouble(json['score']) ?? 0,
        interval: json['interval'] == null
            ? null
            : Interval.fromJson(jsonMap(json['interval'])),
        grade: asString(json['grade']) ?? '',
        breakdown: asDoubleMap(json['breakdown']),
        totals: asDoubleMap(json['totals']),
        entryCount: asInt(json['entryCount']) ?? 0,
        eligible: asBool(json['eligible']),
        computedAt: asInt(json['computedAt']) ?? 0,
      );
}
