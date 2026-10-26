import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'widgets/settings_widgets.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  static const _presets = <String>['deepseek-flash', 'deepseek-v4-pro'];

  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _key;
  late bool _enabled;
  late bool _localOnly;
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  String? _feedback;
  bool _feedbackOk = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _baseUrl = TextEditingController(text: settings.aiBaseUrl);
    _model = TextEditingController(text: settings.aiModel);
    _key = TextEditingController(text: settings.aiApiKey);
    _enabled = settings.aiEnabled;
    _localOnly = settings.localOnly;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  String _sanitizeKey(String raw) {
    var value = raw.replaceAll(RegExp(r'[\u200B\uFEFF]'), '').trim();
    if (value.toLowerCase().startsWith('bearer')) {
      value = value.substring(6).trim();
    }
    value = value.replaceAll(RegExp(r'''^["']+|["']+$'''), '');
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  String _mask(String raw) {
    final key = _sanitizeKey(raw);
    if (key.isEmpty) return '';
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 3)}••••••${key.substring(key.length - 4)}';
  }

  String _normalizedBaseUrl() {
    final raw = _baseUrl.text.trim();
    if (raw.isEmpty) return 'https://api.deepseek.com';
    return raw.replaceFirst(RegExp(r'/+$'), '');
  }

  String _normalizedModel() {
    final raw = _model.text.trim();
    return raw.isEmpty ? 'deepseek-flash' : raw;
  }

  bool _validBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _setFeedback(String text, {required bool ok}) {
    setState(() {
      _feedback = text;
      _feedbackOk = ok;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final key = _sanitizeKey(_key.text);
    final baseUrl = _normalizedBaseUrl();
    final model = _normalizedModel();
    if (!_validBaseUrl(baseUrl)) {
      _setFeedback('Base URL 需要以 http:// 或 https:// 开头。', ok: false);
      return;
    }
    if (_enabled && !_localOnly && key.isEmpty) {
      _setFeedback('启用 AI 需要填写 API key；也可以先打开「本地模式」只跑本地规则。', ok: false);
      return;
    }
    setState(() => _saving = true);
    _baseUrl.text = baseUrl;
    _model.text = model;
    _key.text = key;
    try {
      await ref.read(appStateProvider.notifier).setAi(
            enabled: _enabled,
            apiKey: key,
            baseUrl: baseUrl,
            model: model,
            localOnly: _localOnly,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      _setFeedback(
        _localOnly && _enabled
            ? '已保存。本地模式仍开启，关闭后 AI 才会联网。'
            : '已保存。',
        ok: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _setFeedback('保存失败：$error', ok: false);
    }
  }

  Future<void> _confirmTest() async {
    FocusScope.of(context).unfocus();
    final key = _sanitizeKey(_key.text);
    final baseUrl = _normalizedBaseUrl();
    if (key.isEmpty) {
      _setFeedback('先填写 API key，再测试连接。', ok: false);
      return;
    }
    if (!_validBaseUrl(baseUrl)) {
      _setFeedback('Base URL 需要以 http:// 或 https:// 开头。', ok: false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('测试连接'),
        content: Text(
          '将向 $baseUrl 发送「一个鸡蛋」用于解析测试，不包含健康档案。\n\n'
          '单次约 ¥0.003 以内（deepseek-flash 文本），从你填写的 API key 对应账户扣费。\n\n'
          '测试不会保存表单。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('发送测试'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runTest(key: key, baseUrl: baseUrl, model: _normalizedModel());
  }

  Future<void> _runTest({
    required String key,
    required String baseUrl,
    required String model,
  }) async {
    setState(() {
      _testing = true;
      _feedback = null;
    });
    final settings = ref.read(settingsProvider).copyWith(
          aiEnabled: true,
          aiApiKey: key,
          aiBaseUrl: baseUrl,
          aiModel: model,
          localOnly: false,
        );
    try {
      final service = AiService(
        settings: settings,
        foods: ref.read(foodsProvider),
      );
      final result = await service.parseText('一个鸡蛋');
      if (!mounted) return;
      if (result.error != null) {
        setState(() => _testing = false);
        _setFeedback('连接失败：${_shortError(result.error!)}', ok: false);
      } else if (result.items.isEmpty) {
        setState(() => _testing = false);
        _setFeedback('连接成功，但没有解析出食物条目。可以检查模型名或 Base URL。', ok: false);
      } else {
        final source = result.usedAi ? model : '本地规则';
        setState(() => _testing = false);
        _setFeedback(
          '连接成功：返回 ${result.items.length} 项（$source）。测试未保存设置。',
          ok: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _testing = false);
      _setFeedback('连接失败：${_shortError('$error')}', ok: false);
    }
  }

  static String _shortError(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final busy = _saving || _testing;
    final masked = _mask(_key.text);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const PageHeader(
              title: 'AI 设置',
              subtitle: '可选增强；不配置也能完整使用',
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoNote(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI 只做一件事',
                    text: '把食物文字或照片转成食物条目。营养数字来自本地食物库，评分和健康规则不经过模型。'
                        '无 key、无网或失败时都会回退到本地规则。',
                  ),
                  const SizedBox(height: 20),
                  SettingsGroup(
                    title: '开关',
                    children: [
                      SettingsTile(
                        icon: Icons.bolt_rounded,
                        title: '启用 AI',
                        subtitle: '无 key 或请求失败时自动回退本地规则',
                        trailing: Switch(
                          value: _enabled,
                          onChanged: busy ? null : (value) => setState(() => _enabled = value),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.wifi_off_rounded,
                        title: '本地模式',
                        subtitle: '不发送任何数据；照片识别不可用',
                        trailing: Switch(
                          value: _localOnly,
                          onChanged: busy
                              ? null
                              : (value) => setState(() => _localOnly = value),
                        ),
                      ),
                    ],
                  ),
                  if (_localOnly && _enabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: InfoNote(
                        icon: Icons.shield_outlined,
                        color: t.good,
                        title: '本地模式优先',
                        text: '即使启用了 AI，本地模式开启时也不会发起网络请求。需要联网解析时请关闭本地模式。',
                      ),
                    ),
                  const SectionTitle(
                    '连接',
                    subtitle: '兼容 OpenAI 格式的 /chat/completions',
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _baseUrl,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Base URL',
                            hintText: 'https://api.deepseek.com',
                            helperText: '使用代理或自建网关时才需要修改',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('模型', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in _presets)
                              ChoiceChip(
                                label: Text(preset),
                                selected: _model.text.trim() == preset,
                                showCheckmark: false,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() => _model.text = preset),
                                selectedColor: t.accent,
                                backgroundColor: t.surface,
                                side: BorderSide(
                                  color: _model.text.trim() == preset ? t.accent : t.hairline,
                                  width: t.borderWidth,
                                ),
                                labelStyle: textTheme.labelMedium?.copyWith(
                                  color: _model.text.trim() == preset ? t.accentInk : t.ink,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    t.isQ ? t.pillRadius : t.radiusSm,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _model,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '模型名称',
                            hintText: 'deepseek-flash',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _key,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'API key',
                            hintText: 'sk-...',
                            helperText: '粘贴后会自动去除空格、换行、引号与 Bearer 前缀',
                            helperMaxLines: 2,
                            suffixIcon: IconButton(
                              tooltip: _obscure ? '显示 key' : '隐藏 key',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.key_rounded, size: 14, color: t.inkTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                masked.isEmpty ? '当前 key：未填写' : '当前 key：$masked',
                                style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 12),
                    InfoNote(
                      icon: _feedbackOk
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: _feedbackOk ? t.good : t.veryHigh,
                      title: _feedbackOk ? '成功' : '失败',
                      text: _feedback!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accentInk,
                            ),
                          )
                        : const Text('保存设置'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _confirmTest,
                    icon: Icon(Icons.bolt_rounded, size: 18, color: t.ink),
                    label: Text(_testing ? '测试中…' : '测试连接（发送「一个鸡蛋」）'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '测试会发起一次真实请求，不会保存表单；只发送测试文字，不发送健康档案。',
                    style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle('成本与隐私'),
                  const InfoNote(
                    icon: Icons.payments_outlined,
                    title: '费用',
                    text: '文本解析单次约 ¥0.003（deepseek-flash），照片解析更高；'
                        '费用从你填写的 DeepSeek 账户扣除。建议月预算 ≤ ¥10，并在 DeepSeek 控制台设置额度。',
                  ),
                  const SizedBox(height: 10),
                  const InfoNote(
                    icon: Icons.privacy_tip_outlined,
                    title: '只发食物',
                    text: '只发送食物描述或餐食照片，不发送健康档案、疾病、用药、体重或偏好表。'
                        '请求从本机直接发往你填写的 Base URL。',
                  ),
                  const SizedBox(height: 10),
                  const InfoNote(
                    icon: Icons.computer_rounded,
                    title: '密钥保存',
                    text: '当前版本的 API key 与设置一起保存在本机应用数据中（未加密）；'
                        'Web 端保存在浏览器本地存储。共用设备请用后清空 key，不要截图分享设置页。',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '没有 API key 时，文字记录仍可用本地别名和模糊匹配；完整功能不依赖 AI。',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
