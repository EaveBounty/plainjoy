import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/db/app_database.dart';
import 'core/db/app_repository.dart';
import 'core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await AppDatabase.open();
    final repository = AppRepository(database);
    await repository.seedIfNeeded();
    runApp(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlainjoyApp(),
      ),
    );
  } catch (error, stack) {
    // 数据库损坏/磁盘满时，至少给出可读错误，而不是停在原生启动页
    debugPrint('startup failed: $error\n$stack');
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.editorial(),
      home: ErrorPage(error: error),
    ));
  }
}
