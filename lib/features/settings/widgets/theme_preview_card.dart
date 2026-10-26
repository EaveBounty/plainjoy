import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

/// A live mini preview of one visual theme. Tapping selects that theme.
class ThemePreviewCard extends StatelessWidget {
  final ThemeVariant variant;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  const ThemePreviewCard({
    super.key,
    required this.variant,
    required this.selected,
    required this.onTap,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final outer = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final previewTheme = variant == ThemeVariant.q ? AppTheme.q() : AppTheme.editorial();
    final duration = MediaQuery.of(context).disableAnimations || reduceMotion
        ? Duration.zero
        : Duration(milliseconds: outer.motionMs.toInt());

    return Semantics(
      button: true,
      selected: selected,
      label: '${variant.label}主题：${variant.description}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: outer.motionCurve,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: selected ? outer.accent : outer.accent.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(outer.radiusLg + 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(outer.radiusLg),
                child: Theme(
                  data: previewTheme,
                  child: Builder(
                    builder: (inner) {
                      final t = inner.tokens;
                      return MediaQuery(
                        data: MediaQuery.of(inner).copyWith(
                          textScaler: TextScaler.noScaling,
                        ),
                        child: Container(
                          height: 132,
                          width: double.infinity,
                          color: t.background,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: t.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '示意',
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: t.inkSecondary,
                                        fontFamily: t.bodyFont,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '82',
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      color: t.ink,
                                      fontFamily: t.titleFont,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '/100',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: t.inkTertiary,
                                      fontFamily: t.bodyFont,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(t.pillRadius),
                                child: Container(
                                  height: 5,
                                  color: t.surfaceAlt,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: 0.72,
                                    child: Container(color: t.good),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: t.surface,
                                  borderRadius: BorderRadius.circular(t.radiusSm),
                                  border: Border.all(color: t.hairline, width: t.borderWidth),
                                ),
                                child: Text(
                                  '今天差一口蔬菜',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: t.ink,
                                    fontFamily: t.bodyFont,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  _dot(t.good),
                                  const SizedBox(width: 4),
                                  _dot(t.low),
                                  const SizedBox(width: 4),
                                  _dot(t.high),
                                  const Spacer(),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: t.accent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(variant.label, style: textTheme.titleSmall),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 16, color: outer.accent),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              variant.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
