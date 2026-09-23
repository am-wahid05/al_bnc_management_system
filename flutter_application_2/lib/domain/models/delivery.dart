import 'product.dart';
import 'supplier.dart';

enum DeliveryStatus { draft, received, corrected, cancelled }

enum SynchronizationStatus {
  localOnly,
  pendingSync,
  synced,
  syncFailed,
  // Legacy values are retained so existing local records can be upgraded safely.
  pending,
  synchronized,
  failed,
}

class Delivery {
  Delivery({
    required this.id,
    required this.supplier,
    required this.product,
    required this.recordedAt,
    required List<double> bagWeights,
    required this.recordedByUserId,
    this.status = DeliveryStatus.received,
    this.synchronizationStatus = SynchronizationStatus.pending,
    DateTime? updatedAt,
  }) : bagWeights = List.unmodifiable(bagWeights),
       updatedAt = updatedAt ?? recordedAt {
    if (this.bagWeights.isEmpty) {
      throw ArgumentError.value(bagWeights, 'bagWeights', 'must not be empty');
    }

    for (final weight in this.bagWeights) {
      if (!weight.isFinite || weight <= 0) {
        throw ArgumentError.value(
          weight,
          'bagWeights',
          'must contain finite values greater than zero',
        );
      }
    }
  }

  final String id;
  final Supplier supplier;
  final Product product;
  final DateTime recordedAt;
  final List<double> bagWeights;
  final String recordedByUserId;
  final DeliveryStatus status;
  final SynchronizationStatus synchronizationStatus;
  final DateTime updatedAt;

  bool get needsSynchronization =>
      synchronizationStatus != SynchronizationStatus.synced &&
      synchronizationStatus != SynchronizationStatus.synchronized;

  int get numberOfBags => bagWeights.length;

  double get totalWeight => calculateTotalWeight(bagWeights);

  static double calculateTotalWeight(Iterable<double> weights) {
    return weights.fold<double>(0, (total, weight) => total + weight);
  }
}
