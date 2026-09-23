import 'package:sqflite/sqflite.dart';

import '../../domain/models/product.dart';

class ProductRepository {
  ProductRepository(this.database);

  final Database database;

  Future<void> seedInitialProducts() async {
    final now = DateTime.now().toIso8601String();
    for (final product in Product.initialProducts) {
      await database.insert(
        'products',
        {
          'id': product.id,
          'name': product.name,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<List<Product>> all({bool activeOnly = false}) async {
    final rows = await database.query(
      'products',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Product?> findById(String id) async {
    final rows = await database.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<Product> create(String name) async {
    final cleanName = _validateName(name);
    final now = DateTime.now();
    final id = _newId(cleanName);
    try {
      await database.insert('products', {
        'id': id,
        'name': cleanName,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw StateError('A product with this name already exists');
      rethrow;
    }
    return (await findById(id))!;
  }

  Future<Product> update(Product product) async {
    final cleanName = _validateName(product.name);
    try {
      final changed = await database.update(
        'products',
        {'name': cleanName, 'is_active': product.isActive ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      if (changed == 0) throw StateError('Product ${product.id} was not found');
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw StateError('A product with this name already exists');
      rethrow;
    }
    return (await findById(product.id))!;
  }

  Future<Product> setActive(Product product, bool isActive) {
    return update(product.copyWith(isActive: isActive));
  }

  String _validateName(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Product name is required');
    return cleanName;
  }

  String _newId(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    return '$slug-${DateTime.now().microsecondsSinceEpoch}';
  }

  static Product _fromRow(Map<String, Object?> row) {
    return Product(
      id: row['id']! as String,
      name: row['name']! as String,
      isActive: row['is_active'] == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}