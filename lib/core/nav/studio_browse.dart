import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// One-shot intent when navigating to Studio Stock with a category preselected.
class StudioBrowse {
  StudioBrowse._();

  /// Fires when something requests opening Studio Stock on a category chip.
  static final ValueNotifier<String?> pendingCategory =
      ValueNotifier<String?>(null);

  static void openCategory(String category) {
    // ValueNotifier skips notify when value is unchanged — clear first so
    // re-opening the same chip (e.g. Speedometer) still applies.
    if (pendingCategory.value == category) {
      pendingCategory.value = null;
    }
    pendingCategory.value = category;
  }

  static String? takePendingCategory() {
    final v = pendingCategory.value;
    if (v != null) pendingCategory.value = null;
    return v;
  }

  /// Open Studio Stock on [category].
  static void goToCategory(BuildContext context, String category) {
    openCategory(category);
    context.go('/studio');
  }
}
