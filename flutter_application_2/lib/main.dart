import 'package:flutter/material.dart';

import 'app/albnc_app.dart';
import 'app/supabase_config.dart';
import 'features/products/product_database.dart';
import 'features/products/product_repository.dart';
import 'features/receiving/delivery_repository.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/local_auth_repository.dart';
import 'features/auth/supabase_auth_repository.dart';
import 'features/receiving/receiving_service.dart';
import 'features/suppliers/supplier_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseClient = await SupabaseConfig.initialize();
  final database = await ProductDatabase.open();
  final productRepository = ProductRepository(database);
  await productRepository.seedInitialProducts();
  final supplierRepository = SupplierRepository(database: database);
  await supplierRepository.initialize();
  final authRepository = supabaseClient == null
      ? LocalAuthRepository(database)
      : SupabaseAuthRepository(supabaseClient);
  if (authRepository is LocalAuthRepository) {
    final users = await authRepository.allUsers();
    if (!users.any((user) => user.username.toLowerCase() == LocalAuthRepository.testUsername)) {
      await authRepository.createUser(username: LocalAuthRepository.testUsername, displayName: 'Local Test Admin', role: UserRole.admin, password: LocalAuthRepository.testPassword);
    }
    if (!users.any((user) => user.username.toLowerCase() == LocalAuthRepository.testSecretaryUsername)) {
      await authRepository.createUser(username: LocalAuthRepository.testSecretaryUsername, displayName: 'Local Test Secretary', role: UserRole.secretary, password: LocalAuthRepository.testSecretaryPassword);
    }
  }
  runApp(AlbncApp(
    productRepository: productRepository,
    deliveryRepository: DeliveryRepository(database),
    authRepository: authRepository,
    repository: supplierRepository,
    receivingService: ReceivingService(
      database: database,
      supplierRepository: supplierRepository,
    ),
  ));
}
