import AppIntents

@available(iOS 16.0, *)
struct StartDriveIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Drive"
    
    @Parameter(title: "Destination")
    var destination: String?
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 16.0, *)
struct CheckBatteryIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Car Battery"
    
    func perform() async throws -> some IntentResult {
        return .result(dialog: "Your battery is at 100%.")
    }
}
