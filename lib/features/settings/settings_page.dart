import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/settings.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'widgets/about_sheet.dart';
import 'ai_settings_page.dart';
import 'backup_page.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/theme_preview_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const PageHeader(
              title: '设置',
              subtitle: '外观、精度与数据',
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    '外观',
                    subtitle: '两套皮肤，语义色不变；切换立即生效',
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
                  const SectionTitle(
                    '记录精度',
                    subtitle: '默认的份量输入方式，可随时切换',
                  ),
                  for (final tier in PrecisionTier.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PrecisionTile(
                        tier: tier,
                        selected: settings.precision == tier,
                        reduceMotion: settings.reduceMotion,
                        onTap: () =>
                            ref.read(appStateProvider.notifier).setPrecision(tier),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SettingsGroup(
                    title: '体验',
                    children: [
                      SettingsTile(
                        icon: Icons.animation_rounded,
                        title: '减少动态',
                        subtitle: '关闭大部分过渡与宠物动画',
                        trailing: Switch(
                          value: settings.reduceMotion,
                          onChanged: (value) => ref
                              .read(appStateProvider.notifier)
                              .setReduceMotion(value),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'AI 与数据',
                    children: [
                      SettingsTile(
                        icon: Icons.auto_awesome_outlined,
                        title: 'AI 设置',
                        subtitle: _aiSubtitle(settings),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AiSettingsPage(),
                          ),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.archive_outlined,
                        title: '备份与恢复',
                        subtitle: '本地优先，无账号 · 建议每周导出一次',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BackupPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: '关于',
                    children: [
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: '关于清欢',
                        subtitle: '版本 $appVersion · 免责声明与误差说明',
                        onTap: () => showAboutSheet(context),
                      ),
                    ],
                  ),
                  const InfoNote(
                    icon: Icons.shield_outlined,
                    title: '本地优先',
                    text: '没有账号，也不做云同步。档案、记录和偏好只保存在这台设备；'
                        '卸载应用或清理浏览器数据会丢失，请定期导出备份。',
                  ),
                  const SizedBox(height: 12),
                  const AppDisclaimer(),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      '清欢 $appVersion',
                      style: textTheme.labelSmall?.copyWith(color: t.inkTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _aiSubtitle(AppSettings settings) {
    if (settings.localOnly) return '本地模式 · 不发送任何数据';
    if (!settings.aiEnabled) return '未启用 · 本地规则完整可用';
    if (!settings.hasAiKey) return '已启用 · 缺少 API key';
    return '已配置 · ${settings.aiModel}';
  }
}

class _PrecisionTile extends StatelessWidget {
  final PrecisionTier tier;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _PrecisionTile({
    required this.tier,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      color: selected ? t.surfaceAlt : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations || reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? t.accent : t.accent.withValues(alpha: 0),
              border: Border.all(
                color: selected ? t.accent : t.inkTertiary,
                width: selected ? 6 : t.borderWidth,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.label, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(tier.hint, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, size: 18, color: t.accent),
        ],
      ),
    );
  }
}
