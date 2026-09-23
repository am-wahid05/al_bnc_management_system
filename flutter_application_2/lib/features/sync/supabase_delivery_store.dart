import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/delivery.dart';
import 'sync_models.dart';

class SupabaseDeliveryStore implements RemoteDeliveryStore {
  SupabaseDeliveryStore(this.client);

  final SupabaseClient client;

  @override
  Future<void> upsert(Delivery delivery) async {
    final existing = await client
        .from('deliveries')
        .select('updated_at')
        .eq('id', delivery.id)
        .maybeSingle();
    if (existing != null) {
      final remoteUpdatedAt = DateTime.parse(existing['updated_at'] as String);
      if (remoteUpdatedAt.isAfter(delivery.updatedAt)) {
        throw SyncConflictException(
          delivery.id,
          'Remote delivery is newer than the local record',
        );
      }
    }
    await client.from('deliveries').upsert({
      'id': delivery.id,
      'supplier_id': delivery.supplier.id,
      'supplier_name': delivery.supplier.name,
      'supplier_type': delivery.supplier.type.name,
      'product_id': delivery.product.id,
      'product_name': delivery.product.name,
      'recorded_at': delivery.recordedAt.toIso8601String(),
      'recorded_by_user_id': delivery.recordedByUserId,
      'status': delivery.status.name,
      'updated_at': delivery.updatedAt.toIso8601String(),
      'bag_weights': delivery.bagWeights,
    }, onConflict: 'id');
  }
}

class SyncConflictException implements Exception {
  const SyncConflictException(this.deliveryId, this.message);

  final String deliveryId;
  final String message;

  @override
  String toString() => 'Sync conflict for $deliveryId: $message';
}
