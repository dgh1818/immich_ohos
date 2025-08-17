import 'package:drift/drift.dart';
//import 'package:drift_flutter/drift_flutter.dart';
import 'package:immich_mobile/domain/interfaces/db.interface.dart';
import 'package:immich_mobile/infrastructure/entities/log.entity.dart';

import 'package:drift_sqflite/drift_sqflite.dart';

import 'logger_db.repository.drift.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(join(docs.path, 'immich_logs'));
    return SqfliteQueryExecutor(path: file.path, singleInstance: false);
  });
}

@DriftDatabase(tables: [LogMessageEntity])
class DriftLogger extends $DriftLogger implements IDatabaseRepository {
  DriftLogger() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      //await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 500');
    },
  );
}
