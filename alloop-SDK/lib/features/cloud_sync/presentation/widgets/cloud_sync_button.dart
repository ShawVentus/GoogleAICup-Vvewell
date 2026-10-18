import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../foundations/ui/vvewell_theme.dart';
import '../../data/cloud_measurement_sync_service.dart';

class CloudSyncButton extends StatefulWidget {
  const CloudSyncButton({super.key});

  @override
  State<CloudSyncButton> createState() => _CloudSyncButtonState();
}

class _CloudSyncButtonState extends State<CloudSyncButton> {
  bool _syncing = false;

  CloudMeasurementSyncService get _service =>
      CloudMeasurementSyncService.instance;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      if (kIsWeb) {
        _showMessage('This preview retains the original sample data. Sync device measurements using the mobile app.', isError: false);
        return;
      }
      await _service.ensureDemoSession();
      final result = await _service.syncDashboardData();
      if (mounted) _showMessage(result.summary, isError: result.failed > 0);
    } on Object {
      if (mounted) {
        _showMessage('Cloud sync failed. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? VvewellColors.error : VvewellColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Tooltip(
        message: _syncing ? 'Syncing dashboard data' : 'Sync dashboard data',
        child: IconButton(
          onPressed: _syncing ? null : _sync,
          icon: _syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_outlined),
          color: VvewellColors.foreground,
          splashRadius: 20,
        ),
      ),
    );
  }
}
