import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/entry.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/settings.dart';

class AiParseItem {
  final String name;
  final String? foodId;
  final double gramsP10;
  final double gramsP50;
  final double gramsP90;
  final double confidence;
  final String category;

  /// 已解析到的本地食物；匹配不到时可能是 AI 现场估算的合成食物。
  final Food? food;

  /// local | ai_estimate | null（未解析）
  final String? nutrientSource;

  const AiParseItem({
    required this.name,
    this.foodId,
    required this.gramsP10,
    required this.gramsP50,
    required this.gramsP90,
    required this.confidence,
    this.category = 'other',
    this.food,
    this.nutrientSource,
  });
}

class AiParseResult {
  final List<AiParseItem> items;
  final String? error;
  final bool usedAi;
  final int? inputTokens;
  final int? outputTokens;

  const AiParseResult({
    required this.items,
    this.error,
    this.usedAi = false,
    this.inputTokens,
    this.outputTokens,
  });

  bool get ok => items.isNotEmpty;
}

class AiService {
  final AppSettings settings;
  final List<Food> foods;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  AiService({
    required this.settings,
    required this.foods,
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get enabled => settings.aiEnabled && settings.hasAiKey && !settings.localOnly;

  Future<AiParseResult> parseText(String text) async {
    if (text.trim().isEmpty) {
      return const AiParseResult(items: [], error: '没有可解析的文字');
    }
    if (!enabled) {
      return _localParse(text);
    }
    try {
      final body = {
        'model': settings.aiModel,
        'messages': [
          {'role': 'system', 'content': _systemPrompt()},
          {'role': 'user', 'content': text.trim()},
        ],
        'response_format': {'type': 'json_object'},
        'thinking': {'type': 'disabled'},
        'temperature': 0.1,
        'max_tokens': 1600,
      };
      final response = await _post(body);
      return _parseResponse(response, fallbackText: text);
    } catch (e) {
      final fallback = _localParse(text);
      return AiParseResult(
        items: fallback.items,
        error: 'AI 解析失败，已用本地规则：$e',
        usedAi: false,
      );
    }
  }

  Future<AiParseResult> parseImage({
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (!enabled) {
      return const AiParseResult(items: [], error: '未启用 AI 或没有 API key；先用文字记录，或到设置里填入 DeepSeek key。');
    }
    try {
      final base64Image = base64Encode(bytes);
      final body = {
        'model': settings.aiModel,
        'messages': [
          {'role': 'system', 'content': _systemPrompt()},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': '识别这张餐食照片里的食物和大致份量。只输出 JSON。'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
              },
            ],
          },
        ],
        'response_format': {'type': 'json_object'},
        'thinking': {'type': 'disabled'},
        'temperature': 0.1,
        'max_tokens': 1600,
      };
      final response = await _post(body);
      return _parseResponse(response, fallbackText: '');
    } catch (e) {
      return AiParseResult(items: const [], error: '图片识别失败：$e');
    }
  }

  Future<Map<String, Object?>> _post(Map<String, Object?> body) async {
    final base = settings.aiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.aiApiKey.trim()}',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = response.body.length > 300 ? response.body.substring(0, 300) : response.body;
      throw Exception('HTTP ${response.statusCode}: $msg');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw Exception('返回格式不正确');
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  AiParseResult _parseResponse(Map<String, Object?> response, {required String fallbackText}) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) {
      return AiParseResult(items: _localParse(fallbackText).items, error: 'AI 返回为空', usedAi: true);
    }
    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content']?.toString() ?? '' : '';
    final parsed = _extractJson(content);
    if (parsed == null) {
      return AiParseResult(items: _localParse(fallbackText).items, error: 'AI 返回不是 JSON', usedAi: true);
    }
    final rawItems = parsed['items'];
    if (rawItems is! List) {
      return const AiParseResult(items: [], error: 'AI 没有返回食物条目', usedAi: true);
    }
    final items = <AiParseItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final p50 = _double(raw['grams']) ?? _double(raw['grams_p50']) ?? 100;
      final p10 = _double(raw['grams_min']) ?? p50 * 0.7;
      final p90 = _double(raw['grams_max']) ?? p50 * 1.3;
      var food = _matchFood(name);
      String? source = food == null ? null : 'local';

      // 本地库查不到时，接受 AI 给出的每 100 g 营养，但必须过值域校验，
      // 并明确标记为 ai_estimate，UI 会显示「AI 估算」。
      if (food == null) {
        final aiNutrients = _sanitizeNutrients(raw['nutrients_per_100g']);
        if (aiNutrients.isNotEmpty) {
          food = Food(
            id: 'ai-${_uuid.v7()}',
            name: name,
            category: _normalizeCategory(raw['category']?.toString()),
            source: 'ai_estimate',
            sourceRef: 'vision-json',
            nutrientsPer100g: aiNutrients,
            groupsPer100g: _groupsFor(_normalizeCategory(raw['category']?.toString())),
            isVerified: false,
            tags: const ['ai_estimate'],
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          source = 'ai_estimate';
        }
      }

      items.add(AiParseItem(
        name: food?.name ?? name,
        foodId: food?.id,
        food: food,
        nutrientSource: source,
        gramsP10: min(p10, p50),
        gramsP50: p50,
        gramsP90: max(p90, p50),
        confidence: (_double(raw['confidence']) ?? 0.5).clamp(0.1, 0.95),
        category: food?.category ?? _normalizeCategory(raw['category']?.toString()),
      ));
    }
    final usage = response['usage'];
    return AiParseResult(
      items: items,
      usedAi: true,
      inputTokens: usage is Map ? _int(usage['prompt_tokens']) : null,
      outputTokens: usage is Map ? _int(usage['completion_tokens']) : null,
    );
  }

  Map<String, Object?>? _extractJson(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?'), '').replaceFirst(RegExp(r'```$'), '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    return null;
  }

  AiParseResult _localParse(String text) {
    final items = <AiParseItem>[];
    final segments = text
        .split(RegExp(r'[，。；;、\n\r\t,+！!？?]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final segment in segments) {
      final food = _matchFood(segment);
      if (food == null) continue;
      final grams = _extractGrams(segment) ?? food.defaultServingGrams ?? _defaultGrams(food.category);
      final spread = 0.35;
      items.add(AiParseItem(
        name: food.name,
        foodId: food.id,
        gramsP10: grams * (1 - spread),
        gramsP50: grams,
        gramsP90: grams * (1 + spread),
        confidence: 0.4,
        category: food.category,
      ));
    }
    if (items.isEmpty) {
      return const AiParseResult(items: [], error: '没匹配到食物，试试「番茄炒蛋 200g + 米饭一碗」。');
    }
    return AiParseResult(items: items, usedAi: false);
  }

  Food? _matchFood(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return null;
    Food? best;
    var bestScore = 0;
    for (final food in foods) {
      final candidates = [food.name, ...food.aliases];
      for (final candidate in candidates) {
        final c = candidate.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (c.isEmpty) continue;
        if (normalized == c) return food;
        if (normalized.contains(c)) {
          final score = c.length;
          if (score > bestScore) {
            best = food;
            bestScore = score;
          }
        }
      }
    }
    return best;
  }

  double? _extractGrams(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(g|克|ml|毫升)').firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    if ((match.group(2) ?? '').contains('ml') || (match.group(2) ?? '').contains('毫升')) {
      return value;
    }
    return value;
  }

  double _defaultGrams(String category) => switch (category) {
        'staple' => 150,
        'vegetable' => 100,
        'fruit' => 150,
        'meat' => 80,
        'fish' => 80,
        'egg' => 50,
        'dairy' => 200,
        'bean' => 100,
        'nut' => 10,
        'dish' => 200,
        'drink' => 250,
        _ => 100,
      };

  String _systemPrompt() {
    return '''
你是「清欢」的餐食解析器。把用户的中文描述或餐食照片解析成 JSON，只输出 JSON，不要解释、不要 Markdown。

输出格式：
{"items":[{
 "name":"食物名",
 "grams":150,"grams_min":110,"grams_max":190,
 "confidence":0.6,
 "category":"staple|vegetable|fruit|meat|fish|egg|dairy|bean|nut|dish|drink|condiment|snack|other",
 "ingredients":[{"name":"番茄","grams":120}],
 "seasonings":[{"name":"生抽","grams":5}],
 "nutrients_per_100g":{"energy_kcal":0,"protein_g":0,"fat_g":0,"carb_g":0,"fiber_g":0,"sodium_mg":0,"potassium_mg":0,"calcium_mg":0,"iron_mg":0,"va_ug":0,"vc_mg":0,"sugar_g":0,"sfa_g":0},
 "nutrient_source":"ai_estimate"
}]}

规则：
1. grams 是克重中位数；grams_min/max 是合理区间。用户说“一碗/一盘/一份”时 confidence 降到 0.4–0.6，不要假装精确。
2. 复合菜（番茄炒蛋、青椒肉丝）先给整份，再在 ingredients 里拆主料；拆不出的就不要硬拆。
3. 调味品必须单独成条：盐、生抽、老抽、蚝油、味精、鸡精、豆瓣酱、甜面酱、油。中餐隐形钠主要在这里；不知道用量时给 3–10 g 区间。
4. 只有本地库查不到的菜，才填 nutrients_per_100g；用中国食物成分表口径，每 100 g。查得到的菜 nutrient_source 留空，app 会用本地值覆盖。
5. nutrients_per_100g 必须是数字，不确定就省略该字段；不要编造碘、维 D、B12、叶酸、嘌呤。
6. 多份食物拆成多条；无法识别输出 {"items":[]}。
''';
  }

  String _normalizeCategory(String? raw) {
    const allowed = {
      'staple', 'vegetable', 'fruit', 'meat', 'fish', 'egg', 'dairy',
      'bean', 'nut', 'dish', 'drink', 'condiment', 'snack', 'oil', 'other',
    };
    final value = raw?.trim().toLowerCase();
    return value != null && allowed.contains(value) ? value : 'other';
  }

  Map<String, double> _sanitizeNutrients(Object? raw) {
    if (raw is! Map) return const {};
    const ranges = <String, (double, double)>{
      'energy_kcal': (0, 900),
      'protein_g': (0, 100),
      'fat_g': (0, 100),
      'carb_g': (0, 100),
      'fiber_g': (0, 60),
      'sodium_mg': (0, 40000),
      'potassium_mg': (0, 5000),
      'calcium_mg': (0, 3000),
      'iron_mg': (0, 100),
      'va_ug': (0, 20000),
      'vc_mg': (0, 3000),
      'sugar_g': (0, 100),
      'sfa_g': (0, 100),
    };
    final out = <String, double>{};
    for (final entry in ranges.entries) {
      final value = _double(raw[entry.key]);
      if (value == null) continue;
      if (value < entry.value.$1 || value > entry.value.$2) continue;
      out[entry.key] = value;
    }
    return out;
  }

  Map<String, double> _groupsFor(String category) => switch (category) {
        'vegetable' => const {'veg': 100},
        'fruit' => const {'fruit': 100},
        'dairy' => const {'dairy': 100},
        'bean' || 'nut' => const {'soy_nut': 100},
        'meat' || 'egg' => const {'animal_protein': 100},
        'fish' => const {'animal_protein': 100, 'fish': 100},
        'staple' => const {'refined_grain': 100},
        _ => const {},
      };

  double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<EntryItem> toEntryItems(AiParseResult result, Map<String, Food> foodById) {
    final out = <EntryItem>[];
    for (var i = 0; i < result.items.length; i++) {
      final item = result.items[i];
      final food = item.food ?? (item.foodId == null ? null : foodById[item.foodId]);
      if (food == null) continue;
      out.add(EntryItem.fromFood(
        id: _uuid.v7(),
        food: food,
        gramsP10: item.gramsP10,
        gramsP50: item.gramsP50,
        gramsP90: item.gramsP90,
        method: result.usedAi ? EstimateMethod.ai : EstimateMethod.visual,
        confidence: item.confidence,
        position: i,
      ));
    }
    return out;
  }
}
