import 'package:flutter/material.dart';

import 'package:omi/services/capture/trigger_config_service.dart';
import 'package:omi/utils/l10n_extensions.dart';

class TriggerDevicesPage extends StatefulWidget {
  const TriggerDevicesPage({super.key, this.service});

  final TriggerConfigService? service;

  @override
  State<TriggerDevicesPage> createState() => _TriggerDevicesPageState();
}

class _TriggerDevicesPageState extends State<TriggerDevicesPage> {
  late final TriggerConfigService _service = widget.service ?? TriggerConfigService();
  late Future<List<BtDevice>> _devicesFuture = _service.listDevices();

  @override
  void dispose() {
    if (widget.service == null) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _setEnabled(BtDevice device, bool enabled) async {
    await _service.setDeviceEnabled(device.mac, enabled);
    if (!mounted) return;
    setState(() {
      _devicesFuture = _service.listDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.btTriggerDevices),
      ),
      body: FutureBuilder<List<BtDevice>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
          }
          final devices = snapshot.data ?? const [];
          if (devices.isEmpty) {
            return Center(
              child: Text(context.l10n.btTriggerNoDevices, style: TextStyle(color: Colors.grey.shade400)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                color: const Color(0xFF1C1C1E),
                child: SwitchListTile(
                  value: device.enabled,
                  onChanged: (enabled) => _setEnabled(device, enabled),
                  activeThumbColor: const Color(0xFF22C55E),
                  title: Text(device.name.isEmpty ? device.mac : device.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${device.kind} | ${device.mac}',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
