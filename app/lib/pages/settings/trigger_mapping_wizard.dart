import 'dart:async';

import 'package:flutter/material.dart';

import 'package:omi/services/capture/trigger_config_service.dart';
import 'package:omi/utils/alerts/app_snackbar.dart';
import 'package:omi/utils/l10n_extensions.dart';

class TriggerMappingWizard extends StatefulWidget {
  const TriggerMappingWizard({super.key, this.service});

  final TriggerConfigService? service;

  @override
  State<TriggerMappingWizard> createState() => _TriggerMappingWizardState();
}

class _TriggerMappingWizardState extends State<TriggerMappingWizard> {
  late final TriggerConfigService _service = widget.service ?? TriggerConfigService();
  final List<BtLearnEvent> _events = [];
  StreamSubscription<BtLearnEvent>? _learnSubscription;
  Timer? _timeoutTimer;
  String? _selectedAction;
  bool _listening = false;
  bool _timedOut = false;
  bool _saving = false;

  static const _actions = <String>['start', 'stop', 'toggle', 'mark'];

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _learnSubscription?.cancel();
    if (_listening) {
      unawaited(_service.stopLearnMode());
    }
    if (widget.service == null) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _startLearning(String action) async {
    _timeoutTimer?.cancel();
    await _learnSubscription?.cancel();
    setState(() {
      _selectedAction = action;
      _events.clear();
      _listening = true;
      _timedOut = false;
    });
    _learnSubscription = _service.learnEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.add(event);
        _timedOut = false;
      });
    });
    await _service.startLearnMode();
    _timeoutTimer = Timer(const Duration(seconds: 10), () async {
      await _stopLearning();
      if (!mounted || _events.isNotEmpty) return;
      setState(() => _timedOut = true);
    });
  }

  Future<void> _stopLearning() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _learnSubscription?.cancel();
    _learnSubscription = null;
    if (_listening) {
      await _service.stopLearnMode();
    }
    if (mounted) {
      setState(() => _listening = false);
    } else {
      _listening = false;
    }
  }

  Future<void> _bindEvent(BtLearnEvent event) async {
    final action = _selectedAction;
    if (action == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _service.upsertMapping(
        ButtonMapping(
          deviceMac: event.deviceMac,
          eventKey: event.eventKey,
          action: action,
          attribution: event.attribution,
          createdMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _stopLearning();
      if (!mounted) return;
      AppSnackbar.showSnackbar(context.l10n.btTriggerMappingSaved);
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _actionLabel(BuildContext context, String action) {
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
        title: Text(context.l10n.btTriggerAddMapping),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.btTriggerPickAction,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in _actions)
                ChoiceChip(
                  label: Text(_actionLabel(context, action)),
                  selected: _selectedAction == action,
                  onSelected: _saving ? null : (_) => _startLearning(action),
                  selectedColor: const Color(0xFF22C55E),
                  labelStyle: TextStyle(color: _selectedAction == action ? Colors.black : Colors.white),
                  backgroundColor: const Color(0xFF1C1C1E),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            context.l10n.btTriggerPressButtonNow,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.btTriggerPressButtonDescription,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 18),
          if (_listening)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E)),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.btTriggerListening, style: const TextStyle(color: Colors.white)),
              ],
            ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(context.l10n.btTriggerTapEventToBind, style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            for (final event in _events)
              _LearnEventTile(
                event: event,
                saving: _saving,
                onTap: () => _bindEvent(event),
              ),
          ],
          if (_timedOut) ...[
            const SizedBox(height: 18),
            Text(
              context.l10n.btTriggerNoButtonReceived,
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 14, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _LearnEventTile extends StatelessWidget {
  const _LearnEventTile({required this.event, required this.saving, required this.onTap});

  final BtLearnEvent event;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1C1C1E),
      child: ListTile(
        enabled: !saving,
        title: Text(event.eventKey, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(event.deviceMac ?? context.l10n.btTriggerDevice, style: TextStyle(color: Colors.grey.shade500)),
        trailing: _TierBadge(tier: event.attribution),
        onTap: onTap,
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final normalized = tier.toUpperCase();
    final color = switch (normalized) {
      'CONFIRMED' => const Color(0xFF22C55E),
      'INFERRED' => const Color(0xFF38BDF8),
      _ => const Color(0xFFF59E0B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(normalized, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
