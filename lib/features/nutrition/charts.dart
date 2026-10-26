import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/score.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';

/// 动画降级：Android「移除动画」与 iOS「减弱动态效果」都要查。
bool appReduceMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations ||
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;

Duration appMotion(BuildContext context, int ms) =>
    appReduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

const _weekdayShort = ['一', '二', '三', '四', '五', '六', '日'];

String weekdayShort(String date) =>
    _weekdayShort[parseDateKey(date).weekday - 1];

String _monthDay(String date) {
  final parsed = parseDateKey(date);
  return '${parsed.month}/${parsed.day}';
}

String compactNumber(double value) {
  final abs = value.abs();
  if (abs >= 100) return value.round().toString();
  if (abs >= 10) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }
  if (abs == 0) return '0';
  return value.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// 基础绘制工具
// ---------------------------------------------------------------------------

void paintHatch(
  Canvas canvas,
  Rect rect,
  Color color, {
  double spacing = 4.5,
  double strokeWidth = 1,
  bool reverse = false,
  bool cross = false,
}) {
  if (rect.isEmpty) return;
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke;
  canvas.save();
  canvas.clipRect(rect);
  if (!reverse) {
    for (
      var x = rect.left - rect.height;
      x <= rect.right + rect.height;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
  } else {
    for (var x = rect.left; x <= rect.right + rect.height; x += spacing) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x - rect.height, rect.bottom),
        paint,
      );
    }
  }
  if (cross) {
    for (
      var x = rect.left - rect.height;
      x <= rect.right + rect.height;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x + rect.height, rect.bottom),
        paint,
      );
    }
  }
  canvas.restore();
}

void paintDotPattern(
  Canvas canvas,
  Rect rect,
  Color color, {
  double spacing = 5,
  double radius = 0.9,
}) {
  if (rect.isEmpty) return;
  final paint = Paint()..color = color;
  canvas.save();
  canvas.clipRect(rect);
  var row = 0;
  for (var y = rect.top + spacing / 2; y < rect.bottom; y += spacing) {
    final offset = row.isEven ? 0.0 : spacing / 2;
    for (var x = rect.left + offset; x < rect.right; x += spacing) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
    row++;
  }
  canvas.restore();
}

void paintCenteredText(
  Canvas canvas,
  String text,
  Offset center, {
  required TextStyle style,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
  )..layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

// ---------------------------------------------------------------------------
// 环形分数（总分 / 三域）
// ---------------------------------------------------------------------------

class RingScore extends StatelessWidget {
  const RingScore({
    super.key,
    required this.value,
    required this.label,
    this.size = 88,
    this.color,
    this.semanticLabel,
  });

  final double? value;
  final String label;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value;
    final c = color ?? (v == null ? t.unknown : (v >= 70 ? t.ink : t.low));
    final stroke = t.isQ ? 8.0 : 5.5;
    return Semantics(
      label: semanticLabel ?? '$label ${v == null ? '暂无' : '${v.round()} 分'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (v ?? 0).clamp(0, 100) / 100),
                duration: appMotion(context, 760),
                curve: t.motionCurve,
                builder: (context, progress, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    progress: progress,
                    color: c,
                    track: t.surfaceAlt,
                    stroke: stroke,
                    capRound: t.isQ,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    v == null ? '—' : v.round().toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: c,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.inkSecondary,
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
    required this.capRound,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  final bool capRound;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = capRound ? StrokeCap.round : StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke ||
      old.capRound != capRound;
}

// ---------------------------------------------------------------------------
// 瀑布：100 基线，逐项扣分
// ---------------------------------------------------------------------------

class WaterfallStep {
  const WaterfallStep({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;
}

class WaterfallChart extends StatelessWidget {
  const WaterfallChart({
    super.key,
    required this.steps,
    this.base = 100,
    required this.rawTotal,
    required this.finalTotal,
    this.capLabel,
  });

  final List<WaterfallStep> steps;
  final double base;
  final double rawTotal;
  final double finalTotal;
  final String? capLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final totalLost = steps.fold<double>(0, (sum, e) => sum + e.amount);
    final gateLoss = (rawTotal - finalTotal).clamp(0.0, 100.0);
    return Semantics(
      label:
          '瀑布图：基线 100 分，共丢 ${compactNumber(totalLost + gateLoss)} 分，'
          '最终 ${finalTotal.round()} 分。主要扣分项：'
          '${steps.take(3).map((e) => '${e.label} ${compactNumber(e.amount)} 分').join('，')}。',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '基线 ${base.round()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '合计 −${compactNumber(totalLost + gateLoss)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: appMotion(context, 380),
              curve: t.motionCurve,
              builder: (context, progress, _) {
                var running = base;
                final rows = <Widget>[];
                for (final step in steps) {
                  final before = running;
                  final after = before - step.amount;
                  running = after;
                  rows.add(
                    _WaterfallRow(
                      label: step.label,
                      before: before,
                      after: before - step.amount * progress,
                      color: step.color,
                    ),
                  );
                }
                return Column(children: rows);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: _labelWidth,
                right: _valueWidth,
                top: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0', style: Theme.of(context).textTheme.bodySmall),
                  Text('50', style: Theme.of(context).textTheme.bodySmall),
                  Text('100', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(height: t.borderWidth, color: t.hairline),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('加权分', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(
                  compactNumber(rawTotal),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (gateLoss > 0.4) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.vertical_align_bottom_rounded,
                    size: 14,
                    color: t.high,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      capLabel ?? '结构上限',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
                    ),
                  ),
                  Text(
                    '−${compactNumber(gateLoss)} → ${compactNumber(finalTotal)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const double _labelWidth = 78;
const double _valueWidth = 46;

class _WaterfallRow extends StatelessWidget {
  const _WaterfallRow({
    required this.label,
    required this.before,
    required this.after,
    required this.color,
  });

  final String label;
  final double before;
  final double after;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 27,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.ink),
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WaterfallBarPainter(
                  before: before,
                  after: after,
                  color: color,
                  track: t.chartGridColor.withValues(alpha: 0.35),
                  grid: t.chartGridColor.withValues(alpha: 0.28),
                  barHeight: t.isQ ? 12 : 9,
                  q: t.isQ,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SizedBox(
            width: _valueWidth,
            child: Text(
              '−${compactNumber((before - after).clamp(0, 100))}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterfallBarPainter extends CustomPainter {
  const _WaterfallBarPainter({
    required this.before,
    required this.after,
    required this.color,
    required this.track,
    required this.grid,
    required this.barHeight,
    required this.q,
  });

  final double before;
  final double after;
  final Color color;
  final Color track;
  final Color grid;
  final double barHeight;
  final bool q;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    for (final value in [0.0, 50.0, 100.0]) {
      final x = size.width * value / 100;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()..color = grid,
      );
    }
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = track
        ..strokeWidth = 1,
    );
    final left = size.width * after.clamp(0, 100) / 100;
    final right = size.width * before.clamp(0, 100) / 100;
    final rect = Rect.fromLTRB(
      math.min(left, right),
      cy - barHeight / 2,
      math.max(left, right),
      cy + barHeight / 2,
    );
    if (rect.width > 0.8) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(q ? 5 : 1.5)),
        Paint()..color = color,
      );
    }
    // 落点细线，强调“扣到这里”。
    canvas.drawLine(
      Offset(left, cy - barHeight / 2 - 4),
      Offset(left, cy + barHeight / 2 + 4),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_WaterfallBarPainter old) =>
      old.before != before ||
      old.after != after ||
      old.color != color ||
      old.track != track ||
      old.grid != grid ||
      old.barHeight != barHeight ||
      old.q != q;
}

// ---------------------------------------------------------------------------
// 子弹图：实际 vs 目标 vs 适宜区间
// ---------------------------------------------------------------------------

class BulletChart extends StatelessWidget {
  const BulletChart({
    super.key,
    required this.intake,
    required this.targetMin,
    required this.targetMax,
    required this.status,
    this.showBand = true,
    this.limit = false,
    this.recorded = true,
    this.height = 24,
  });

  final double intake;
  final double targetMin;
  final double targetMax;
  final ScoreStatus status;
  final bool showBand;
  final bool limit;
  final bool recorded;
  final double height;

  double get scaleMax {
    final upper = math.max(intake, targetMax);
    final base = upper <= 0 ? 1.0 : upper;
    return math.max(base * 1.14, math.max(targetMin * 1.2, 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (status) {
      ScoreStatus.low => t.low,
      ScoreStatus.high => t.high,
      ScoreStatus.veryHigh => t.veryHigh,
      ScoreStatus.ok => t.good,
      ScoreStatus.unknown => t.unknown,
    };
    return Semantics(
      label:
          '实际 ${compactNumber(intake)}，目标 ${limit ? '不超过' : '至少'} '
          '${compactNumber(limit ? targetMax : targetMin)}，${status.label}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: appMotion(context, 420),
          curve: t.motionCurve,
          builder: (context, progress, _) => RepaintBoundary(
            child: CustomPaint(
              painter: _BulletPainter(
                intake: intake,
                targetMin: targetMin,
                targetMax: targetMax,
                status: status,
                color: color,
                scaleMax: scaleMax,
                showBand: showBand,
                limit: limit,
                recorded: recorded,
                progress: progress,
                track: t.surfaceAlt,
                ink: t.ink,
                inkSecondary: t.inkSecondary,
                unknown: t.unknown,
                barHeight: t.isQ ? 11 : 8,
                q: t.isQ,
              ),
              child: SizedBox(height: height, width: double.infinity),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletPainter extends CustomPainter {
  const _BulletPainter({
    required this.intake,
    required this.targetMin,
    required this.targetMax,
    required this.status,
    required this.color,
    required this.scaleMax,
    required this.showBand,
    required this.limit,
    required this.recorded,
    required this.progress,
    required this.track,
    required this.ink,
    required this.inkSecondary,
    required this.unknown,
    required this.barHeight,
    required this.q,
  });

  final double intake;
  final double targetMin;
  final double targetMax;
  final ScoreStatus status;
  final Color color;
  final double scaleMax;
  final bool showBand;
  final bool limit;
  final bool recorded;
  final double progress;
  final Color track;
  final Color ink;
  final Color inkSecondary;
  final Color unknown;
  final double barHeight;
  final bool q;

  double _x(double value) => (value / scaleMax).clamp(0.0, 1.0) * 100;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    double px(double value) => _x(value) / 100 * size.width;
    final barRect = Rect.fromLTRB(
      0,
      cy - barHeight / 2,
      size.width,
      cy + barHeight / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(barHeight / 2)),
      Paint()..color = track,
    );

    if (!recorded) {
      paintDotPattern(
        canvas,
        barRect.deflate(1),
        unknown.withValues(alpha: 0.45),
        spacing: 5,
      );
    }

    if (showBand && targetMax > 0) {
      final from = px(limit ? 0 : targetMin);
      final to = px(targetMax);
      canvas.drawRect(
        Rect.fromLTRB(from, cy - barHeight / 2, to, cy + barHeight / 2),
        Paint()..color = ink.withValues(alpha: 0.08),
      );
    }

    final actual = px(intake * progress);
    if (recorded && actual > 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0, cy - barHeight / 2, actual, cy + barHeight / 2),
          Radius.circular(barHeight / 2),
        ),
        Paint()..color = ink.withValues(alpha: limit ? 0.72 : 0.86),
      );
    }

    // 不足：空心左端 + 45° 细斜纹（蓝）。
    if (recorded && !limit && intake < targetMin) {
      final gap = Rect.fromLTRB(
        actual,
        cy - barHeight / 2,
        px(targetMin),
        cy + barHeight / 2,
      );
      paintHatch(
        canvas,
        gap,
        color.withValues(alpha: 0.55),
        spacing: 4,
        strokeWidth: 1,
      );
      canvas.drawLine(
        Offset(0, cy - barHeight / 2),
        Offset(0, cy + barHeight / 2),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
    }

    // 偏多：只在限制项的超出段画反向斜纹，右上端点加粗。
    if (recorded && limit && intake > targetMax) {
      final over = Rect.fromLTRB(
        px(targetMax),
        cy - barHeight / 2,
        actual,
        cy + barHeight / 2,
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            px(targetMax),
            cy - barHeight / 2,
            actual,
            cy + barHeight / 2,
          ),
          Radius.circular(q ? 4 : 1),
        ),
      );
      paintHatch(
        canvas,
        over,
        color.withValues(alpha: 0.85),
        spacing: 4.2,
        strokeWidth: 1.2,
        reverse: true,
      );
      canvas.restore();
      canvas.drawRect(
        Rect.fromLTRB(
          actual - (status == ScoreStatus.veryHigh ? 3 : 1.6),
          cy - barHeight / 2,
          actual,
          cy + barHeight / 2,
        ),
        Paint()..color = color,
      );
    }

    // 目标刻线 / 适宜区间刻度。
    final tick = px(limit ? targetMax : targetMin);
    canvas.drawLine(
      Offset(tick, cy - barHeight / 2 - 4),
      Offset(tick, cy + barHeight / 2 + 4),
      Paint()
        ..color = inkSecondary
        ..strokeWidth = 1.4,
    );
    if (showBand && !limit && targetMax > targetMin * 1.12) {
      final upper = px(targetMax);
      canvas.drawLine(
        Offset(upper, cy - 3),
        Offset(upper, cy + 3),
        Paint()
          ..color = inkSecondary.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
    }

    if (recorded) {
      canvas.drawCircle(Offset(actual, cy), 2.4, Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(_BulletPainter old) =>
      old.intake != intake ||
      old.targetMin != targetMin ||
      old.targetMax != targetMax ||
      old.status != status ||
      old.color != color ||
      old.scaleMax != scaleMax ||
      old.showBand != showBand ||
      old.limit != limit ||
      old.recorded != recorded ||
      old.progress != progress ||
      old.track != track ||
      old.ink != ink ||
      old.inkSecondary != inkSecondary ||
      old.unknown != unknown ||
      old.barHeight != barHeight ||
      old.q != q;
}

// ---------------------------------------------------------------------------
// 7 日趋势 + 区间带（fl_chart）
// ---------------------------------------------------------------------------

class TrendBandChart extends StatelessWidget {
  const TrendBandChart({super.key, required this.days, this.height = 200});

  final List<DayScore> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = days.length;
    final scoredDays = days.where((e) => e.total != null).toList();
    if (scoredDays.isEmpty) {
      return Semantics(
        label: '最近 $n 天还没有可评分的记录。先记 2 餐，再回来看趋势。',
        child: SizedBox(
          height: 128,
          child: Center(
            child: Text(
              '这 $n 天还没有可评分的记录。\n先记 2 餐，再回来看趋势。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
        ),
      );
    }
    final low = <FlSpot>[];
    final high = <FlSpot>[];
    final mid = <FlSpot>[];
    for (var i = 0; i < n; i++) {
      final day = days[i];
      final total = day.total;
      if (total == null) {
        low.add(FlSpot.nullSpot);
        high.add(FlSpot.nullSpot);
        mid.add(FlSpot.nullSpot);
      } else {
        final p10 = day.interval?.p10 ?? total;
        final p90 = day.interval?.p90 ?? total;
        low.add(FlSpot(i.toDouble(), p10.clamp(0, 100)));
        high.add(FlSpot(i.toDouble(), p90.clamp(0, 100)));
        mid.add(FlSpot(i.toDouble(), total.clamp(0, 100)));
      }
    }
    final scored = days.where((e) => e.eligible && e.total != null).length;
    final today = days.isEmpty ? null : days.last;

    return Semantics(
      label:
          '最近 ${days.length} 天趋势：$scored 天可评分，'
          '${days.where((e) => e.eligible && e.total != null).map((e) => '${weekdayShort(e.date)} ${e.total!.round()}').join('，')}。'
          '${today?.total == null ? '今天记录不足，暂不评分。' : '今天 ${today!.total!.round()} 分。'}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minX: -0.35,
                maxX: n - 0.65,
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: t.chartGridColor.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          value.round().toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= n) return const SizedBox.shrink();
                        final isToday = i == n - 1;
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            isToday ? '今天' : weekdayShort(days[i].date),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isToday ? t.ink : t.inkSecondary,
                                  fontWeight: isToday
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 70,
                      color: t.chartGridColor.withValues(alpha: 0.7),
                      strokeWidth: 1,
                      dashArray: [2, 4],
                    ),
                  ],
                ),
                betweenBarsData: [
                  BetweenBarsData(
                    fromIndex: 0,
                    toIndex: 1,
                    color: t.ink.withValues(alpha: 0.07),
                  ),
                ],
                lineBarsData: [
                  LineChartBarData(
                    spots: low,
                    show: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: high,
                    show: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: mid,
                    isCurved: false,
                    color: t.ink,
                    barWidth: t.chartLineWidth,
                    isStrokeCapRound: t.isQ,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final day = days[index];
                        final precise =
                            day.interval != null && day.interval!.width <= 3;
                        final isToday = index == days.length - 1;
                        final radius = isToday ? 4.2 : 3.0;
                        return FlDotCirclePainter(
                          radius: radius,
                          color: precise ? t.ink : t.surface,
                          strokeWidth: 1.5,
                          strokeColor: t.ink,
                        );
                      },
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => t.ink,
                    tooltipBorderRadius: BorderRadius.circular(t.radiusSm),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        if (spot.barIndex != 2) return null;
                        final day = days[spot.spotIndex];
                        final interval = day.interval;
                        final text = interval == null
                            ? '${formatDate(day.date)}\n${day.total?.round() ?? '—'} 分'
                            : '${formatDate(day.date)}\n${day.total!.round()} 分（${interval.p10.round()}–${interval.p90.round()}）';
                        return LineTooltipItem(
                          text,
                          TextStyle(
                            color: t.background,
                            fontSize: 12,
                            height: 1.45,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          textAlign: TextAlign.left,
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (bar, indexes) => indexes
                      .map(
                        (index) => TouchedSpotIndicatorData(
                          FlLine(
                            color: t.ink.withValues(alpha: 0.25),
                            strokeWidth: 1,
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, i) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: t.surface,
                                  strokeWidth: 1.5,
                                  strokeColor: t.ink,
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              duration: appMotion(context, 420),
              curve: t.motionCurve,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 30 日日历热力：色 + 斜纹 + 箭头
// ---------------------------------------------------------------------------

enum DayBand { steady, ok, low, gap, unrated }

DayBand dayBand(DayScore day) {
  final total = day.total;
  if (!day.eligible || total == null) return DayBand.unrated;
  if (total >= 85) return DayBand.steady;
  if (total >= 70) return DayBand.ok;
  if (total >= 55) return DayBand.low;
  return DayBand.gap;
}

String dayBandLabel(DayBand band) => switch (band) {
  DayBand.steady => '稳定',
  DayBand.ok => '达标',
  DayBand.low => '待补',
  DayBand.gap => '缺口较大',
  DayBand.unrated => '未评分',
};

String dayBandGlyph(DayBand band) => switch (band) {
  DayBand.steady || DayBand.ok => '✓',
  DayBand.low => '↓',
  DayBand.gap => '↓↓',
  DayBand.unrated => '?',
};

class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.days,
    required this.onDayTap,
    this.columns = 6,
  });

  final List<DayScore> days;
  final ValueChanged<DayScore> onDayTap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (days.isEmpty) return const SizedBox.shrink();
    final rows = (days.length / columns).ceil();
    final counts = <DayBand, int>{
      for (final band in DayBand.values)
        band: days.where((d) => dayBand(d) == band).length,
    };
    return Semantics(
      label:
          '最近 ${days.length} 天日历：稳定 ${counts[DayBand.steady]} 天，'
          '达标 ${counts[DayBand.ok]} 天，待补 ${counts[DayBand.low]} 天，'
          '缺口较大 ${counts[DayBand.gap]} 天，未评分 ${counts[DayBand.unrated]} 天。'
          '点格子看当天扣分。',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final cellW =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final cellH = math.min(40.0, math.max(30.0, cellW * 0.78));
            final width = constraints.maxWidth;
            final height = math.max(0.0, rows * cellH + (rows - 1) * gap);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final col = (details.localPosition.dx / (cellW + gap))
                        .floor();
                    final row = (details.localPosition.dy / (cellH + gap))
                        .floor();
                    if (col < 0 || col >= columns || row < 0 || row >= rows) {
                      return;
                    }
                    final index = row * columns + col;
                    if (index < 0 || index >= days.length) return;
                    onDayTap(days[index]);
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: _HeatmapPainter(
                        days: days,
                        columns: columns,
                        cellW: cellW,
                        cellH: cellH,
                        gap: gap,
                        today: todayKey(),
                        good: t.good,
                        low: t.low,
                        unknown: t.unknown,
                        hairline: t.hairline,
                        ink: t.ink,
                        surface: t.surface,
                        isQ: t.isQ,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        days.isEmpty ? '' : _monthDay(days.first.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        days.isEmpty ? '' : _monthDay(days.last.date),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (final band in DayBand.values)
                      _HeatLegendItem(band: band, count: counts[band] ?? 0),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeatLegendItem extends StatelessWidget {
  const _HeatLegendItem({required this.band, required this.count});

  final DayBand band;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (band) {
      DayBand.steady || DayBand.ok => t.good,
      DayBand.low || DayBand.gap => t.low,
      DayBand.unrated => t.unknown,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CustomPaint(
            painter: _LegendSwatchPainter(
              band: band,
              color: color,
              hairline: t.hairline,
              ink: t.ink,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${dayBandLabel(band)} $count',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LegendSwatchPainter extends CustomPainter {
  const _LegendSwatchPainter({
    required this.band,
    required this.color,
    required this.hairline,
    required this.ink,
  });

  final DayBand band;
  final Color color;
  final Color hairline;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    _paintBandFill(canvas, rrect, rect, band, color);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = hairline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_LegendSwatchPainter old) =>
      old.band != band ||
      old.color != color ||
      old.hairline != hairline ||
      old.ink != ink;
}

void _paintBandFill(
  Canvas canvas,
  RRect rrect,
  Rect rect,
  DayBand band,
  Color color,
) {
  switch (band) {
    case DayBand.steady:
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.22));
    case DayBand.ok:
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.10));
    case DayBand.low:
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.14));
      paintHatch(
        canvas,
        rect,
        color.withValues(alpha: 0.55),
        spacing: 4,
        strokeWidth: 1,
      );
    case DayBand.gap:
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.24));
      paintHatch(
        canvas,
        rect,
        color.withValues(alpha: 0.6),
        spacing: 3.6,
        strokeWidth: 1,
        cross: true,
      );
    case DayBand.unrated:
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.07));
      paintDotPattern(
        canvas,
        rect.deflate(1),
        color.withValues(alpha: 0.45),
        spacing: 4,
      );
  }
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.days,
    required this.columns,
    required this.cellW,
    required this.cellH,
    required this.gap,
    required this.today,
    required this.good,
    required this.low,
    required this.unknown,
    required this.hairline,
    required this.ink,
    required this.surface,
    required this.isQ,
  });

  final List<DayScore> days;
  final int columns;
  final double cellW;
  final double cellH;
  final double gap;
  final String today;
  final Color good;
  final Color low;
  final Color unknown;
  final Color hairline;
  final Color ink;
  final Color surface;
  final bool isQ;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < days.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final rect = Rect.fromLTWH(
        col * (cellW + gap),
        row * (cellH + gap),
        cellW,
        cellH,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(isQ ? 8 : 3));
      final band = dayBand(days[i]);
      final color = switch (band) {
        DayBand.steady || DayBand.ok => good,
        DayBand.low || DayBand.gap => low,
        DayBand.unrated => unknown,
      };
      _paintBandFill(canvas, rrect, rect, band, color);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = days[i].date == today ? ink : hairline
          ..strokeWidth = days[i].date == today ? 1.8 : 1,
      );
      paintCenteredText(
        canvas,
        dayBandGlyph(band),
        rect.center,
        style: TextStyle(
          color: band == DayBand.steady || band == DayBand.ok
              ? good
              : (band == DayBand.unrated ? unknown : low),
          fontSize: band == DayBand.gap ? 10 : 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.days != days ||
      old.columns != columns ||
      old.cellW != cellW ||
      old.cellH != cellH ||
      old.gap != gap ||
      old.today != today ||
      old.good != good ||
      old.low != low ||
      old.unknown != unknown ||
      old.hairline != hairline ||
      old.ink != ink ||
      old.surface != surface ||
      old.isQ != isQ;
}

// ---------------------------------------------------------------------------
// 每日丢分构成（堆叠条，单色阶）
// ---------------------------------------------------------------------------

class StackedLossBars extends StatelessWidget {
  const StackedLossBars({
    super.key,
    required this.days,
    required this.onDayTap,
  });

  final List<DayScore> days;
  final ValueChanged<DayScore> onDayTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = <ScoreDomain, Color>{
      ScoreDomain.foodGroups: t.ink.withValues(alpha: 0.82),
      ScoreDomain.nutrients: t.inkSecondary.withValues(alpha: 0.55),
      ScoreDomain.limits: t.inkTertiary.withValues(alpha: 0.42),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          _StackedDayRow(day: day, colors: colors, onTap: () => onDayTap(day)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final domain in ScoreDomain.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[domain],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    domain.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '条形按丢分构成归一化；右侧是当天日分。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
        ),
      ],
    );
  }
}

class _StackedDayRow extends StatelessWidget {
  const _StackedDayRow({
    required this.day,
    required this.colors,
    required this.onTap,
  });

  final DayScore day;
  final Map<ScoreDomain, Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final losses = <ScoreDomain, double>{
      for (final domain in ScoreDomain.values)
        domain: day.items
            .where((item) => item.domain == domain)
            .fold<double>(0, (sum, item) => sum + item.lostPoints),
    };
    final scored = day.eligible && day.total != null;
    return Semantics(
      label:
          '${weekdayShort(day.date)}，${scored ? '${day.total!.round()} 分' : '未评分'}，'
          '食物组丢 ${losses[ScoreDomain.foodGroups]!.toStringAsFixed(0)} 分，'
          '营养素丢 ${losses[ScoreDomain.nutrients]!.toStringAsFixed(0)} 分，'
          '限制项丢 ${losses[ScoreDomain.limits]!.toStringAsFixed(0)} 分。',
      button: true,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    weekdayShort(day.date),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: const Size.fromHeight(16),
                      painter: _StackedBarPainter(
                        losses: losses,
                        colors: colors,
                        track: t.surfaceAlt,
                        surface: t.surface,
                        scored: scored,
                        unknown: t.unknown,
                        q: t.isQ,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    scored ? day.total!.round().toString() : '—',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scored ? t.ink : t.unknown,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  const _StackedBarPainter({
    required this.losses,
    required this.colors,
    required this.track,
    required this.surface,
    required this.scored,
    required this.unknown,
    required this.q,
  });

  final Map<ScoreDomain, double> losses;
  final Map<ScoreDomain, Color> colors;
  final Color track;
  final Color surface;
  final bool scored;
  final Color unknown;
  final bool q;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(q ? 8 : 2);
    final trackRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = track,
    );
    if (!scored) {
      paintDotPattern(
        canvas,
        trackRect.deflate(1),
        unknown.withValues(alpha: 0.4),
        spacing: 5,
      );
      return;
    }
    var x = 0.0;
    final domains = ScoreDomain.values;
    for (var i = 0; i < domains.length; i++) {
      final value = losses[domains[i]] ?? 0;
      final width = size.width * value.clamp(0, 100) / 100;
      if (width <= 0) continue;
      final rect = Rect.fromLTWH(x, 0, width, size.height);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(q ? 4 : 1));
      canvas.drawRRect(rrect, Paint()..color = colors[domains[i]]!);
      x += width;
      if (x >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(_StackedBarPainter old) =>
      old.losses != losses ||
      old.colors != colors ||
      old.track != track ||
      old.surface != surface ||
      old.scored != scored ||
      old.unknown != unknown ||
      old.q != q;
}

// ---------------------------------------------------------------------------
// 食物组 6 轴雷达（轴序固定）
// ---------------------------------------------------------------------------

const foodRadarShortLabels = <String, String>{
  'A1': '蔬菜',
  'A2': '水果',
  'A3': '全谷',
  'A4': '奶类',
  'A5': '豆坚果',
  'A6': '鱼肉蛋',
};

class FoodGroupRadar extends StatelessWidget {
  const FoodGroupRadar({super.key, required this.items, this.height = 214});

  final List<ScoreItemResult> items;
  final double height;

  List<ScoreItemResult> get _ordered {
    final byCode = {for (final item in items) item.code: item};
    return [
      for (final code in foodRadarShortLabels.keys) byCode[code],
    ].whereType<ScoreItemResult>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ordered = _ordered;
    final weakest = ordered.isEmpty
        ? null
        : (ordered.toList()..sort((a, b) => a.score.compareTo(b.score))).first;
    return Semantics(
      label:
          '食物组 6 轴雷达，轴序固定：'
          '${ordered.map((e) => '${e.label} ${e.score.round()} 分').join('，')}。'
          '${weakest == null ? '' : '最弱是${weakest.label}。'}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _RadarPainter(
                values: [for (final item in ordered) item.score / 100],
                labels: [
                  for (final item in ordered)
                    foodRadarShortLabels[item.code] ?? item.label,
                ],
                grid: t.chartGridColor.withValues(alpha: 0.55),
                axis: t.chartGridColor.withValues(alpha: 0.55),
                ink: t.ink,
                labelColor: t.inkSecondary,
                labelFont: t.bodyFont,
                q: t.isQ,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.labels,
    required this.grid,
    required this.axis,
    required this.ink,
    required this.labelColor,
    required this.labelFont,
    required this.q,
  });

  final List<double> values;
  final List<String> labels;
  final Color grid;
  final Color axis;
  final Color ink;
  final Color labelColor;
  final String labelFont;
  final bool q;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 3) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width / 2, size.height / 2) - 34;
    if (radius <= 8) return;
    final count = values.length;

    Offset pointAt(int i, double scale) {
      final angle = -math.pi / 2 + 2 * math.pi * i / count;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * scale);
    }

    // 3 圈参考网格：报告版多边形，绘本版圆形。
    for (final level in [1 / 3, 2 / 3, 1.0]) {
      final paint = Paint()
        ..color = grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      if (q) {
        canvas.drawCircle(center, radius * level, paint);
      } else {
        final path = Path();
        for (var i = 0; i < count; i++) {
          final point = pointAt(i, level);
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    for (var i = 0; i < count; i++) {
      canvas.drawLine(
        center,
        pointAt(i, 1),
        Paint()
          ..color = axis
          ..strokeWidth = 1,
      );
    }

    final dataPath = Path();
    for (var i = 0; i < count; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final point = pointAt(i, math.max(0.015, value));
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = ink.withValues(alpha: 0.10));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = q ? 2.6 : 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < count; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final point = pointAt(i, math.max(0.015, value));
      canvas.drawCircle(point, q ? 3.2 : 2.4, Paint()..color = ink);
    }

    for (var i = 0; i < count; i++) {
      final direction = pointAt(i, 1) - center;
      final anchor = center + direction * (1 + 14 / radius);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontFamily: labelFont,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var dx = anchor.dx - tp.width / 2;
      if (direction.dx > 0.2) dx = anchor.dx;
      if (direction.dx < -0.2) dx = anchor.dx - tp.width;
      dx = dx.clamp(0.0, size.width - tp.width);
      final dy = (anchor.dy - tp.height / 2).clamp(
        0.0,
        size.height - tp.height,
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.grid != grid ||
      old.axis != axis ||
      old.ink != ink ||
      old.labelColor != labelColor ||
      old.labelFont != labelFont ||
      old.q != q;
}
