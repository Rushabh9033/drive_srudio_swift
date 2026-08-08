import WidgetKit
import SwiftUI

@main
struct DriveStudioWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.0, *) {
            DriveStudioSlot1Widget()
            DriveStudioSlot2Widget()
            DriveStudioSlot3Widget()
            DriveStudioSlot4Widget()
        }
    }
}
