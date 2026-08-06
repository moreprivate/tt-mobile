import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/database/migrations/migrations.dart';

/// Adds server endpoint knobs used by import/UI.
///
/// When adding more server columns later: put them in `servers_table.drift`,
/// then append `m.addColumn(...)` here (or start migrations_v6) and bump
/// [AppDatabase.schemaVersion].
class MigrationsV5 implements Migrations {
  const MigrationsV5();

  @override
  Future<void> migrate(GeneratedDatabase database, Migrator m) async {
    final appDatabase = database as db.AppDatabase;
    await m.addColumn(appDatabase.servers, appDatabase.servers.httpConnectionsNum);
    await m.addColumn(appDatabase.servers, appDatabase.servers.antiDpi);
  }
}
