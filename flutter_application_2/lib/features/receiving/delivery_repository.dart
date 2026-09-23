import 'package:sqflite/sqflite.dart';

import '../../domain/models/delivery.dart';
import '../../domain/models/product.dart';
import '../../domain/models/supplier.dart';
import '../suppliers/supplier_repository.dart';

class DeliveryRepository {
  DeliveryRepository(this.database);

  final Database database;

  Future<void> save(Delivery delivery) async {
    if (await findById(delivery.id) != null) {
      throw DuplicateDeliveryException(delivery.id);
    }
    final createdAt = DateTime.now().toIso8601String();
    await database.transaction((transaction) async {
      await saveInTransaction(transaction, delivery, createdAt: createdAt);
    });
  }

  Future<void> saveInTransaction(
    DatabaseExecutor transaction,
    Delivery delivery, {
    String? createdAt,
  }) async {
    final columns = await transaction.rawQuery('PRAGMA table_info(deliveries)');
    final hasSupplierInternalId = columns.any((column) => column['name'] == 'supplier_internal_id');
    final row = <String, Object?>{
      'id': delivery.id,
      'supplier_id': delivery.supplier.id,
      'product_id': delivery.product.id,
      'recorded_at': delivery.recordedAt.toIso8601String(),
      'recorded_by_user_id': delivery.recordedByUserId,
      'status': delivery.status.name,
      'synchronization_status': delivery.synchronizationStatus.name,
      'supplier_name': delivery.supplier.name,
      'product_name': delivery.product.name,
      'supplier_type': delivery.supplier.type.name,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': delivery.updatedAt.toIso8601String(),
    };
    if (hasSupplierInternalId) row['supplier_internal_id'] = delivery.supplier.internalId;
    await transaction.insert('deliveries', row);

    for (var index = 0; index < delivery.bagWeights.length; index++) {
      await transaction.insert('delivery_bag_weights', {
        'delivery_id': delivery.id,
        'bag_number': index + 1,
        'weight': delivery.bagWeights[index],
      });
    }
  }

  Future<int> count() async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM deliveries',
    );
    return result.single['count']! as int;
  }

  Future<List<Delivery>> unsynchronized() async {
    final rows = await database.query(
      'deliveries',
      where: 'synchronization_status IN (?, ?, ?, ?)',
      whereArgs: ['localOnly', 'pendingSync', 'pending', 'syncFailed'],
      orderBy: 'recorded_at ASC',
    );
    return _loadDeliveries(rows);
  }

  Future<void> recordSyncAttempt(String id, DateTime attemptedAt) async {
    await database.rawUpdate(
      'UPDATE deliveries SET synchronization_status = ?, sync_attempts = sync_attempts + 1, last_sync_attempt_at = ? WHERE id = ?',
      ['pendingSync', attemptedAt.toIso8601String(), id],
    );
  }

  Future<void> markSynced(String id, DateTime syncedAt) async {
    await database.update(
      'deliveries',
      {'synchronization_status': 'synced', 'synchronization_error': null, 'synced_at': syncedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncFailed(String id, String error, DateTime attemptedAt) async {
    await database.update(
      'deliveries',
      {'synchronization_status': 'syncFailed', 'synchronization_error': error, 'last_sync_attempt_at': attemptedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Delivery>> forDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return forRange(start, end);
  }

  Future<List<Delivery>> forRange(
    DateTime start,
    DateTime end, {
    String? supplierId,
    String? productId,
  }) async {
    final clauses = <String>['recorded_at >= ?', 'recorded_at < ?'];
    final arguments = <Object?>[start.toIso8601String(), end.toIso8601String()];
    if (supplierId != null) {
      clauses.add('supplier_id = ?');
      arguments.add(supplierId);
    }
    if (productId != null) {
      clauses.add('product_id = ?');
      arguments.add(productId);
    }
    final rows = await database.query(
      'deliveries',
      where: clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'recorded_at DESC',
    );
    return _loadDeliveries(rows);
  }

  Future<Delivery?> findById(String id) async {
    final rows = await database.query(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (await _loadDeliveries(rows)).single;
  }

  Future<bool> hasLikelyDuplicate({
    required DateTime recordedAt,
    required String supplierId,
    String? supplierName,
    required String productId,
    required double totalWeight,
  }) async {
    final start = DateTime(recordedAt.year, recordedAt.month, recordedAt.day);
    final end = start.add(const Duration(days: 1));
    final rows = await database.query(
      'deliveries',
      columns: ['id'],
      where: 'recorded_at >= ? AND recorded_at < ? AND product_id = ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
        productId,
      ],
    );
    for (final row in rows) {
      final delivery = await findById(row['id']! as String);
        final sameSupplier = delivery != null &&
          (delivery.supplier.id == supplierId ||
            (supplierName != null &&
              SupplierRepository.normalizeName(delivery.supplier.name) ==
                SupplierRepository.normalizeName(supplierName)));
        if (sameSupplier &&
            (delivery.totalWeight - totalWeight).abs() < 0.01) {
        return true;
      }
    }
    return false;
  }

  Future<Delivery> updateWeights(String id, List<double> weights) async {
    final existing = await findById(id);
    if (existing == null) throw StateError('Delivery $id was not found');
    final corrected = Delivery(
      id: existing.id,
      supplier: existing.supplier,
      product: existing.product,
      recordedAt: existing.recordedAt,
      bagWeights: weights,
      recordedByUserId: existing.recordedByUserId,
      status: DeliveryStatus.corrected,
      synchronizationStatus: SynchronizationStatus.pending,
      updatedAt: DateTime.now(),
    );
    await database.transaction((transaction) async {
      await transaction.update(
        'deliveries',
        {
          'status': corrected.status.name,
          'synchronization_status': corrected.synchronizationStatus.name,
          'updated_at': corrected.updatedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await transaction.delete(
        'delivery_bag_weights',
        where: 'delivery_id = ?',
        whereArgs: [id],
      );
      for (var index = 0; index < corrected.bagWeights.length; index++) {
        await transaction.insert('delivery_bag_weights', {
          'delivery_id': id,
          'bag_number': index + 1,
          'weight': corrected.bagWeights[index],
        });
      }
    });
    return corrected;
  }

  Future<List<Delivery>> _loadDeliveries(
    List<Map<String, Object?>> rows,
  ) async {
    final deliveries = <Delivery>[];
    for (final row in rows) {
      final weightRows = await database.query(
        'delivery_bag_weights',
        where: 'delivery_id = ?',
        whereArgs: [row['id']],
        orderBy: 'bag_number',
      );
      deliveries.add(
        Delivery(
          id: row['id']! as String,
          supplier: Supplier(
            id: row['supplier_id']! as String,
            name: row['supplier_name']! as String,
            type: SupplierType.values.byName(row['supplier_type']! as String),
            town: '',
            district: '',
            region: '',
          ),
          product: Product(
            id: row['product_id']! as String,
            name: row['product_name']! as String,
          ),
          recordedAt: DateTime.parse(row['recorded_at']! as String),
          bagWeights: weightRows
              .map((weight) => (weight['weight']! as num).toDouble())
              .toList(),
          recordedByUserId: row['recorded_by_user_id']! as String,
          status: DeliveryStatus.values.byName(row['status']! as String),
          synchronizationStatus: SynchronizationStatus.values.byName(
            row['synchronization_status']! as String,
          ),
          updatedAt: DateTime.parse(row['updated_at']! as String),
        ),
      );
    }
    return deliveries;
  }
}

class DuplicateDeliveryException implements Exception {
  const DuplicateDeliveryException(this.deliveryId);

  final String deliveryId;

  @override
  String toString() => 'Delivery $deliveryId already exists';
}
