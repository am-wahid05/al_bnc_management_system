import 'package:flutter/material.dart';

import '../../domain/models/delivery.dart';
import '../receiving/delivery_repository.dart';
import 'delivery_detail_screen.dart';
import '../sync/sync_coordinator.dart';
import '../sync/sync_status_card.dart';
import '../sync/sync_status_repository.dart';

class TodaysRecordsScreen extends StatefulWidget {
  const TodaysRecordsScreen({required this.repository, required this.statusRepository, this.coordinator, super.key});

  final DeliveryRepository repository;
  final SyncStatusRepository statusRepository;
  final SyncCoordinator? coordinator;

  @override
  State<TodaysRecordsScreen> createState() => _TodaysRecordsScreenState();
}

class _TodaysRecordsScreenState extends State<TodaysRecordsScreen> {
  late DateTime _selectedDate;
  late Future<List<Delivery>> _records;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadRecords();
  }

  void _loadRecords() {
    _records = widget.repository.forDate(_selectedDate);
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _selectedDate);
    if (selected != null) setState(() { _selectedDate = selected; _loadRecords(); });
  }

  Future<void> _open(Delivery delivery) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryDetailScreen(repository: widget.repository, delivery: delivery)));
    setState(_loadRecords);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Records")),
      body: FutureBuilder<List<Delivery>>(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Could not load records: ${snapshot.error}'));
          final records = snapshot.data!;
          final suppliers = records.map((delivery) => delivery.supplier.id).toSet().length;
          final bags = records.fold(0, (total, delivery) => total + delivery.numberOfBags);
          final weight = records.fold<double>(0, (total, delivery) => total + delivery.totalWeight);
          return RefreshIndicator(
            onRefresh: () async => setState(_loadRecords),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Receiving records', style: Theme.of(context).textTheme.headlineMedium), IconButton(tooltip: 'Choose date', onPressed: _chooseDate, icon: const Icon(Icons.calendar_month_outlined))]),
                Text(_formatDate(_selectedDate), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SyncStatusCard(statusRepository: widget.statusRepository, coordinator: widget.coordinator),
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 12, children: [_SummaryCard(label: 'Suppliers', value: '$suppliers'), _SummaryCard(label: 'Deliveries', value: '${records.length}'), _SummaryCard(label: 'Bags', value: '$bags'), _SummaryCard(label: 'Weight', value: '${weight.toStringAsFixed(1)} kg')]),
                const SizedBox(height: 24),
                if (records.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No deliveries recorded for this date.'))),
                ...records.map((delivery) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(delivery.supplier.name),
                        subtitle: Text('${delivery.product.name} · ${delivery.numberOfBags} bags · ${delivery.totalWeight.toStringAsFixed(1)} kg\n${_formatTime(delivery.recordedAt)} · Sync: ${delivery.synchronizationStatus.name}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(delivery),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  static String _formatTime(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleLarge)])));
}
