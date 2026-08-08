import 'package:flutter/widgets.dart';

import '../../data/models/models.dart';

/// Wall-clock broadcast for live clock / date / analog / battery layers.
///
/// Uses [InheritedNotifier] so **only** descendants that call [watch] rebuild
/// when time advances. The editor gesture overlay must never [watch] this —
/// otherwise [Timer.periodic] would remount hit targets and kill drag.
class ClockTicker extends InheritedNotifier<ValueNotifier<DateTime>> {
  const ClockTicker({
    super.key,
    required ValueNotifier<DateTime> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// Registers a dependency — rebuild when [notifier] updates.
  static DateTime watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ClockTicker>();
    assert(scope != null, 'ClockTicker.watch used outside ClockTicker');
    return scope!.notifier!.value;
  }

  /// Read current time without registering a rebuild dependency.
  static DateTime? peek(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ClockTicker>();
    return scope?.notifier?.value;
  }
}

/// Whether [layer] must repaint on the studio clock tick.
bool layerNeedsClockTick(LayerKind kind) {
  return kind == LayerKind.clock ||
      kind == LayerKind.date ||
      kind == LayerKind.analog ||
      kind == LayerKind.battery;
}
