import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final dbDir = Directory(p.join(dir.path, 'plainjoy'));
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  return databaseFactoryIo.openDatabase(p.join(dbDir.path, 'plainjoy.db'));
}
