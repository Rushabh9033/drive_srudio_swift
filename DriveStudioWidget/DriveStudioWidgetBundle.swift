import WidgetKit
import SwiftUI

@main
struct DriveStudioWidgetBundle: WidgetBundle {
    var body: some Widget {
        DriveStudioSlot1Widget()
        DriveStudioSlot2Widget()
        DriveStudioSlot3Widget()
        DriveStudioSlot4Widget()
        OrbitDateWidget()
        NoirGoldWidget()
        SegmentsWidget()
        AuroraRingWidget()
        BatteryPieWidget()
        MinimalDateWidget()
        CommandCenterWidget()
        VortexDriveWidget()
        GridHUDWidget()
        CockpitWidget()
        PhantomWidget()
        SplitPanelWidget()
        SolarDashWidget()
        NeonStripWidget()
        CarbonWidget()
        RadarWidget()
        TriZoneWidget()
        GalaxyWidget()
        // Live Activity is iOS 16.1+. The bundle body compiles
        // against iOS 16.0 (our minimum), so we gate the entry
        // behind an availability check. Devices on iOS 16.0 see
        // the 22 home-screen widgets; iOS 16.1+ also sees the Live
        // Activity.
        if #available(iOS 16.1, *) {
            DriveStudioLiveActivityWidget()
        }
    }
}
