import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health/health_rules.dart';
import '../../core/models/enums.dart';
import '../../core/models/profile.dart';
import '../../core/models/settings.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../pet/pet_shop_page.dart';
import '../record/container_calibration_page.dart';
import '../settings/widgets/about_sheet.dart';
import '../settings/ai_settings_page.dart';
import '../settings/backup_page.dart';
import '../settings/settings_page.dart';
import '../settings/widgets/settings_widgets.dart';
import '../settings/widgets/theme_preview_card.dart';
import 'health_profile_page.dart';
import 'preferences_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final data = ref.watch(dataProvider);
    final settings = ref.watch(settingsProvider);
    final profile = data?.profile;
    final streak = ref.watch(streakProvider);
    final pet = ref.watch(activePetProvider);
    final name = (profile?.nickname.trim().isNotEmpty ?? false)
        ? profile!.nickname.trim()
        : '我';
    final preferenceCount = data?.activePreferences.length ?? 0;
    final ruleCount = HealthRules.forProfile(profile).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('我的', style: textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: '设置',
                    onPressed: () => _push(context, const SettingsPage()),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: t.surfaceAlt,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: t.hairline,
                                  width: t.borderWidth,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initial(name),
                                style: textTheme.headlineSmall?.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: textTheme.headlineSmall),
                                  const SizedBox(height: 4),
                                  Text(
                                    _metaLine(profile),
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '编辑健康档案',
                              onPressed: () =>
                                  _push(context, const HealthProfilePage()),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Pill(
                              '目标 ${profile?.goal.label ?? '待设置'}',
                              icon: Icons.flag_outlined,
                              color: t.ink,
                              filled: true,
                            ),
                            if (streak > 0)
                              Pill(
                                '连续 $streak 天',
                                icon: Icons.local_fire_department_outlined,
                                color: t.high,
                                filled: true,
                              )
                            else
                              Pill(
                                '尚未形成连续记录',
                                icon: Icons.local_fire_department_outlined,
                                color: t.inkTertiary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Hairline(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                icon: Icons.local_fire_department_outlined,
                                label: '连续记录',
                                value: '$streak 天',
                              ),
                            ),
                            _divider(context),
                            Expanded(
                              child: _Metric(
                                icon: Icons.pets_rounded,
                                label: '爪印',
                                value: '${pet?.coins ?? 0}',
                              ),
                            ),
                            _divider(context),
                            Expanded(
                              child: _Metric(
                                icon: Icons.favorite_outline_rounded,
                                label: '伙伴',
                                value: pet?.name ?? '—',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _StatusCard(
                          icon: Icons.auto_awesome_outlined,
                          label: 'AI',
                          value: _aiValue(settings),
                          hint: _aiHint(settings),
                          onTap: () => _push(context, const AiSettingsPage()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatusCard(
                          icon: Icons.tune_rounded,
                          label: '精度档',
                          value: settings.precision.label,
                          hint:
                              '误差约 ±${(settings.precision.relativeSpread * 100).round()}%',
                          onTap: () => _push(context, const SettingsPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(
                    '外观',
                    subtitle: '两套皮肤，语义色一致；点选立即生效',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ThemePreviewCard(
                          variant: ThemeVariant.editorial,
                          selected: settings.theme == ThemeVariant.editorial,
                          reduceMotion: settings.reduceMotion,
                          onTap: () => ref
                              .read(appStateProvider.notifier)
                              .setTheme(ThemeVariant.editorial),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ThemePreviewCard(
                          variant: ThemeVariant.q,
                          selected: settings.theme == ThemeVariant.q,
                          reduceMotion: settings.reduceMotion,
                          onTap: () =>
                              ref.read(appStateProvider.notifier).setTheme(ThemeVariant.q),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SettingsGroup(
                    title: '健康与偏好',
                    children: [
                      SettingsTile(
                        icon: Icons.favorite_outline_rounded,
                        title: '健康档案',
                        subtitle: profile == null
                            ? '填写后获得饮食提示'
                            : '性别、目标、过敏 · 当前 $ruleCount 条提示',
                        onTap: () => _push(context, const HealthProfilePage()),
                      ),
                      SettingsTile(
                        icon: Icons.restaurant_menu_rounded,
                        title: '食物偏好',
                        subtitle: '$preferenceCount 条 · 5 星、不吃与过敏',
                        onTap: () => _push(context, const PreferencesPage()),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: '工具',
                    children: [
                      SettingsTile(
                        icon: Icons.storefront_outlined,
                        title: '宠物商店',
                        subtitle: '爪印 ${pet?.coins ?? 0} · 皮肤与伙伴',
                        onTap: () => _push(context, const PetShopPage()),
                      ),
                      SettingsTile(
                        icon: Icons.coffee_outlined,
                        title: '容器标定',
                        subtitle: '标定碗杯，份量估算更稳',
                        onTap: () =>
                            _push(context, const ContainerCalibrationPage()),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: '应用',
                    children: [
                      SettingsTile(
                        icon: Icons.settings_outlined,
                        title: '设置',
                        subtitle: '主题、精度、减少动态',
                        onTap: () => _push(context, const SettingsPage()),
                      ),
                      SettingsTile(
                        icon: Icons.archive_outlined,
                        title: '备份',
                        subtitle: '导出 / 导入 JSON · 建议每周一次',
                        onTap: () => _push(context, const BackupPage()),
                      ),
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: '关于与免责声明',
                        subtitle: '版本 $appVersion · 误差与边界',
                        onTap: () => showAboutSheet(context),
                      ),
                    ],
                  ),
                  const InfoNote(
                    icon: Icons.shield_outlined,
                    title: '本地优先',
                    text: '没有账号，也不做云同步。档案、记录与偏好只在这台设备；'
                        '卸载或清理浏览器数据前请先导出备份。',
                  ),
                  const SizedBox(height: 12),
                  const AppDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '我';
    return String.fromCharCode(trimmed.runes.first);
  }

  static String _metaLine(HealthProfile? profile) {
    if (profile == null) return '档案待完善';
    final parts = <String>[];
    if (profile.sex != Sex.preferNot) parts.add(profile.sex.label);
    final age = profile.age;
    if (age != null && age > 0 && age < 130) parts.add('$age 岁');
    if (profile.heightCm != null) {
      parts.add('${_formatDimension(profile.heightCm!)} cm');
    }
    if (profile.weightKg != null) {
      parts.add('${_formatDimension(profile.weightKg!)} kg');
    }
    return parts.isEmpty ? '档案待完善，补两句更贴合' : parts.join(' · ');
  }

  static String _formatDimension(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  static String _aiValue(AppSettings settings) {
    if (settings.localOnly) return '本地模式';
    if (settings.aiEnabled && settings.hasAiKey) return '已配置';
    return '未配置';
  }

  static String _aiHint(AppSettings settings) {
    if (settings.localOnly) return '不发送数据 · 本地规则';
    if (settings.aiEnabled && settings.hasAiKey) return settings.aiModel;
    if (settings.aiEnabled) return '缺少 API key';
    return '本地规则可用';
  }

  static Widget _divider(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: t.borderWidth,
      height: 34,
      color: t.hairline,
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: t.inkTertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return PressableScale(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: t.inkSecondary),
                const SizedBox(width: 5),
                Expanded(child: Text(label, style: textTheme.labelSmall)),
                Icon(Icons.chevron_right_rounded, size: 15, color: t.inkTertiary),
              ],
            ),
            const SizedBox(height: 7),
            Text(value, style: textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
