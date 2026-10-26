double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? asString(Object? value) => value?.toString();

bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  return value.toString() == 'true';
}

List<String> asStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

Map<String, double> asDoubleMap(Object? value) {
  if (value is Map) {
    final out = <String, double>{};
    value.forEach((key, val) {
      final d = asDouble(val);
      if (d != null) out[key.toString()] = d;
    });
    return out;
  }
  return const {};
}

Map<String, int> asIntMap(Object? value) {
  if (value is Map) {
    final out = <String, int>{};
    value.forEach((key, val) {
      final i = asInt(val);
      if (i != null) out[key.toString()] = i;
    });
    return out;
  }
  return const {};
}

Map<String, Object?> jsonMap(Object? value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
