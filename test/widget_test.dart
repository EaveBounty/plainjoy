import 'package:flutter_test/flutter_test.dart';
import 'package:plainjoy/core/models/enums.dart';
import 'package:plainjoy/core/models/profile.dart';
import 'package:plainjoy/core/scoring/nutrient_targets.dart';

void main() {
  test('targets are sane for a default profile', () {
    const profile = HealthProfile(
      id: 'test',
      nickname: '测试',
      sex: Sex.female,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
    );
    final targets = NutrientTargets.fromProfile(profile);
    expect(targets.energy, greaterThan(1200));
    expect(targets.protein, greaterThanOrEqualTo(55));
    expect(targets.sodiumOk, 2000);
    expect(targets.iron, 18);
    expect(targets.vegetable, 300);
  });
}
