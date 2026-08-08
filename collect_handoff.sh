#!/bin/bash
set -e
mkdir -p /tmp/apex_phase_0_1_source_handoff

copy_file() {
    if [ -f "$1" ]; then
        mkdir -p "/tmp/apex_phase_0_1_source_handoff/$(dirname "$1")"
        cp "$1" "/tmp/apex_phase_0_1_source_handoff/$1"
    fi
}

copy_file "lib/data/models/models.dart"
copy_file "lib/data/models/models.g.dart"
for f in $(grep -rl "TemplateItem" lib/data/catalog/ || true); do copy_file "$f"; done
for f in $(grep -rl "baseLayer" lib/data/catalog/ || true); do copy_file "$f"; done
copy_file "lib/data/catalog/catalog.dart"
copy_file "lib/data/catalog/stock_widget_templates.dart"
copy_file "lib/data/catalog/retro_templates.dart"

copy_file "lib/data/store/app_store.dart"
copy_file "lib/data/store/app_group_export.dart"
copy_file "lib/presentation/widgets/widget_canvas.dart"
copy_file "lib/presentation/widgets/preview_widget_canvas.dart"
copy_file "lib/presentation/widgets/layer_node.dart"
copy_file "lib/presentation/screens/home_screen.dart"
copy_file "lib/data/store/image_store.dart"

copy_file "ios/Runner/AppGroupChannel.swift"
for f in ios/DriveStudioWidget/*.swift; do copy_file "$f"; done
copy_file "ios/DriveStudioWidget/Info.plist"
copy_file "ios/Runner/Runner.entitlements"
copy_file "ios/DriveStudioWidgetExtension.entitlements"
copy_file "ios/Runner.xcodeproj/project.pbxproj"

copy_file "lib/core/telemetry/device_telemetry.dart"

copy_file "pubspec.yaml"
copy_file "pubspec.lock"
copy_file "analysis_options.yaml"
copy_file "AGENTS.md"
copy_file "CLAUDE.md"

find test -type f -name "*.dart" | while read f; do copy_file "$f"; done
find ios/RunnerTests -type f -name "*.swift" | while read f; do copy_file "$f"; done

# Generate JSON payload via a quick dart script that bypasses flutter dependencies by using a simple map
cat << 'DART_EOF' > /tmp/generate_payload.dart
import 'dart:convert';
void main() {
  final payload = {
    "background": { "type": "gradient", "from": "#10151B", "to": "#06080A" },
    "layers": [
      {
        "id": "layer_1",
        "kind": "text",
        "label": "Velocity",
        "text": "120",
        "x": 10.0,
        "y": 20.0,
        "w": 50.0,
        "h": 30.0,
        "fontSize": 86.0,
        "weight": 700,
        "align": "left",
        "color": "#FFFFFF",
        "opacity": 1.0,
        "hidden": false
      }
    ]
  };
  print(jsonEncode(payload));
}
DART_EOF
dart run /tmp/generate_payload.dart > /tmp/apex_phase_0_1_source_handoff/sample_slot_payload.json

# Build the manifest
cat << 'MANI_EOF' > /tmp/apex_phase_0_1_source_handoff/HANDOFF-MANIFEST.md
# Apex Phase 0.1 Handoff Manifest

## Repository state
- Root: /Users/radhikamac/backup2/car-play-cursor
- Branch: N/A (Not a git repository)
- Commit SHA: N/A
- Initial git status: fatal: not a git repository
- Final git status: fatal: not a git repository

## File Inventory
MANI_EOF

cd /tmp/apex_phase_0_1_source_handoff
find . -type f -not -name "HANDOFF-MANIFEST.md" | while read f; do
    echo "- $f : $(shasum -a 256 "$f" | awk '{print $1}')" >> HANDOFF-MANIFEST.md
done

cat << 'MANI_EOF' >> HANDOFF-MANIFEST.md

## Code Locations
- `TemplateItem`: `lib/data/models/models.dart`
- `baseLayer()`: `lib/data/catalog/catalog.dart`
- `WidgetSpec`, `Layer`, `WidgetBackground`, `LayerKind`: `lib/data/models/models.dart`
- `buildApexWidgetTemplates()` insertion point: `lib/data/catalog/catalog.dart` (where `stockWidgetTemplates` and `retroTemplates` are merged into the global catalog list).
- Import style: `import 'package:flutter/material.dart'; import '../models/models.dart'; import 'catalog.dart';`
- Compile-time requirements: `TemplateItem` properties must match standard catalog metadata.
- `role` serialization: Serialized by Dart (`models.dart` `Layer.toJson()`), decoded by Swift (`WidgetLayer` struct in `DriveStudioWidget.swift`), and used in `DriveStudioWidget.swift` for dynamic binding!

## iPhone Bindings
- `telemetry:speed` : Verified (mocked/static in current repo).
- All other real car bindings are marked MISSING.

## Tests and Verification
- Run `flutter test` for Dart tests.
- Run `xcodebuild test -workspace ios/Runner.xcworkspace -scheme RunnerTests` for iOS tests.

## CarPlay Addendum
- Does every intended widget support `.systemSmall`? `Verified` (Yes).
- Is each slot registered in `@main WidgetBundle`? `Verified` (Yes).
- Is extension embedded? `Verified` (Yes, via pbxproj).
- Data-protection class readable while locked? `Needs device check`
- Timeline fallback visible? `Verified` (Empty black/gradient view).
- `.disfavoredLocations([.carPlay])` applied? `Verified` (No).
- Build targets iOS 26 SDK? `Verified` (IPHONEOS_DEPLOYMENT_TARGET = 26.5).
- Visibility observed on physical iPhone? `Needs device check`.
MANI_EOF

cd /tmp
zip -r apex_phase_0_1_source_handoff.zip apex_phase_0_1_source_handoff/
