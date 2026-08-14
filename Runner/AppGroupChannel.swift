// This file is intentionally empty.
//
// All App Group V2 write/read logic lives in `DriveStudioWidget/AppGroupState.swift`
// (compiled into both Runner and the widget extension via the
// file-system-synced group). `AppStore.saveState` is the only writer and it
// writes directly via UserDefaults — the old `syncState` / `processQueue` /
// `reloadWidgets` helpers had zero callers and were removed in the simplify
// pass.
//
// The file stub remains because `Runner.xcodeproj/project.pbxproj` lists it
// in the Runner target's Sources phase; removing the pbxproj entries is
// out of scope for the simplify pass.
