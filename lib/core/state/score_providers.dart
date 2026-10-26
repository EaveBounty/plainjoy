import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry.dart';
import '../models/score.dart';
import '../pet/pet_state_service.dart';
import '../scoring/score_aggregator.dart';
import '../scoring/score_engine.dart';
import '../util/date_utils.dart';
import 'app_state.dart';

final todayScoreProvider = Provider<DayScore>((ref) {
  final data = ref.watch(dataProvider);
  final date = todayKey();
  if (data == null) {
    return ScoreEngine.computeDay(date: date, entries: const [], profile: null);
  }
  return ScoreEngine.computeDay(
    date: date,
    entries: data.entriesForDate(date),
    profile: data.profile,
  );
});

final dayScoreProvider = Provider.family<DayScore, String>((ref, date) {
  final data = ref.watch(dataProvider);
  if (data == null) {
    return ScoreEngine.computeDay(date: date, entries: const [], profile: null);
  }
  return ScoreEngine.computeDay(
    date: date,
    entries: data.entriesForDate(date),
    profile: data.profile,
  );
});

final todayEntriesProvider = Provider<List<FoodEntry>>((ref) {
  final data = ref.watch(dataProvider);
  return data?.entriesForDate(todayKey()) ?? const [];
});

final last7ScoresProvider = Provider<List<DayScore>>((ref) {
  final today = parseDateKey(todayKey());
  return List.generate(7, (i) {
    final date = dateKey(today.subtract(Duration(days: 6 - i)));
    return ref.watch(dayScoreProvider(date));
  });
});

final last30ScoresProvider = Provider<List<DayScore>>((ref) {
  final today = parseDateKey(todayKey());
  return List.generate(30, (i) {
    final date = dateKey(today.subtract(Duration(days: 29 - i)));
    return ref.watch(dayScoreProvider(date));
  });
});

final weekScoreProvider = Provider<PeriodScore>((ref) {
  final scores = ref.watch(last7ScoresProvider);
  final last30 = ref.watch(last30ScoresProvider);
  final previous = last30.take(23).where((e) => e.eligible && e.total != null).toList();
  final baseline = previous.isEmpty
      ? 60.0
      : previous.map((e) => e.total!).reduce((a, b) => a + b) / previous.length;
  return ScoreAggregator.week(
    weekKey: weekKey(scores.last.date),
    label: '最近 7 天',
    days: scores,
    baseline28: baseline,
  );
});

final monthScoreProvider = Provider<PeriodScore>((ref) {
  final scores = ref.watch(last30ScoresProvider);
  final weeks = <PeriodScore>[];
  for (var i = 0; i < 4; i++) {
    final slice = scores.sublist(i * 7, i * 7 + 7);
    weeks.add(ScoreAggregator.week(
      weekKey: weekKey(slice.last.date),
      label: '第 ${i + 1} 周',
      days: slice,
    ));
  }
  return ScoreAggregator.month(
    monthKey: monthKey(todayKey()),
    label: '最近 30 天',
    weeks: weeks,
    days: scores,
  );
});

final streakProvider = Provider<int>((ref) {
  final data = ref.watch(dataProvider);
  if (data == null) return 0;
  var count = 0;
  var date = parseDateKey(todayKey());
  for (var i = 0; i < 365; i++) {
    final key = dateKey(date);
    final score = ref.watch(dayScoreProvider(key));
    if (score.eligible && (score.total ?? 0) >= 70) {
      count++;
      date = date.subtract(const Duration(days: 1));
    } else if (i == 0) {
      date = date.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return count;
});

final petStateProvider = Provider<PetStateResult>((ref) {
  final scores = ref.watch(last7ScoresProvider);
  final streak = ref.watch(streakProvider);
  return PetStateService.compute(last7: scores, streakDays: streak);
});

final weekDaysProvider = Provider<List<DayScore>>((ref) {
  final today = parseDateKey(todayKey());
  return List.generate(7, (i) {
    final date = dateKey(today.subtract(Duration(days: 6 - i)));
    return ref.watch(dayScoreProvider(date));
  });
});
