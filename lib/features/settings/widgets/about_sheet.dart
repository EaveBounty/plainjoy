import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'settings_widgets.dart';

const String appVersion = '0.2.0';

Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const AboutSheet(),
  );
}

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    border: Border.all(color: t.hairline, width: t.borderWidth),
                  ),
                  child: Icon(Icons.pets_rounded, color: t.ink, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('清欢', style: textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        '不用称，也知道今天差哪一口。',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.radiusMd),
                border: Border.all(color: t.hairline, width: t.borderWidth),
              ),
              child: Column(
                children: [
                  _row(context, '版本', appVersion),
                  const SizedBox(height: 8),
                  _row(context, '数据', '本地优先，无账号，无云同步'),
                  const SizedBox(height: 8),
                  _row(context, '食物库', '102 条独立估算；本地全量库可选，不随公开仓库分发'),
                  const SizedBox(height: 8),
                  _row(context, 'AI', '可选增强；只发送当次输入，不含健康档案'),
                  const SizedBox(height: 8),
                  _row(context, '隐私', '本地存储、无账号、无云同步；Android 自动备份已关闭'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppDisclaimer(),
            const SizedBox(height: 12),
            const InfoNote(
              icon: Icons.health_and_safety_outlined,
              title: '不做什么',
              text: '不做疾病诊断，不做风险百分比，不提供处方，不调整药物。'
                  '慢性肾病、孕期、用药期间的饮食目标请以医生或注册营养师意见为准。',
            ),
            const SizedBox(height: 12),
            const InfoNote(
              icon: Icons.functions_rounded,
              title: '误差说明',
              text: '份量与营养值都是区间估算。快速档误差约 ±35–45%，标准档约 ±20–25%，'
                  '精确档约 ±8–10%。记录不足时不给总分。',
            ),
            const SizedBox(height: 16),
            Text(
              'PolyForm Noncommercial License 1.0.0 · 商业使用需单独授权',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Required Notice: Copyright 2026 长沙市果垂素宇工程设计有限公司',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'https://github.com/EaveBounty/plainjoy',
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.ink),
          ),
        ),
      ],
    );
  }
}
