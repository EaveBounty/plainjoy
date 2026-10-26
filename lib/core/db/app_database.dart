import 'package:sembast/sembast.dart';

import 'database_factory.dart';

class AppDatabase {
  final Database db;

  AppDatabase(this.db);

  static Future<AppDatabase> open() async {
    final database = await openAppDatabase();
    return AppDatabase(database);
  }

  final foods = StoreRef<String, Map<String, Object?>>('foods');
  final entries = StoreRef<String, Map<String, Object?>>('entries');
  final recipes = StoreRef<String, Map<String, Object?>>('recipes');
  final containers = StoreRef<String, Map<String, Object?>>('containers');
  final referenceObjects = StoreRef<String, Map<String, Object?>>('reference_objects');
  final preferences = StoreRef<String, Map<String, Object?>>('preferences');
  final plans = StoreRef<String, Map<String, Object?>>('plans');
  final pets = StoreRef<String, Map<String, Object?>>('pets');
  final petSnapshots = StoreRef<String, Map<String, Object?>>('pet_snapshots');
  final profiles = StoreRef<String, Map<String, Object?>>('profiles');
  final settings = StoreRef<String, Map<String, Object?>>('settings');
  final scoreSnapshots = StoreRef<String, Map<String, Object?>>('score_snapshots');
  final aiJobs = StoreRef<String, Map<String, Object?>>('ai_jobs');

  Future<void> close() => db.close();
}
