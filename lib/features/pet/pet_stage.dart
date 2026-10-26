import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/pet.dart';
import '../../core/theme/app_tokens.dart';
import 'pet_painter.dart';

/// 宠物舞台：负责动画节拍、状态切换与点击，不依赖任何 provider。
///
/// 绘制只在 [RepaintBoundary] 内重绘，宿主页面不会逐帧重建。
class PetStage extends StatefulWidget {
  final PetSpecies species;
  final PetSignal signal;
  final PetAxes axes;
  final double height;
  final bool animated;
  final VoidCallback? onTap;

  const PetStage({
    super.key,
    required this.species,
    required this.signal,
    required this.axes,
    this.height = 240,
    this.animated = true,
    this.onTap,
  });

  @override
  State<PetStage> createState() => _PetStageState();
}

class _PetStageState extends State<PetStage> with TickerProviderStateMixin {
  late final AnimationController _loop;
  late final AnimationController _transition;
  Timer? _napTimer;
  bool _napping = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      value: 1,
    );
    if (widget.animated) {
      _loop.repeat();
      _scheduleNap();
    } else {
      _loop.value = 0.28;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _syncMotion();
    }
  }

  @override
  void didUpdateWidget(covariant PetStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.species != widget.species &&
        widget.animated &&
        !_reduceMotion) {
      _transition.forward(from: 0);
    }
    if (oldWidget.signal != widget.signal ||
        oldWidget.axes.vitality != widget.axes.vitality) {
      _wake();
      _scheduleNap();
    }
    if (oldWidget.animated != widget.animated) {
      _syncMotion();
      _scheduleNap();
    }
  }

  void _syncMotion() {
    if (widget.animated && !_reduceMotion) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      if (_loop.value == 0) _loop.value = 0.28;
    }
  }

  void _scheduleNap() {
    _napTimer?.cancel();
    if (!widget.animated || _reduceMotion) return;
    if (widget.signal != PetSignal.idle) {
      if (_napping && mounted) setState(() => _napping = false);
      return;
    }
    _napTimer = Timer(const Duration(seconds: 22), () {
      if (!mounted || widget.signal != PetSignal.idle) return;
      setState(() => _napping = true);
    });
  }

  void _wake() {
    _napTimer?.cancel();
    if (_napping && mounted) setState(() => _napping = false);
  }

  void _handleTap() {
    _wake();
    _scheduleNap();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _napTimer?.cancel();
    _loop.dispose();
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final baseMood = _napping
        ? PetMood.sleep
        : resolvePetMood(signal: widget.signal, axes: widget.axes);

    return Semantics(
      label: '${widget.species.label}，${baseMood.label}',
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _handleTap,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _transition,
              builder: (context, _) {
                final inTransition =
                    widget.animated &&
                    !_reduceMotion &&
                    _transition.isAnimating;
                return CustomPaint(
                  painter: PetPainter(
                    species: widget.species,
                    style: t.petStyle,
                    isQ: t.isQ,
                    mood: inTransition ? PetMood.transition : baseMood,
                    axes: widget.axes,
                    animation: _loop,
                    transition: _transition,
                    outline: t.ink,
                    ground: t.inkTertiary,
                    accent: t.accent,
                    water: t.low,
                    shadowColor: t.hardShadowColor,
                    shadowOffset: t.hardShadowOffset,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String petSignalLabel(PetSignal signal) => switch (signal) {
  PetSignal.idle => '安静',
  PetSignal.hungry => '想吃',
  PetSignal.thirsty => '想喝水',
  PetSignal.sleepy => '犯困',
  PetSignal.lowEnergy => '想休息',
  PetSignal.proud => '高兴',
  PetSignal.celebrate => '庆祝',
};
