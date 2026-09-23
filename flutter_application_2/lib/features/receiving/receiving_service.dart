import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/delivery.dart';
import '../../domain/models/supplier.dart';
import '../suppliers/supplier_repository.dart';
import 'delivery_repository.dart';

class ReceivingService {
  ReceivingService({required this.database, required this.supplierRepository});

  final Database database;
  final SupplierRepository supplierRepository;

  Future<Delivery> saveDelivery({
    String? supplierId,
    required String supplierName,
    required SupplierType supplierType,
    required String town,
    required String district,
    required String region,
    String? phone,
    String? notes,
    Supplier? selectedSupplier,
    required Delivery delivery,
  }) async {
    return database.transaction((transaction) async {
      var supplier = selectedSupplier;
      final normalizedName = SupplierRepository.normalizeName(supplierName);
      if (supplier == null) {
        final existing = await transaction.query(
          'suppliers',
          where: supplierId == null || supplierId.trim().isEmpty
              ? 'normalized_name = ? AND is_active = 1'
              : '(supplier_id = ? OR normalized_name = ?) AND is_active = 1',
          whereArgs: supplierId == null || supplierId.trim().isEmpty
              ? [normalizedName]
              : [supplierId.trim(), normalizedName],
          limit: 1,
        );
        supplier = existing.isEmpty ? null : SupplierRepository.fromRow(existing.single);
      }
      supplier ??= await _createSupplier(transaction, supplierName, supplierType, town, district, region, phone, notes);
      if (supplier.internalId != delivery.supplier.internalId) {
        delivery = Delivery(
          id: delivery.id,
          supplier: supplier,
          product: delivery.product,
          recordedAt: delivery.recordedAt,
          bagWeights: delivery.bagWeights,
          recordedByUserId: delivery.recordedByUserId,
          status: delivery.status,
          synchronizationStatus: delivery.synchronizationStatus,
          updatedAt: delivery.updatedAt,
        );
      }
      final repository = DeliveryRepository(database);
      await repository.saveInTransaction(transaction, delivery);
      supplierRepository.cache(supplier);
      return delivery;
    });
  }

  Future<Supplier> _createSupplier(
    DatabaseExecutor transaction,
    String name,
    SupplierType type,
    String town,
    String district,
    String region,
    String? phone,
    String? notes,
  ) async {
    final now = DateTime.now();
    final internalId = _uuid();
    final namespace = await _metadata(transaction, 'supplier_device_namespace', () => _namespace());
    final counter = int.parse(await _metadata(transaction, 'supplier_counter', () => '0')) + 1;
    await transaction.insert('local_metadata', {'key': 'supplier_counter', 'value': '$counter'}, conflictAlgorithm: ConflictAlgorithm.replace);
    final supplier = Supplier(
      internalId: internalId,
      id: 'ALB-$namespace-${counter.toString().padLeft(6, '0')}',
      name: name.trim().replaceAll(RegExp(r'\s+'), ' '),
      type: type,
      town: town.trim(),
      district: district.trim(),
      region: region.trim(),
      phone: _optional(phone),
      notes: _optional(notes),
      createdAt: now,
      updatedAt: now,
    );
    await transaction.insert('suppliers', SupplierRepository.toRow(supplier));
    return supplier;
  }

  Future<String> _metadata(DatabaseExecutor transaction, String key, String Function() create) async {
    final rows = await transaction.query('local_metadata', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isNotEmpty) return rows.single['value']! as String;
    final value = create();
    await transaction.insert('local_metadata', {'key': key, 'value': value});
    return value;
  }

  static String _namespace() => List.generate(6, (_) => Random.secure().nextInt(36).toRadixString(36)).join().toUpperCase();
  static String _uuid() => List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  static String? _optional(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
