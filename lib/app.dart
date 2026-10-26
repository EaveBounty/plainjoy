import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/enums.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PlainjoyApp()));
}

class PlainjoyApp extends ConsumerWidget {
  const PlainjoyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.theme == ThemeVariant.q ? AppTheme.q() : AppTheme.editorial();
    return MaterialApp(
      title: '清欢',
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeMode: ThemeMode.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeAnimationDuration: const Duration(milliseconds: 320),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
            disableAnimations: settings.reduceMotion || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppGate(),
    );
  }
}

/// 启动闸门：开屏动画与数据库初始化并行，任一未完成都不切页。
/// 开屏最短 620ms，避免「闪一下就没了」；数据慢时自然延长。
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  static const _minSplash = Duration(milliseconds: 620);
  bool _minElapsed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minSplash, () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final data = state.asData?.value;
    final ready = _minElapsed && (state.hasError || data != null);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !ready
          ? const SplashPage(key: ValueKey('splash'))
          : state.hasError
              ? ErrorPage(key: const ValueKey('error'), error: state.error!)
              : data!.settings.onboardingDone
                  ? const AppShell(key: ValueKey('shell'))
                  : const OnboardingPage(key: ValueKey('onboarding')),
    );
  }
}

class ErrorPage extends StatelessWidget {
  final Object error;
  const ErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: t.veryHigh, size: 36),
              const SizedBox(height: 12),
              Text('启动失败', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
