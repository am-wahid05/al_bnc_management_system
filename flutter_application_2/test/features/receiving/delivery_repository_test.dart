import 'package:flutter_application_2/domain/models/delivery.dart';
import 'package:flutter_application_2/domain/models/product.dart';
import 'package:flutter_application_2/domain/models/supplier.dart';
import 'package:flutter_application_2/features/receiving/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DeliveryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(':memory:', options: OpenDatabaseOptions(
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE deliveries (
            id TEXT PRIMARY KEY,
            supplier_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            recorded_by_user_id TEXT NOT NULL,
            status TEXT NOT NULL,
            synchronization_status TEXT NOT NULL,
            supplier_name TEXT NOT NULL,
            product_name TEXT NOT NULL,
            supplier_type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE delivery_bag_weights (
            delivery_id TEXT NOT NULL,
            bag_number INTEGER NOT NULL,
            weight REAL NOT NULL,
            PRIMARY KEY (delivery_id, bag_number)
          )
        ''');
      },
    ));
    repository = DeliveryRepository(database);
  });

  tearDown(() => database.close());

  test('saves a delivery and every individual bag weight in one database operation', () async {
    final supplier = Supplier(id: 'ALB-000001', name: 'Ibrahim Mensah', type: SupplierType.aggregator, town: 'Techiman', district: 'Techiman Municipal', region: 'Bono East');
    final delivery = Delivery(id: 'delivery-1', supplier: supplier, product: Product.cashew, recordedAt: DateTime(2026, 9, 21), bagWeights: [82.5, 79.8, 81.2], recordedByUserId: 'secretary-1');

    await repository.save(delivery);

    expect(await repository.count(), 1);
    final rows = await database.query('delivery_bag_weights', orderBy: 'bag_number');
    expect(rows.map((row) => row['weight']), [82.5, 79.8, 81.2]);
  });

  test('delivery calculation derives count and total from bag weights', () {
    final supplier = Supplier(id: 'ALB-000001', name: 'Ibrahim Mensah', type: SupplierType.farmer, town: 'Techiman', district: 'Techiman Municipal', region: 'Bono East');
    final delivery = Delivery(id: 'delivery-2', supplier: supplier, product: Product.cocoa, recordedAt: DateTime(2026, 9, 21), bagWeights: [82.5, 79.8, 81.2], recordedByUserId: 'secretary-1');

    expect(delivery.numberOfBags, 3);
    expect(delivery.totalWeight, closeTo(243.5, 0.0001));
  });

  test('returns only the selected date and supports controlled correction', () async {
    final supplier = Supplier(id: 'ALB-000001', name: 'Ibrahim Mensah', type: SupplierType.farmer, town: 'Techiman', district: 'Techiman Municipal', region: 'Bono East');
    final today = Delivery(id: 'delivery-today', supplier: supplier, product: Product.cashew, recordedAt: DateTime(2026, 9, 21, 10), bagWeights: [80, 70], recordedByUserId: 'secretary-1');
    final yesterday = Delivery(id: 'delivery-yesterday', supplier: supplier, product: Product.cashew, recordedAt: DateTime(2026, 9, 20, 10), bagWeights: [100], recordedByUserId: 'secretary-1');

    await repository.save(today);
    await repository.save(yesterday);

    final records = await repository.forDate(DateTime(2026, 9, 21));
    expect(records.map((delivery) => delivery.id), ['delivery-today']);
    expect(records.single.numberOfBags, 2);
    expect(records.single.totalWeight, 150);

    final corrected = await repository.updateWeights(today.id, [82.5, 79.8, 81.2]);
    expect(corrected.status, DeliveryStatus.corrected);
    expect(corrected.synchronizationStatus, SynchronizationStatus.pending);
    expect(corrected.numberOfBags, 3);
    expect(corrected.totalWeight, closeTo(243.5, 0.0001));
  });
}
