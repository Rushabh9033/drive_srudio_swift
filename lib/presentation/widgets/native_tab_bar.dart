import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/feedback/drive_haptics.dart';

/// Flutter / UIKit Bridge for Apple Native Liquid Glass Bottom Tab Bar.
///
/// On iOS (non-web), renders native UIKit [UITabBar] via [UiKitView].
/// On Android, Web, and desktop/test environments, renders [fallbackBar].
class NativeBottomTabBar extends StatefulWidget {
  const NativeBottomTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.fallbackBar,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget fallbackBar;

  @override
  State<NativeBottomTabBar> createState() => _NativeBottomTabBarState();
}

class _NativeBottomTabBarState extends State<NativeBottomTabBar> {
  MethodChannel? _channel;
  bool _isNativeUpdating = false;

  bool get _useNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(NativeBottomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        _channel != null &&
        !_isNativeUpdating) {
      _channel?.invokeMethod('setSelectedIndex', {'index': widget.selectedIndex});
    }
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('drivestudio/native_tab_bar_$id');
    _channel?.setMethodCallHandler(_handleMethodCall);
    _channel?.invokeMethod('setSelectedIndex', {'index': widget.selectedIndex});
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onTabSelected') {
      final args = call.arguments as Map?;
      final index = args?['index'] as int?;
      if (index != null && index >= 0 && index < 4 && index != widget.selectedIndex) {
        _isNativeUpdating = true;
        try {
          DriveHaptics.selection();
          widget.onTabSelected(index);
        } finally {
          _isNativeUpdating = false;
        }
      }
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_useNative) {
      return widget.fallbackBar;
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = 50.0 + bottomInset;

    return Semantics(
      label: 'Primary Native',
      container: true,
      child: KeyedSubtree(
        key: const ValueKey('drivestudio_native_tab_bar'),
        child: SizedBox(
          height: totalHeight,
          child: UiKitView(
            viewType: 'drivestudio/native_tab_bar',
            creationParams: <String, dynamic>{
              'selectedIndex': widget.selectedIndex,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
        ),
      ),
    );
  }
}
