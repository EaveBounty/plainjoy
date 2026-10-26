import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 开屏：30° 等腰三角形版式 + 半透明东坡词意象。
///
/// 版式几何：
/// - 三角形顶点在上方 [apexY]，底边在 [baseY]，顶角固定 30°，底角 75°；
/// - 「清」「欢」沿 30° 斜线排布，第二个字的顶端与第一个字的竖直中点对齐
///   （水平位移 = 0.5em / tan30° = 0.866em，竖直位移 = 0.5em）。
///
/// 动画总时长 720ms；系统开启「减少动态效果」时直接呈现终态。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.onFinished});

  /// 仅用于调试/截图：动画跑完时回调。正常启动由 AppGate 控制切换。
  final VoidCallback? onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduce) {
      _c.value = 1;
    } else {
      _c.forward().whenComplete(() => widget.onFinished?.call());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final w = media.size.width;
    final apexY = h * 0.185;
    final baseY = math.min(h * 0.855, apexY + w * 1.62);
    final halfBase = (baseY - apexY) * math.tan(15 * math.pi / 180);
    final fs = (w * 0.178).clamp(50.0, 74.0);

    final poemStyle = TextStyle(
      fontFamily: t.titleFont,
      fontFamilyFallback: ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
      fontSize: (w * 0.033).clamp(11.0, 13.5),
      height: 1.9,
      letterSpacing: 1.4,
      color: t.ink.withValues(alpha: 0.78),
    );

    final left = w / 2 - fs * 0.933;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // ---- 三角窗口内的淡墨意象 ----
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final o = _step(0, 0.42).value;
                  final s = 1.035 - 0.035 * _step(0.1, 1).value;
                  return Opacity(
                    opacity: o * 0.62,
                    child: Transform.scale(scale: s, child: child),
                  );
                },
                child: ClipPath(
                  clipper: _TriangleClipper(apexY: apexY, baseY: baseY, halfBase: halfBase),
                  child: Image.asset(
                    'assets/brand/splash_ink.webp',
                    fit: BoxFit.cover,
                    width: w,
                    height: h,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),

          // ---- 三角框线 ----
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _TrianglePainter(
                    apex: Offset(w / 2, apexY),
                    halfBase: halfBase,
                    baseY: baseY,
                    progress: _step(0.06, 0.5).value,
                    color: t.ink.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
          ),

          // ---- 清 / 欢：30° 斜向、半字对齐 ----
          Positioned(
            left: left,
            top: apexY + fs * 1.02,
            child: _FadeUp(
              animation: _step(0.16, 0.52),
              child: Text(
                '清',
                style: TextStyle(
                  fontFamily: t.titleFont,
                  fontFamilyFallback: ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
                  fontSize: fs,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: t.ink,
                ),
              ),
            ),
          ),
          Positioned(
            left: left + fs * 0.866,
            top: apexY + fs * 1.02 + fs * 0.5,
            child: _FadeUp(
              animation: _step(0.28, 0.64),
              child: Text(
                '欢',
                style: TextStyle(
                  fontFamily: t.titleFont,
                  fontFamilyFallback: ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
                  fontSize: fs,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: t.ink,
                ),
              ),
            ),
          ),

          // ---- 底部诗句 ----
          Positioned(
            left: w / 2 - halfBase * 0.74,
            width: halfBase * 1.48,
            bottom: h - (baseY - 58),
            child: _FadeUp(
              animation: _step(0.38, 0.78),
              dy: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('雪沫乳花浮午盏，', textAlign: TextAlign.center, style: poemStyle),
                  Text('蓼茸蒿笋试春盘。', textAlign: TextAlign.center, style: poemStyle),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '人间有味是清欢。',
                        style: poemStyle.copyWith(
                          color: t.ink,
                          fontSize: (w * 0.041).clamp(13.0, 15.5),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _c,
                        builder: (context, child) => Opacity(
                          opacity: _step(0.66, 0.92).value,
                          child: Transform.rotate(angle: -0.02, child: child),
                        ),
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA6402D).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          child: const Text(
                            '清',
                            style: TextStyle(
                              color: Color(0xFFFFF6EC),
                              fontSize: 10,
                              height: 1,
                              fontFamily: 'Noto Serif SC',
                              fontFamilyFallback: ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
                            ),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'P L A I N J O Y',
                      style: TextStyle(
                        fontFamily: t.bodyFont,
                        fontSize: 8.5,
                        letterSpacing: 3.4,
                        color: t.inkTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child, this.dy = 10});

  final Animation<double> animation;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, dy * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  const _TriangleClipper({required this.apexY, required this.baseY, required this.halfBase});

  final double apexY;
  final double baseY;
  final double halfBase;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, apexY)
      ..lineTo(size.width / 2 - halfBase, baseY)
      ..lineTo(size.width / 2 + halfBase, baseY)
      ..close();
  }

  @override
  bool shouldReclip(_TriangleClipper old) =>
      old.apexY != apexY || old.baseY != baseY || old.halfBase != halfBase;
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({
    required this.apex,
    required this.halfBase,
    required this.baseY,
    required this.progress,
    required this.color,
  });

  final Offset apex;
  final double halfBase;
  final double baseY;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final left = Offset(size.width / 2 - halfBase, baseY);
    final right = Offset(size.width / 2 + halfBase, baseY);
    final full = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    // 从顶点向两侧「生长」的描边
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (final metric in full.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0, 1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.progress != progress || old.color != color || old.baseY != baseY;
}
