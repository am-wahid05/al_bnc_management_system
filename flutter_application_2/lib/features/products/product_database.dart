import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract final class ProductDatabase {
  static Future<Database> open() async {
    final factory = _databaseFactory();
    final directory = await factory.getDatabasesPath();
    return factory.openDatabase(
      path.join(directory, 'albnc_ventures.db'),
      options: OpenDatabaseOptions(
        version: 11,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL COLLATE NOCASE UNIQUE,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await _createDeliveryTables(database);
          await _createUserTable(database);
          await _createReceiptSendTable(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createDeliveryTables(database);
          if (oldVersion < 3) await _addDeliveryDisplaySnapshots(database);
          if (oldVersion < 4) await _addSupplierTypeSnapshot(database);
          if (oldVersion < 5) await _createUserTable(database);
          if (oldVersion < 6) await _createImportLogTable(database);
          if (oldVersion < 7) await _addSynchronizationMetadata(database);
          if (oldVersion < 8) await _addSupplierTables(database);
          if (oldVersion < 9) await _addAnalyticsIndexes(database);
          if (oldVersion < 10) await _createUserTable(database);
          if (oldVersion < 11) await _createReceiptSendTable(database);
        },
      ),
    );
  }

  static Future<void> _createDeliveryTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS deliveries (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        recorded_by_user_id TEXT NOT NULL,
        status TEXT NOT NULL,
        synchronization_status TEXT NOT NULL,
        supplier_internal_id TEXT,
        supplier_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        supplier_type TEXT NOT NULL,
        synchronization_error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_attempt_at TEXT,
        synced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS delivery_bag_weights (
        delivery_id TEXT NOT NULL,
        bag_number INTEGER NOT NULL,
        weight REAL NOT NULL,
        PRIMARY KEY (delivery_id, bag_number),
        FOREIGN KEY (delivery_id) REFERENCES deliveries (id) ON DELETE CASCADE
      )
    ''');
    await _createSupplierTables(database);
  }

  static Future<void> _addDeliveryDisplaySnapshots(Database database) async {
    await _addColumnIfMissing(database, 'deliveries', 'supplier_name TEXT NOT NULL DEFAULT ""');
    await _addColumnIfMissing(database, 'deliveries', 'product_name TEXT NOT NULL DEFAULT ""');
  }

  static Future<void> _addSupplierTypeSnapshot(Database database) async {
    await _addColumnIfMissing(database, 'deliveries', 'supplier_type TEXT NOT NULL DEFAULT "farmer"');
  }

  static Future<void> _createUserTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        display_name TEXT NOT NULL,
        role TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createImportLogTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS import_logs (
        id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        imported_by_user_id TEXT NOT NULL,
        rows_total INTEGER NOT NULL,
        rows_imported INTEGER NOT NULL,
        rows_skipped INTEGER NOT NULL,
        rows_failed INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createReceiptSendTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS receipt_sends (
        id TEXT PRIMARY KEY,
        delivery_id TEXT NOT NULL,
        phone TEXT NOT NULL,
        channel TEXT NOT NULL,
        status TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        provider_reference TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_receipt_sends_delivery_id ON receipt_sends(delivery_id)');
  }

  static Future<void> _addSynchronizationMetadata(Database database) async {
    await _addColumnIfMissing(database, 'deliveries', 'synchronization_error TEXT');
    await _addColumnIfMissing(database, 'deliveries', 'sync_attempts INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(database, 'deliveries', 'last_sync_attempt_at TEXT');
    await _addColumnIfMissing(database, 'deliveries', 'synced_at TEXT');
  }

  static Future<void> _addSupplierTables(Database database) async {
    await _createSupplierTables(database);
    await _addColumnIfMissing(database, 'deliveries', 'supplier_internal_id TEXT');
  }

  static Future<void> _addAnalyticsIndexes(Database database) async {
    await database.execute('CREATE INDEX IF NOT EXISTS idx_deliveries_recorded_at ON deliveries(recorded_at)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_deliveries_supplier_id ON deliveries(supplier_id)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_deliveries_product_id ON deliveries(product_id)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_deliveries_supplier_type ON deliveries(supplier_type)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_delivery_bag_weights_delivery_id ON delivery_bag_weights(delivery_id)');
  }

  static Future<void> _createSupplierTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        internal_id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL UNIQUE,
        normalized_name TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        phone TEXT,
        town TEXT NOT NULL DEFAULT '',
        district TEXT NOT NULL DEFAULT '',
        region TEXT NOT NULL DEFAULT '',
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synchronization_status TEXT NOT NULL DEFAULT 'pendingSync',
        synchronization_error TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_normalized_name ON suppliers(normalized_name)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_supplier_id ON suppliers(supplier_id)');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS local_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _addColumnIfMissing(
    Database database,
    String table,
    String definition,
  ) async {
    final columnName = definition.split(' ').first;
    final columns = await database.rawQuery('PRAGMA table_info($table)');
    if (columns.any((column) => column['name'] == columnName)) return;
    await database.execute('ALTER TABLE $table ADD COLUMN $definition');
  }

  static DatabaseFactory _databaseFactory() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }
}