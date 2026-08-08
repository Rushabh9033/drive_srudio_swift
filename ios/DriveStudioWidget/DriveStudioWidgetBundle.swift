import WidgetKit
import SwiftUI

/// WidgetBundle for the Drive Studio widget extension.
///
/// Registers 4 slot widgets (the iOS WidgetKit practical limit per
/// extension). Each `DriveStudioSlotWidget` exposes a unique `kind` string
/// so WidgetKit treats them as separate widgets in the gallery.
@main
struct DriveStudioWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.0, *) {
            DriveStudioSlotWidget(slotIndex: 0)
            DriveStudioSlotWidget(slotIndex: 1)
            DriveStudioSlotWidget(slotIndex: 2)
            DriveStudioSlotWidget(slotIndex: 3)
        }
    }
}