import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  BackupService(
    this.database, {
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? now,
  })  : _directoryProvider = directoryProvider ?? _defaultDirectory,
        _now = now ?? DateTime.now;

  final Database database;
  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _now;

  static const _businessTables = [
    'products',
    'deliveries',
    'delivery_bag_weights',
    'import_logs',
  ];

  Future<File> createBackup({String? filename}) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _businessTables) {
      tables[table] = await database.query(table);
    }
    final archive = <String, Object?>{
      'format': 'albnc-business-backup',
      'version': 1,
      'created_at': _now().toUtc().toIso8601String(),
      'tables': tables,
    };
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File(path.join(
      directory.path,
      filename ?? 'ALBNC_Backup_${_fileDate(_now())}.json',
    ));
    return file.writeAsString(jsonEncode(archive), flush: true);
  }

  Future<File> restoreBackup(File backupFile) async {
    final contents = await backupFile.readAsString();
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'albnc-business-backup' ||
        decoded['version'] != 1) {
      throw const FormatException('This is not a supported ALBNC business backup');
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException('Backup tables are missing');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _businessTables) {
      final rawRows = rawTables[table];
      if (rawRows is! List) {
        throw FormatException('Backup table is missing: $table');
      }
      tables[table] = rawRows
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();
    }

    final safetyBackup = await createBackup(
      filename: 'ALBNC_PreRestore_${_fileDate(_now())}.json',
    );
    await database.transaction((transaction) async {
      await transaction.delete('delivery_bag_weights');
      await transaction.delete('deliveries');
      await transaction.delete('import_logs');
      await transaction.delete('products');
      for (final table in ['products', 'deliveries', 'delivery_bag_weights', 'import_logs']) {
        for (final row in tables[table]!) {
          await transaction.insert(table, row);
        }
      }
    });
    return safetyBackup;
  }

  static String _fileDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}${date.millisecond.toString().padLeft(3, '0')}';

  static Future<Directory> _defaultDirectory() async =>
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
}
