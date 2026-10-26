import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/pet.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../pet/pet_stage.dart';

/// 首启：画风 → 使用强度。两屏都不强制填身高体重。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  ThemeVariant _theme = ThemeVariant.editorial;
  PrecisionTier _precision = PrecisionTier.quick;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skip = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .completeOnboarding(
            theme: skip ? ThemeVariant.editorial : _theme,
            precision: skip ? PrecisionTier.quick : _precision,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请再试一次。')));
    }
  }

  void _next() {
    if (_page < 2) {
      _controller.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('有味清欢', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '不用称，也知道今天差哪一口。',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_page + 1} / 3',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 6,
                    ),
                    width: i == _page ? 22 : 7,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == _page ? t.ink : t.hairline,
                      borderRadius: BorderRadius.circular(t.pillRadius),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: [_whyStep(), _themeStep(), _precisionStep()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => _finish(skip: true),
                    child: const Text('跳过'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 156,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_page == 2 ? '开始' : '下一步'),
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

  Widget _whyStep() {
    final t = context.tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('先把「为什么」说清楚', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: BoxDecoration(
              color: t.surfaceAlt.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(t.radiusMd),
              border: Border(left: BorderSide(color: t.ink.withValues(alpha: 0.55), width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「安身之本，必资于食；救疾之速，必凭于药。不知食宜者，不足以存生也。」',
                  style: TextStyle(
                    fontFamily: t.titleFont,
                    fontSize: 13.5,
                    height: 1.9,
                    letterSpacing: 0.5,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '—— 孙思邈《备急千金要方·食治》',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _whyRow(
            '01',
            '一餐估错，不影响结论',
            '单餐误差 ±20% 是常态。决定健康的是 7 天的结构：食物组、钠、蛋白、纤维。拍照或一句话，10 秒记一餐。',
          ),
          _whyRow(
            '02',
            '同一种饭，对不同人结论相反',
            '高血压看钠；肾功能看钾、磷、蛋白；痛风看嘌呤与果糖；缺铁看铁与维 C。病况、用药、口味不同，目标与建议就不同。',
          ),
          _whyRow(
            '03',
            '先补下一餐，不排满 21 餐',
            '记录是后视镜，规划是方向盘。按缺口补 1–5 餐「补丁餐」，保留你原本的吃法，不用重排整周。',
          ),
          _whyRow(
            '04',
            '数据默认留在本机',
            '不注册、不上传；接 DeepSeek 才需联网，且只发送当次输入。没有 key 时用本地规则降级。',
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in const ['不用称', '区间估算', '本地优先', '可接 DeepSeek'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(t.pillRadius),
                    border: Border.all(color: t.hairline),
                  ),
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '有味清欢不是医疗器械，不提供诊断、处方或治疗方案。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _whyRow(String index, String title, String body) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              index,
              style: TextStyle(
                fontFamily: t.numberFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.inkTertiary,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.inkSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('先选一种画法', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(
            '同一只宠物，两种画法。切换只影响界面，不影响评分与记录。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.inkSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stylePreview(ThemeVariant.editorial),
              const SizedBox(width: 10),
              _stylePreview(ThemeVariant.q),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '之后可以在设置里随时换。默认是报告版。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _stylePreview(ThemeVariant variant) {
    final outer = context.tokens;
    final selected = _theme == variant;
    final previewTheme = variant == ThemeVariant.q
        ? AppTheme.q()
        : AppTheme.editorial();
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _theme = variant),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outer.radiusLg + 3),
            border: Border.all(
              color: selected ? outer.accent : outer.hairline,
              width: selected ? 2 : outer.borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(outer.radiusLg),
            child: Theme(
              data: previewTheme,
              child: Builder(
                builder: (inner) {
                  final t = inner.tokens;
                  return Container(
                    color: t.surface,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              variant.label,
                              style: Theme.of(inner).textTheme.labelLarge,
                            ),
                            const Spacer(),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: t.ink,
                              ),
                          ],
                        ),
                        PetStage(
                          species: PetSpecies.calicoCat,
                          signal: PetSignal.idle,
                          axes: const PetAxes(
                            vitality: 72,
                            coat: 70,
                            mood: 74,
                            hydration: 68,
                          ),
                          height: 116,
                          animated: false,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          variant.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(inner).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _precisionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你打算怎么记', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(
            '只是默认档位，记录时随时能改。不填身高体重也能开始。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.inkSecondary,
            ),
          ),
          const SizedBox(height: 18),
          for (final tier in PrecisionTier.values) ...[
            _precisionTile(tier),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(
            '估算会带区间。宁可说「大概」，不假装精确。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _precisionTile(PrecisionTier tier) {
    final t = context.tokens;
    final selected = _precision == tier;
    return GestureDetector(
      onTap: () => setState(() => _precision = tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.06) : t.surface,
          borderRadius: BorderRadius.circular(t.radiusLg),
          border: Border.all(
            color: selected ? t.accent : t.hairline,
            width: selected ? 2 : t.borderWidth,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.accent : t.inkTertiary,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(tier.hint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
