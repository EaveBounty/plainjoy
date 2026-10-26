import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/pet.dart';
import '../../core/theme/app_tokens.dart';

/// 宠物的十个可见状态。
///
/// 前七个由 [PetSignal] 直接映射，`sleep` 由停留过久自动进入，
/// `transition` 在切换物种时播放。
enum PetMood {
  idle,
  happy,
  eat,
  full,
  sleepy,
  sleep,
  thirsty,
  lowEnergy,
  celebrate,
  transition,
}

extension PetMoodX on PetMood {
  String get label => switch (this) {
    PetMood.idle => '安静',
    PetMood.happy => '高兴',
    PetMood.eat => '吃饭',
    PetMood.full => '满足',
    PetMood.sleepy => '犯困',
    PetMood.sleep => '睡觉',
    PetMood.thirsty => '想喝水',
    PetMood.lowEnergy => '没力气',
    PetMood.celebrate => '庆祝',
    PetMood.transition => '换装',
  };
}

/// 把四轴结果落成可见状态。只描述需求，不描述后果。
PetMood resolvePetMood({required PetSignal signal, required PetAxes axes}) {
  return switch (signal) {
    PetSignal.hungry => PetMood.eat,
    PetSignal.thirsty => PetMood.thirsty,
    PetSignal.sleepy => PetMood.sleepy,
    PetSignal.lowEnergy => PetMood.lowEnergy,
    PetSignal.proud => PetMood.happy,
    PetSignal.celebrate => PetMood.celebrate,
    PetSignal.idle =>
      axes.vitality >= 78 && axes.hydration >= 65 && axes.mood >= 70
          ? PetMood.full
          : PetMood.idle,
  };
}

/// 程序化宠物绘制。两套画法共用几何，通过 [PetStyle] 与 [isQ] 区分笔触。
///
/// 坐标系固定为 300 × 260，再等比缩放，保证任意容器里的比例一致。
class PetPainter extends CustomPainter {
  final PetSpecies species;
  final PetStyle style;
  final bool isQ;
  final PetMood mood;
  final PetAxes axes;
  final Animation<double> animation;
  final Animation<double> transition;

  final Color outline;
  final Color ground;
  final Color accent;
  final Color water;
  final Color shadowColor;
  final Offset shadowOffset;

  PetPainter({
    required this.species,
    required this.style,
    required this.isQ,
    required this.mood,
    required this.axes,
    required this.animation,
    required this.transition,
    required this.outline,
    required this.ground,
    required this.accent,
    required this.water,
    required this.shadowColor,
    required this.shadowOffset,
  }) : super(repaint: Listenable.merge([animation, transition]));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = animation.value;
    final trans = transition.value;
    final scale = math.min(size.width / 300, size.height / 260);
    canvas.save();
    canvas.translate(
      (size.width - 300 * scale) / 2,
      (size.height - 260 * scale) / 2,
    );
    canvas.scale(scale);
    _paintScene(canvas, t, trans);
    canvas.restore();
  }

  // ---------------------------------------------------------------- scene

  void _paintScene(Canvas canvas, double t, double trans) {
    final m = mood;
    final wave = math.sin(t * 2 * math.pi);

    final sleeping = m == PetMood.sleep;
    final sleepy = m == PetMood.sleepy || sleeping;
    final lively = m == PetMood.happy || m == PetMood.celebrate;
    final low = m == PetMood.lowEnergy;
    final eating = m == PetMood.eat;
    final thirsty = m == PetMood.thirsty;
    final full = m == PetMood.full;
    final celebrating = m == PetMood.celebrate;
    final transitioning = m == PetMood.transition;

    var hop = 0.0;
    if (celebrating) {
      hop = -15 * math.sin(t * math.pi * 2).abs();
    } else if (lively) {
      hop = -6 * math.sin(t * math.pi * 4).abs();
    } else if (transitioning) {
      hop = -7 * math.sin(trans * math.pi);
    }

    _drawShadow(canvas, hop);

    if (thirsty) _drawBowl(canvas, t);

    // 身体
    var bw = 116 * style.bodyRoundness;
    var bh = 86 * (0.9 + 0.1 * style.bodyRoundness);
    var bx = 150.0;
    var by = 176.0;
    if (!species.isCat) {
      bw += 6;
      bh -= 2;
    }
    if (species == PetSpecies.corgi) {
      bw += 6;
      bh -= 4;
      by += 2;
    }
    if (full) {
      bw += 12;
      bh += 8;
      by -= 2;
    }
    if (sleeping) {
      bw += 18;
      bh -= 18;
      by += 10;
    }
    if (low) {
      bh -= 6;
      by += 4;
    }
    if (eating) by += 2;
    bh += wave * 1.4;
    by += hop;

    final bodyPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(bx, by), width: bw, height: bh));

    _drawTail(canvas, bx, by, bw, bh, t, hop);

    final bodyPaint = Paint()..color = style.base;
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.save();
    canvas.clipPath(bodyPath);
    _drawBodyMarkings(canvas, bx, by, bw, bh);
    canvas.restore();
    canvas.drawPath(bodyPath, _stroke(outline, style.outlineWidth));

    // 头
    var hr = 50 * style.headScale;
    var hx = 150.0;
    var hy = 108.0;
    if (eating) hy += 16;
    if (full) hy -= 2;
    if (sleepy && !sleeping) {
      hy += 8;
      hx -= 4;
    }
    if (sleeping) {
      hy = 150;
      hx = 130;
    }
    if (low) hy += 12;
    if (thirsty) hy -= 4;
    if (celebrating) hy -= 6;
    hy += hop;

    final tilt = sleeping
        ? -0.22
        : sleepy
        ? -0.10
        : low
        ? -0.06
        : thirsty
        ? 0.05
        : wave * 0.015;

    final headPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(hx, hy),
          width: hr * 2,
          height: hr * 1.9,
        ),
      );

    _drawEars(canvas, hx, hy, hr, sleeping, sleepy, low);

    canvas.save();
    canvas.translate(hx, hy);
    canvas.rotate(tilt);
    canvas.translate(-hx, -hy);
    canvas.drawPath(headPath, Paint()..color = style.base);
    canvas.save();
    canvas.clipPath(headPath);
    _drawHeadMarkings(canvas, hx, hy, hr);
    canvas.restore();
    canvas.drawPath(headPath, _stroke(outline, style.outlineWidth));
    _drawFace(
      canvas,
      hx,
      hy,
      hr,
      t,
      sleeping,
      sleepy,
      lively,
      low,
      eating,
      thirsty,
      full,
      celebrating,
    );
    canvas.restore();

    if (!species.isCat) _drawCollar(canvas, hx, hy, hr);

    _drawParticles(
      canvas,
      hx,
      hy,
      hr,
      t,
      trans,
      sleeping,
      sleepy,
      lively,
      eating,
      thirsty,
      full,
      celebrating,
      transitioning,
    );
  }

  void _drawShadow(Canvas canvas, double hop) {
    final shrink = hop.abs() * 1.6;
    final rect = Rect.fromCenter(
      center: Offset(150 + shadowOffset.dx, 238 + shadowOffset.dy),
      width: 128 - shrink,
      height: 18 - shrink * 0.18,
    );
    if (isQ) {
      canvas.drawOval(
        rect,
        Paint()..color = shadowColor.withValues(alpha: 0.10),
      );
    }
    canvas.drawOval(
      rect,
      Paint()..color = ground.withValues(alpha: isQ ? 0.16 : 0.22),
    );
  }

  // ---------------------------------------------------------------- tail

  void _drawTail(
    Canvas canvas,
    double bx,
    double by,
    double bw,
    double bh,
    double t,
    double hop,
  ) {
    final sleepyTail = mood == PetMood.sleep || mood == PetMood.sleepy;
    final lowTail = mood == PetMood.lowEnergy;
    final lively = mood == PetMood.happy || mood == PetMood.celebrate;
    final start = Offset(bx + bw * 0.44, by + bh * 0.20);

    final path = Path();
    if (species == PetSpecies.corgi) {
      final wag = lively ? math.sin(t * math.pi * 4) * 3 : 0.0;
      path
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx + 14,
          start.dy - 6 + wag,
          start.dx + 22,
          start.dy - 2 + wag,
        );
    } else if (species == PetSpecies.shibaInu) {
      final sway = math.sin(t * 2 * math.pi) * (lively ? 4 : 1.5);
      path
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + 40,
          start.dy - 20 + sway,
          start.dx + 20,
          start.dy - 68 + sway,
          start.dx - 2,
          start.dy - 44 + sway,
        )
        ..cubicTo(
          start.dx - 14,
          start.dy - 26,
          start.dx + 4,
          start.dy - 18,
          start.dx + 6,
          start.dy - 28,
        );
    } else if (sleepyTail || lowTail) {
      final endY = by + bh * (lowTail ? 0.62 : 0.50);
      path
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(start.dx + 34, endY + 6, start.dx + 16, endY);
    } else {
      final swing = math.sin(t * 2 * math.pi * (lively ? 2.0 : 1.0));
      final amp = lively ? 22.0 : (mood == PetMood.thirsty ? 5.0 : 11.0);
      final lift = lively ? 62.0 : 48.0;
      final tipX = start.dx + 28 + swing * amp;
      final tipY = start.dy - lift + hop;
      path
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + 36,
          start.dy - 10,
          start.dx + 52 + swing * amp * 0.4,
          start.dy - lift * 0.55,
          tipX,
          tipY,
        );
    }

    final base = isQ ? 3.0 : 2.4;
    canvas.drawPath(
      path,
      _stroke(outline, style.outlineWidth + base)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      _stroke(style.base, base)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (species != PetSpecies.corgi) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.last;
        final tip = metric.getTangentForOffset(metric.length)?.position;
        if (tip != null) {
          canvas.drawCircle(tip, base * 0.72, Paint()..color = style.secondary);
        }
      }
    }
  }

  // ------------------------------------------------------------- markings

  void _drawBodyMarkings(
    Canvas canvas,
    double bx,
    double by,
    double bw,
    double bh,
  ) {
    switch (species) {
      case PetSpecies.calicoCat:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx + bw * 0.18, by - bh * 0.18),
            width: bw * 0.52,
            height: bh * 0.60,
          ),
          Paint()..color = style.secondary,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx - bw * 0.26, by + bh * 0.12),
            width: bw * 0.30,
            height: bh * 0.42,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.55),
        );
      case PetSpecies.tabbyCat:
        for (var i = -1; i <= 1; i++) {
          final x = bx + i * bw * 0.16;
          final p = Path()
            ..moveTo(x - 8, by - bh * 0.34)
            ..quadraticBezierTo(x + 3, by - bh * 0.05, x - 4, by + bh * 0.22);
          canvas.drawPath(
            p,
            _stroke(style.secondary.withValues(alpha: 0.65), isQ ? 5 : 3),
          );
        }
      case PetSpecies.orangeCat:
        for (var i = -1; i <= 1; i++) {
          final x = bx + i * bw * 0.20;
          final p = Path()
            ..moveTo(x - 6, by - bh * 0.40)
            ..quadraticBezierTo(x + 4, by - bh * 0.08, x, by + bh * 0.10);
          canvas.drawPath(
            p,
            _stroke(style.secondary.withValues(alpha: 0.5), isQ ? 5 : 3),
          );
        }
      case PetSpecies.tuxedoCat:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx, by + bh * 0.14),
            width: bw * 0.46,
            height: bh * 0.62,
          ),
          Paint()..color = style.belly,
        );
      case PetSpecies.shibaInu:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx, by + bh * 0.18),
            width: bw * 0.52,
            height: bh * 0.52,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.75),
        );
      case PetSpecies.corgi:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx, by + bh * 0.20),
            width: bw * 0.50,
            height: bh * 0.50,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.85),
        );
      case PetSpecies.tuxedoDog:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bx - bw * 0.18, by - bh * 0.16),
            width: bw * 0.42,
            height: bh * 0.46,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.35),
        );
    }
  }

  void _drawHeadMarkings(Canvas canvas, double hx, double hy, double hr) {
    switch (species) {
      case PetSpecies.calicoCat:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx - hr * 0.38, hy - hr * 0.46),
            width: hr * 0.92,
            height: hr * 0.72,
          ),
          Paint()..color = style.secondary,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx + hr * 0.46, hy + hr * 0.20),
            width: hr * 0.52,
            height: hr * 0.62,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.6),
        );
      case PetSpecies.tabbyCat:
        for (var i = -1; i <= 1; i++) {
          final x = hx + i * hr * 0.24;
          canvas.drawPath(
            Path()
              ..moveTo(x - 7, hy - hr * 0.72)
              ..quadraticBezierTo(x + 4, hy - hr * 0.42, x - 2, hy - hr * 0.18),
            _stroke(style.secondary.withValues(alpha: 0.65), isQ ? 5 : 3),
          );
        }
      case PetSpecies.orangeCat:
        for (var i = -1; i <= 1; i++) {
          final x = hx + i * hr * 0.28;
          canvas.drawPath(
            Path()
              ..moveTo(x - 4, hy - hr * 0.70)
              ..quadraticBezierTo(x + 3, hy - hr * 0.36, x, hy - hr * 0.16),
            _stroke(style.secondary.withValues(alpha: 0.45), isQ ? 5 : 3),
          );
        }
      case PetSpecies.tuxedoCat:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx, hy + hr * 0.30),
            width: hr * 1.06,
            height: hr * 0.70,
          ),
          Paint()..color = style.belly,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx, hy - hr * 0.58),
            width: hr * 0.22,
            height: hr * 0.54,
          ),
          Paint()..color = style.belly.withValues(alpha: 0.9),
        );
      case PetSpecies.shibaInu:
        for (final sign in const [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(hx + sign * hr * 0.56, hy + hr * 0.28),
              width: hr * 0.46,
              height: hr * 0.42,
            ),
            Paint()..color = style.secondary.withValues(alpha: 0.9),
          );
        }
      case PetSpecies.corgi:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx, hy - hr * 0.24),
            width: hr * 0.26,
            height: hr * 0.86,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.95),
        );
      case PetSpecies.tuxedoDog:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx + hr * 0.42, hy - hr * 0.36),
            width: hr * 0.70,
            height: hr * 0.64,
          ),
          Paint()..color = style.secondary.withValues(alpha: 0.40),
        );
    }
  }

  // ---------------------------------------------------------------- ears

  void _drawEars(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    bool sleeping,
    bool sleepy,
    bool low,
  ) {
    final droop = sleeping
        ? 0.55
        : sleepy
        ? 0.22
        : low
        ? 0.48
        : mood == PetMood.thirsty
        ? 0.08
        : 0.0;

    final floppy = species == PetSpecies.tuxedoDog;
    for (final sign in const [-1.0, 1.0]) {
      final base = Offset(hx + sign * hr * 0.56, hy - hr * 0.58);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(sign * droop);
      canvas.translate(-base.dx, -base.dy);
      if (floppy) {
        _drawFloppyEar(canvas, hx, hy, hr, sign);
      } else {
        _drawUprightEar(canvas, hx, hy, hr, sign);
      }
      canvas.restore();
    }
  }

  void _drawUprightEar(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    double sign,
  ) {
    final spread = 0.92 + 0.12 * style.earRoundness;
    final outer = Offset(hx + sign * hr * 0.68 * spread, hy - hr * 0.50);
    final inner = Offset(hx + sign * hr * 0.10, hy - hr * 0.90);
    final tip = Offset(
      hx + sign * hr * 0.56 * spread,
      hy - hr * (1.18 + 0.04 * style.earRoundness),
    );

    final path = Path()
      ..moveTo(outer.dx, outer.dy)
      ..quadraticBezierTo(
        hx + sign * hr * 0.66 * spread,
        hy - hr * 1.02,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        hx + sign * hr * 0.28,
        hy - hr * 0.98,
        inner.dx,
        inner.dy,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = style.base);
    canvas.drawPath(path, _stroke(outline, style.outlineWidth));

    final center = Offset(hx + sign * hr * 0.36, hy - hr * 0.80);
    final innerPath = Path()
      ..moveTo(_toward(outer, center, 0.42).dx, _toward(outer, center, 0.42).dy)
      ..quadraticBezierTo(
        _toward(
          Offset(hx + sign * hr * 0.66 * spread, hy - hr * 1.02),
          center,
          0.42,
        ).dx,
        _toward(
          Offset(hx + sign * hr * 0.66 * spread, hy - hr * 1.02),
          center,
          0.42,
        ).dy,
        _toward(tip, center, 0.42).dx,
        _toward(tip, center, 0.42).dy,
      )
      ..quadraticBezierTo(
        _toward(Offset(hx + sign * hr * 0.28, hy - hr * 0.98), center, 0.42).dx,
        _toward(Offset(hx + sign * hr * 0.28, hy - hr * 0.98), center, 0.42).dy,
        _toward(inner, center, 0.42).dx,
        _toward(inner, center, 0.42).dy,
      )
      ..close();
    canvas.drawPath(
      innerPath,
      Paint()..color = style.blush.withValues(alpha: 0.35),
    );
  }

  void _drawFloppyEar(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    double sign,
  ) {
    final center = Offset(hx + sign * hr * 0.86, hy + hr * 0.10);
    final width = hr * 0.54;
    final height = hr * 0.98;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sign * 0.28);
    final rect = Rect.fromCenter(
      center: Offset(0, hr * 0.20),
      width: width,
      height: height,
    );
    final rr = RRect.fromRectAndRadius(
      rect,
      Radius.circular(isQ ? width * 0.48 : width * 0.36),
    );
    canvas.drawRRect(rr, Paint()..color = style.secondary);
    canvas.drawRRect(rr, _stroke(outline, style.outlineWidth));
    canvas.restore();
  }

  Offset _toward(Offset from, Offset to, double t) =>
      Offset(from.dx + (to.dx - from.dx) * t, from.dy + (to.dy - from.dy) * t);

  // ---------------------------------------------------------------- face

  void _drawFace(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    double t,
    bool sleeping,
    bool sleepy,
    bool lively,
    bool low,
    bool eating,
    bool thirsty,
    bool full,
    bool celebrating,
  ) {
    final isCat = species.isCat;
    final eyeY = hy - hr * 0.02;
    final eyeX = hr * 0.36;
    final eyeR = (isCat ? 6.2 : 6.8) * style.eyeScale;
    final closed = sleeping || (mood == PetMood.idle && t > 0.90 && t < 0.955);
    final happyEyes = lively || full || celebrating;
    final half = sleepy && !sleeping;

    // 口鼻底色（狗更明显）
    if (!isCat) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hx, hy + hr * 0.34),
          width: hr * 0.96,
          height: hr * 0.60,
        ),
        Paint()..color = style.belly,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hx, hy + hr * 0.34),
          width: hr * 0.96,
          height: hr * 0.60,
        ),
        _stroke(outline, style.outlineWidth * 0.7),
      );
    }

    for (final sign in const [-1.0, 1.0]) {
      final c = Offset(hx + sign * eyeX, eyeY);
      if (closed) {
        _drawClosedEye(canvas, c, eyeR, sleeping);
      } else if (happyEyes) {
        _drawSmileEye(canvas, c, eyeR);
      } else if (half) {
        _drawHalfEye(canvas, c, eyeR);
      } else if (low) {
        _drawHalfEye(canvas, c, eyeR * 0.9);
      } else {
        final pupilShift = thirsty ? -1.8 : 0.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + pupilShift),
            width: eyeR * 1.6,
            height: eyeR * 1.9,
          ),
          Paint()..color = style.eye,
        );
        canvas.drawCircle(
          Offset(c.dx - eyeR * 0.30, c.dy - eyeR * 0.55 + pupilShift),
          eyeR * 0.34,
          Paint()..color = style.belly,
        );
      }
    }

    // 腮红
    if (style.blushOpacity > 0.01) {
      for (final sign in const [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(hx + sign * hr * 0.62, hy + hr * 0.24),
            width: hr * 0.34,
            height: hr * 0.20,
          ),
          Paint()..color = style.blush.withValues(alpha: style.blushOpacity),
        );
      }
    }

    // 鼻子
    if (isCat) {
      final nose = Path()
        ..moveTo(hx - 5.4, hy + hr * 0.16)
        ..lineTo(hx + 5.4, hy + hr * 0.16)
        ..lineTo(hx, hy + hr * 0.24)
        ..close();
      canvas.drawPath(nose, Paint()..color = style.nose);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hx, hy + hr * 0.20),
          width: 14,
          height: 10,
        ),
        Paint()..color = style.eye,
      );
    }

    _drawMouth(
      canvas,
      hx,
      hy,
      hr,
      t,
      isCat,
      eating,
      thirsty,
      lively,
      sleeping,
      low,
    );

    // 胡须
    if (isCat) {
      final whisker = _stroke(outline.withValues(alpha: 0.32), isQ ? 1.6 : 1.1);
      for (var i = -1; i <= 1; i++) {
        final y = hy + hr * 0.24 + i * hr * 0.10;
        canvas.drawLine(
          Offset(hx - hr * 0.20, y),
          Offset(hx - hr * 0.92, y + i * hr * 0.06 - 2),
          whisker,
        );
        canvas.drawLine(
          Offset(hx + hr * 0.20, y),
          Offset(hx + hr * 0.92, y + i * hr * 0.06 - 2),
          whisker,
        );
      }
    }
  }

  void _drawClosedEye(Canvas canvas, Offset c, double r, bool sleeping) {
    final paint = _stroke(style.eye, isQ ? 2.6 : 1.8);
    final dir = sleeping ? -1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.85, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + dir * r * 1.05, c.dx + r * 0.85, c.dy),
      paint,
    );
  }

  void _drawSmileEye(Canvas canvas, Offset c, double r) {
    final paint = _stroke(style.eye, isQ ? 2.8 : 2.0);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.9, c.dy + r * 0.20)
        ..quadraticBezierTo(
          c.dx,
          c.dy - r * 1.05,
          c.dx + r * 0.9,
          c.dy + r * 0.20,
        ),
      paint,
    );
  }

  void _drawHalfEye(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.24),
      width: r * 1.55,
      height: r * 0.86,
    );
    canvas.drawArc(rect, 0, math.pi, true, Paint()..color = style.eye);
    canvas.drawLine(
      Offset(c.dx - r * 0.82, c.dy + r * 0.02),
      Offset(c.dx + r * 0.82, c.dy + r * 0.02),
      _stroke(style.eye, isQ ? 2.4 : 1.6),
    );
  }

  void _drawMouth(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    double t,
    bool isCat,
    bool eating,
    bool thirsty,
    bool lively,
    bool sleeping,
    bool low,
  ) {
    final mouthY = hy + hr * (isCat ? 0.34 : 0.48);
    final dark = Paint()..color = style.eye;
    final line = _stroke(style.eye, isQ ? 2.2 : 1.5);

    if (eating) {
      final chew = 2.2 + math.sin(t * math.pi * 12).abs() * 2.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hx, mouthY + 2),
          width: 11,
          height: chew,
        ),
        dark,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hx, mouthY + chew * 0.55),
          width: 6.4,
          height: chew * 0.55,
        ),
        Paint()..color = style.blush,
      );
      return;
    }

    if (thirsty) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, mouthY + 3), width: 10, height: 7),
        dark,
      );
      final tongue = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(hx, mouthY + hr * 0.20),
          width: 7,
          height: hr * 0.24,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(tongue, Paint()..color = style.blush);
      return;
    }

    if (sleeping) {
      canvas.drawLine(Offset(hx - 4, mouthY), Offset(hx + 4, mouthY), line);
      return;
    }

    if (lively) {
      final rect = Rect.fromCenter(
        center: Offset(hx, mouthY + hr * 0.04),
        width: 22,
        height: 16,
      );
      canvas.drawArc(rect, 0, math.pi, true, dark);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(hx, mouthY + hr * 0.12),
          width: 12,
          height: 9,
        ),
        0,
        math.pi,
        true,
        Paint()..color = style.blush.withValues(alpha: 0.8),
      );
      return;
    }

    if (isCat) {
      canvas.drawPath(
        Path()
          ..moveTo(hx - hr * 0.20, mouthY - 1)
          ..quadraticBezierTo(hx - hr * 0.10, mouthY + 6, hx, mouthY + 1)
          ..quadraticBezierTo(
            hx + hr * 0.10,
            mouthY + 6,
            hx + hr * 0.20,
            mouthY - 1,
          ),
        line,
      );
    } else {
      canvas.drawLine(
        Offset(hx, mouthY - hr * 0.02),
        Offset(hx, mouthY + 4),
        line,
      );
      canvas.drawPath(
        Path()
          ..moveTo(hx - 7, mouthY + 5)
          ..quadraticBezierTo(hx, mouthY + 9, hx + 7, mouthY + 5),
        line,
      );
    }
  }

  // ------------------------------------------------------------ particles

  void _drawParticles(
    Canvas canvas,
    double hx,
    double hy,
    double hr,
    double t,
    double trans,
    bool sleeping,
    bool sleepy,
    bool lively,
    bool eating,
    bool thirsty,
    bool full,
    bool celebrating,
    bool transitioning,
  ) {
    if (sleeping || sleepy) {
      final count = sleeping ? 3 : 1;
      for (var i = 0; i < count; i++) {
        final phase = (t + i * 0.22) % 1.0;
        _drawZ(
          canvas,
          Offset(
            hx + hr * (0.85 + i * 0.32),
            hy - hr * (0.95 + i * 0.42) - phase * 10,
          ),
          (isQ ? 13.0 : 10.0) + i * 2,
          outline.withValues(alpha: (0.55 - i * 0.12).clamp(0.15, 0.55)),
        );
      }
    }

    if (lively) {
      for (var i = 0; i < 2; i++) {
        final phase = (t + i * 0.35) % 1.0;
        _drawHeart(
          canvas,
          Offset(
            hx + (i == 0 ? -1 : 1) * hr * 0.95,
            hy - hr * (0.75 + phase * 0.7),
          ),
          (isQ ? 7.0 : 5.5) + i,
          style.blush.withValues(alpha: 0.75 - phase * 0.35),
        );
      }
    }

    if (full) {
      for (var i = 0; i < 3; i++) {
        final phase = (t + i * 0.30) % 1.0;
        canvas.drawCircle(
          Offset(hx + hr * (0.64 + i * 0.18), hy - hr * (0.85 + phase * 0.55)),
          3.0 + i * 1.1,
          Paint()..color = accent.withValues(alpha: 0.50 - phase * 0.24),
        );
      }
    }

    if (thirsty) {
      for (var i = 0; i < 3; i++) {
        final phase = (t + i * 0.33) % 1.0;
        _drawDrop(
          canvas,
          Offset(214 + i * 14, 200 - phase * 22),
          4.4,
          water.withValues(alpha: 0.55 - phase * 0.25),
        );
      }
    }

    if (eating) {
      for (var i = 0; i < 3; i++) {
        final phase = (t + i * 0.28) % 1.0;
        canvas.drawCircle(
          Offset(hx + 18 + i * 9, hy + hr * 0.55 + phase * 12),
          1.8 + i * 0.5,
          Paint()
            ..color = style.secondary.withValues(alpha: 0.55 - phase * 0.3),
        );
      }
    }

    if (transitioning) {
      for (var i = 0; i < 6; i++) {
        final angle = i / 6 * math.pi * 2 + trans * 1.4;
        final radius = hr * (1.05 + 0.25 * math.sin(trans * math.pi));
        _drawSparkle(
          canvas,
          Offset(
            hx + math.cos(angle) * radius,
            hy + math.sin(angle) * radius * 0.9,
          ),
          4.6 + (i % 3) * 1.6,
          i.isEven ? accent : style.blush,
          trans,
        );
      }
    }

    if (celebrating) {
      for (var i = 0; i < 8; i++) {
        final angle = i / 8 * math.pi * 2 + 0.4;
        final radius = hr * (0.95 + 0.45 * ((t + i * 0.11) % 1.0));
        final pos = Offset(
          hx + math.cos(angle) * radius,
          hy + math.sin(angle) * radius * 0.86,
        );
        final color = i % 3 == 0
            ? accent
            : i % 3 == 1
            ? style.blush
            : water;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + t * math.pi);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 6, height: 3.2),
            const Radius.circular(1.2),
          ),
          Paint()..color = color.withValues(alpha: 0.85),
        );
        canvas.restore();
      }
    }
  }

  void _drawZ(Canvas canvas, Offset c, double size, Color color) {
    final p = Path()
      ..moveTo(c.dx - size * 0.5, c.dy - size * 0.5)
      ..lineTo(c.dx + size * 0.5, c.dy - size * 0.5)
      ..lineTo(c.dx - size * 0.5, c.dy + size * 0.5)
      ..lineTo(c.dx + size * 0.5, c.dy + size * 0.5);
    canvas.drawPath(p, _stroke(color, isQ ? 2.4 : 1.7));
  }

  void _drawHeart(Canvas canvas, Offset c, double size, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + size * 0.55)
      ..cubicTo(
        c.dx - size * 1.3,
        c.dy - size * 0.20,
        c.dx - size * 0.55,
        c.dy - size * 1.05,
        c.dx,
        c.dy - size * 0.35,
      )
      ..cubicTo(
        c.dx + size * 0.55,
        c.dy - size * 1.05,
        c.dx + size * 1.3,
        c.dy - size * 0.20,
        c.dx,
        c.dy + size * 0.55,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _drawDrop(Canvas canvas, Offset c, double size, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - size)
      ..quadraticBezierTo(
        c.dx + size * 0.9,
        c.dy + size * 0.35,
        c.dx,
        c.dy + size * 0.7,
      )
      ..quadraticBezierTo(
        c.dx - size * 0.9,
        c.dy + size * 0.35,
        c.dx,
        c.dy - size,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _drawSparkle(
    Canvas canvas,
    Offset c,
    double size,
    Color color,
    double opacity,
  ) {
    final p = Path()
      ..moveTo(c.dx, c.dy - size)
      ..quadraticBezierTo(
        c.dx + size * 0.18,
        c.dy - size * 0.18,
        c.dx + size,
        c.dy,
      )
      ..quadraticBezierTo(
        c.dx + size * 0.18,
        c.dy + size * 0.18,
        c.dx,
        c.dy + size,
      )
      ..quadraticBezierTo(
        c.dx - size * 0.18,
        c.dy + size * 0.18,
        c.dx - size,
        c.dy,
      )
      ..quadraticBezierTo(
        c.dx - size * 0.18,
        c.dy - size * 0.18,
        c.dx,
        c.dy - size,
      )
      ..close();
    canvas.drawPath(
      p,
      Paint()..color = color.withValues(alpha: 0.85 * opacity.clamp(0.0, 1.0)),
    );
  }

  void _drawBowl(Canvas canvas, double t) {
    final rect = Rect.fromCenter(
      center: const Offset(236, 232),
      width: 58,
      height: 20,
    );
    canvas.drawOval(rect, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawOval(
      rect,
      _stroke(outline.withValues(alpha: 0.35), style.outlineWidth),
    );
    final waterRect = Rect.fromCenter(
      center: const Offset(236, 236),
      width: 44,
      height: 8,
    );
    canvas.drawOval(waterRect, Paint()..color = water.withValues(alpha: 0.45));
    final ripple = (t * 2) % 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(236, 236),
        width: 44 * (0.4 + ripple * 0.6),
        height: 8 * (0.4 + ripple * 0.6),
      ),
      _stroke(water.withValues(alpha: 0.5 - ripple * 0.35), 1.2),
    );
  }

  void _drawCollar(Canvas canvas, double hx, double hy, double hr) {
    final y = hy + hr * 0.92;
    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(hx, y),
        width: hr * 1.04,
        height: hr * 0.16,
      ),
      Radius.circular(hr * 0.08),
    );
    canvas.drawRRect(band, Paint()..color = accent);
    canvas.drawRRect(band, _stroke(outline, style.outlineWidth * 0.8));
    canvas.drawCircle(
      Offset(hx, y + hr * 0.18),
      hr * 0.09,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(hx, y + hr * 0.18),
      hr * 0.09,
      _stroke(outline, style.outlineWidth * 0.8),
    );
  }

  // ---------------------------------------------------------------- utils

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static bool _sameStyle(PetStyle a, PetStyle b) =>
      a.base == b.base &&
      a.secondary == b.secondary &&
      a.belly == b.belly &&
      a.nose == b.nose &&
      a.eye == b.eye &&
      a.blush == b.blush &&
      a.headScale == b.headScale &&
      a.bodyRoundness == b.bodyRoundness &&
      a.eyeScale == b.eyeScale &&
      a.outlineWidth == b.outlineWidth &&
      a.blushOpacity == b.blushOpacity &&
      a.earRoundness == b.earRoundness;

  @override
  bool shouldRepaint(covariant PetPainter old) {
    return old.species != species ||
        old.mood != mood ||
        old.isQ != isQ ||
        old.axes.vitality != axes.vitality ||
        old.axes.coat != axes.coat ||
        old.axes.mood != axes.mood ||
        old.axes.hydration != axes.hydration ||
        old.outline != outline ||
        old.ground != ground ||
        old.accent != accent ||
        old.water != water ||
        old.shadowColor != shadowColor ||
        old.shadowOffset != shadowOffset ||
        !_sameStyle(old.style, style);
  }
}
