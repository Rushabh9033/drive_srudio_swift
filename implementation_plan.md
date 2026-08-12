# Phase 0.2.2A: Apex Native Widget Integrations

This phase implements the iOS native widget mockups for the Apex Widget System, ensuring the iOS Widget Gallery displays the new Lovable designs rather than a blank state.

## Proposed Changes

### iOS Widget Extension
#### [MODIFY] `ios/DriveStudioWidget/DriveStudioWidget.swift`
- Pass `context.isPreview` through the `TimelineProvider` into `SimpleEntry`.
- Intercept rendering in `DriveStudioWidgetEntryView`: if `isPreview` is true and no slot data exists, render a native SwiftUI mockup instead of the "Slot N" placeholder.

#### [NEW] `ios/DriveStudioWidget/ApexViews.swift`
- Create native SwiftUI mockups for the 12 Apex templates.
- Since the V2 `WidgetSpec` JSON renderer (`FitToCanvasLayers`) is already fully native SwiftUI, we will construct static `WidgetSpec` models with the approved reference values for the mockups. This satisfies the requirement for "native SwiftUI rendering" without duplicating the entire rendering pipeline.
- Map `slotIndex` (0 to 11) to one of the 12 Apex mockups so the Widget Gallery displays all variations across the available slots.

### Testing & Validation
- Run `xcodebuild` for `DriveStudioWidgetExtension` to verify Swift compilation.
- Deploy the updated app to the device so you can verify the iOS Home Screen Widget Gallery.

## User Review Required
> [!IMPORTANT]
> Please approve this plan so I can build the native iOS mockups and integrate them into the widget extension!
