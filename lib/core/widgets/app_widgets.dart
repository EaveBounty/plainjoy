import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? radius;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = radius ?? t.radiusLg;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(r),
        border: showBorder ? Border.all(color: t.hairline, width: t.borderWidth) : null,
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
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: content,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;

  const Pill(this.text, {super.key, this.color, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.inkSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusSm),
        border: Border.all(color: filled ? Colors.transparent : t.hairline, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final double? score;
  final double size;
  final String label;
  final Color? color;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 96,
    this.label = '总分',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = score;
    final c = color ?? (value == null ? t.unknown : _colorFor(value, t));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (value ?? 0) / 100),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : Duration(milliseconds: t.motionMs.toInt() + 260),
      curve: t.motionCurve,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: animated,
                  strokeWidth: t.isQ ? 9 : 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: t.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(c),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value == null ? '—' : value.round().toString(),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: c,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _colorFor(double score, AppTokens t) {
    if (score >= 85) return t.good;
    if (score >= 70) return t.ink;
    if (score >= 55) return t.high;
    return t.veryHigh;
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: t.hairline, width: t.borderWidth),
              ),
              child: Icon(icon, color: t.inkSecondary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableScale({super.key, required this.child, this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Duration(milliseconds: t.isQ ? 90 : 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  final double? indent;
  const Hairline({super.key, this.indent});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: t.borderWidth,
      margin: EdgeInsets.only(left: indent ?? 0),
      color: t.hairline,
    );
  }
}
