import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../backup/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.backupService, super.key});

  final BackupService backupService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _working = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Business data backup', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Backups contain business records only. Login passwords and password secrets are never included.'),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _working ? null : _createBackup, icon: const Icon(Icons.backup_outlined), label: const Text('Create Backup')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _working ? null : _restoreBackup, icon: const Icon(Icons.restore_outlined), label: const Text('Restore Backup')),
          if (_working) ...[const SizedBox(height: 20), const LinearProgressIndicator()],
          if (_message != null) ...[const SizedBox(height: 20), SelectableText(_message!)],
          const SizedBox(height: 28),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Cloud synchronization provides another layer of protection by uploading synchronized delivery records to Supabase. Keep both local backups and cloud synchronization enabled where possible.'))),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() { _working = true; _message = null; });
    try {
      final file = await widget.backupService.createBackup();
      if (mounted) setState(() => _message = 'Backup created: ${file.path}');
    } catch (error) {
      if (mounted) setState(() => _message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Restoring can replace current local business data. A safety backup of the current data will be created first. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    final selection = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final selectedPath = selection?.files.single.path;
    if (selectedPath == null) return;
    setState(() { _working = true; _message = null; });
    try {
      final safetyBackup = await widget.backupService.restoreBackup(File(selectedPath));
      if (mounted) setState(() => _message = 'Restore complete. Safety backup: ${safetyBackup.path}');
    } catch (error) {
      if (mounted) setState(() => _message = 'Restore failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
