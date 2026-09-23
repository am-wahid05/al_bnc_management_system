import 'package:sqflite/sqflite.dart';

class SyncStatusSnapshot {
  const SyncStatusSnapshot({required this.pendingCount, required this.failedCount, this.lastSuccessfulSync});

  final int pendingCount;
  final int failedCount;
  final DateTime? lastSuccessfulSync;

  bool get hasFailures => failedCount > 0;
  bool get hasPending => pendingCount > 0;
}

class SyncStatusRepository {
  const SyncStatusRepository(this.database);

  final Database database;

  Future<SyncStatusSnapshot> load() async {
    final pending = await database.rawQuery('''
      SELECT COUNT(*) AS count FROM deliveries
      WHERE synchronization_status IN (?, ?, ?, ?)
    ''', ['localOnly', 'pendingSync', 'pending', 'syncFailed']);
    final failed = await database.rawQuery('''
      SELECT COUNT(*) AS count FROM deliveries
      WHERE synchronization_status IN (?, ?)
    ''', ['syncFailed', 'failed']);
    final latest = await database.rawQuery('''
      SELECT MAX(synced_at) AS synced_at FROM deliveries
      WHERE synchronization_status IN (?, ?) AND synced_at IS NOT NULL
    ''', ['synced', 'synchronized']);
    final rawLatest = latest.single['synced_at'];
    return SyncStatusSnapshot(
      pendingCount: pending.single['count']! as int,
      failedCount: failed.single['count']! as int,
      lastSuccessfulSync: rawLatest == null ? null : DateTime.tryParse(rawLatest as String),
    );
  }
}
