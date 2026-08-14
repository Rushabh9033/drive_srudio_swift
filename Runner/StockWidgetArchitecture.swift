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
}