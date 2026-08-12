import Foundation
import SwiftUI

// MARK: - Core Document Model Alias
/// The canonical model that represents any widget (stock or custom) in the system.
typealias DriveWidgetDocument = WidgetSpec

// MARK: - Stock Widget Models

enum StockWidgetCategory: String, CaseIterable, Codable {
    case nightTime = "Night and time"
    case phoneBattery = "Phone battery"
    case driving = "Driving"
    case vehicle = "Vehicle"
}

struct StockWidgetDefinition: Identifiable, Codable, Equatable {
    var id: String { stockWidgetId }
    
    let stockWidgetId: String
    let stockWidgetVersion: Int
    let name: String
    let description: String
    let category: StockWidgetCategory
    let requiredDataSource: String // e.g. "Core Location Speed", "Phone Battery"
    let document: DriveWidgetDocument
    
    // Convert this definition into an assignable document
    func toAssignedDocument() -> DriveWidgetDocument {
        // Just return the base spec, the app state tracks the ID and version
        return document
    }
}

// MARK: - Data Snapshots & Fallbacks

/// Represents the real-time or last-known data provided to the renderer
struct WidgetDataSnapshot: Codable, Equatable {
    var timestamp: Date
    var batteryLevel: Int?      // Device battery 0-100
    var isCharging: Bool
    var speedKMH: Double?       // From CoreLocation active drive
    var vehicleBrandId: String?
    var vehicleModelId: String?
    var vehicleArtwork: String?
    
    var isSpeedStale: Bool {
        // e.g. if older than 5 minutes
        Date().timeIntervalSince(timestamp) > 300
    }
}

/// Fallback representations for unavailable data
struct WidgetFallbackState {
    static let noBattery = "Unknown"
    static let noSpeed = "Inactive"
    static let noVehicle = "Select Vehicle"
}

// MARK: - Stock Widget Factory
struct StockWidgetFactory {
    static func createEditableCopy(from definition: StockWidgetDefinition) -> Draft {
        // Create a new custom draft based on the stock definition
        let newId = UUID().uuidString
        return Draft(
            id: newId,
            name: "\(definition.name) (Copy)",
            spec: definition.document,
            updatedAt: Date().timeIntervalSince1970
        )
    }
}
