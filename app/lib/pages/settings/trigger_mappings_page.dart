import 'package:flutter/material.dart';

import 'package:omi/pages/settings/trigger_devices_page.dart';
import 'package:omi/pages/settings/trigger_mapping_wizard.dart';
import 'package:omi/services/capture/trigger_config_service.dart';
import 'package:omi/utils/l10n_extensions.dart';

class TriggerMappingsPage extends StatefulWidget {
  const TriggerMappingsPage({super.key, this.service});

  final TriggerConfigService? service;

  @override
  State<TriggerMappingsPage> createState() => _TriggerMappingsPageState();
}

class _TriggerMappingsPageState extends State<TriggerMappingsPage> {
  late final TriggerConfigService _service = widget.service ?? TriggerConfigService();
  late Future<_TriggerConfigSnapshot> _snapshotFuture = _loadSnapshot();

  @override
  void dispose() {
    if (widget.service == null) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<_TriggerConfigSnapshot> _loadSnapshot() async {
    final devices = await _service.listDevices();
    final mappings = await _service.listMappings();
    return _TriggerConfigSnapshot(devices: devices, mappings: mappings);
  }

  void _reload() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _delete(ButtonMapping mapping) async {
    final id = mapping.id;
    if (id == null) return;
    await _service.deleteMapping(id);
    if (!mounted) return;
    _reload();
  }

  Future<void> _openWizard() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TriggerMappingWizard(service: _service)),
    );
    if (saved == true && mounted) {
      _reload();
    }
  }

  Future<void> _openDevices() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TriggerDevicesPage(service: _service)));
    if (mounted) {
      _reload();
    }
  }

  String _deviceLabel(Map<String, BtDevice> devicesByMac, String? mac) {
    if (mac == null || mac.isEmpty) return context.l10n.btTriggerDevice;
    final device = devicesByMac[mac];
    if (device == null) return mac;
    return device.name.isEmpty ? device.mac : device.name;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'start':
        return context.l10n.btTriggerActionStart;
      case 'stop':
        return context.l10n.btTriggerActionStop;
      case 'toggle':
        return context.l10n.btTriggerActionToggle;
      case 'mark':
        return context.l10n.btTriggerActionMark;
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.btTriggerMappings),
        actions: [
          IconButton(
            tooltip: context.l10n.btTriggerDevices,
            onPressed: _openDevices,
            icon: const Icon(Icons.devices_other),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.black,
        onPressed: _openWizard,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.btTriggerAddMapping),
      ),
      body: FutureBuilder<_TriggerConfigSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
          }
          final data = snapshot.data ?? const _TriggerConfigSnapshot(devices: [], mappings: []);
          if (data.mappings.isEmpty) {
            return Center(
              child: Text(context.l10n.btTriggerNoMappings, style: TextStyle(color: Colors.grey.shade400)),
            );
          }
          final devicesByMac = {for (final device in data.devices) device.mac: device};
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: data.mappings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final mapping = data.mappings[index];
              return Card(
                color: const Color(0xFF1C1C1E),
                child: ListTile(
                  title: Text(
                    _deviceLabel(devicesByMac, mapping.deviceMac),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${context.l10n.btTriggerEvent}: ${mapping.eventKey}\n'
                      '${context.l10n.btTriggerAction}: ${_actionLabel(mapping.action)}\n'
                      '${context.l10n.btTriggerTier}: ${mapping.attribution ?? 'AMBIGUOUS'}',
                      style: TextStyle(color: Colors.grey.shade500, height: 1.35),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: context.l10n.delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _delete(mapping),
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

class _TriggerConfigSnapshot {
  const _TriggerConfigSnapshot({required this.devices, required this.mappings});

  final List<BtDevice> devices;
  final List<ButtonMapping> mappings;
}
