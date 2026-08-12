/// Shared App Group identifiers and JSON keys.
/// Keep in sync with `lib/data/store/app_group_export.dart`.
enum AppGroupContract {
    static let suiteName = "group.com.drivestudio.shared"
    static let stateKey = "widget_state_v1"
    static let schemaVersion = 1
    /// Schema version of the V2 envelope (metadata blob + generation folder).
    /// Used by AppGroupChannel.Metadata(...) when writing, and matched by the
    /// widget extension's AppGroupHelper when reading.
    static let schemaVersionV2 = 2
}

/*
 Expected JSON shape (schemaVersion 1):

 {
   "schemaVersion": 1,
   "updatedAt": "ISO-8601",
   "isPremium": false,
   "vehicle": { "brandId", "modelId", "artwork", "displayName", "hasCustomImage" },
   "sounds": { "connect", "disconnect", "reminder" },
   "slots": [
     {
       "index": 0,
       "draftId": "...",
       "name": "...",
       "updatedAt": 0,
       "summary": {
         "title", "clockFormat", "dateFormat", "badge",
         "bgFrom", "bgTo", "bgType"
       },
       "spec": { background, layers }
     },
     ...
   ]
 }

 Large data-URL images are omitted (`srcOmitted` / `imageOmitted`).
 Oversized payloads set `trimmed: true` and drop `spec` (summary kept).

 Flutter mirrors into SharedPreferences; AppGroupChannel writes the real suite.
*/
