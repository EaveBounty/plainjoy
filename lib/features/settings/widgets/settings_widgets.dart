import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';

/// A titled group of settings rows sharing one bordered surface.
class SettingsGroup extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Hairline(indent: 16));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, subtitle: subtitle),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusLg),
              boxShadow: t.isQ
                  ? [
                      BoxShadow(
                        color: t.hardShadowColor.withValues(alpha: 0.12),
                        offset: t.hardShadowOffset,
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: t.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusLg),
                side: BorderSide(color: t.hairline, width: t.borderWidth),
              ),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row inside a [SettingsGroup].
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showChevron;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: t.hairline, width: t.borderWidth),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? t.inkSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null && showChevron)
            Icon(Icons.chevron_right_rounded, color: t.inkTertiary, size: 20),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// A quiet inline note for privacy, cost and safety copy.
class InfoNote extends StatelessWidget {
  final String text;
  final String? title;
  final IconData icon;
  final Color? color;

  const InfoNote({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final c = color ?? t.inkSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.hairline, width: t.borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: textTheme.titleSmall?.copyWith(color: c),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(text, style: textTheme.bodySmall?.copyWith(color: t.inkSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Short, non-medical disclaimer reused across profile and settings.
class AppDisclaimer extends StatelessWidget {
  const AppDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoNote(
      icon: Icons.medical_information_outlined,
      title: '免责声明',
      text: '清欢不是医疗器械，不提供诊断、处方或治疗方案。营养数值为估算，存在误差；'
          '「需就医」是就医提示，不是诊断结论。如有急症或明显症状，请及时就医。',
    );
  }
}
