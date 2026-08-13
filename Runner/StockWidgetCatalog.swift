import Foundation
import SwiftUI

struct StockWidgetCatalog {
    static let shared = StockWidgetCatalog()
    
    let widgets: [StockWidgetDefinition]
    
    private init() {
        // Clean stock widget catalog ready for user's custom Swift code
        self.widgets = []
    }

    func findWidget(byId id: String) -> StockWidgetDefinition? {
        return widgets.first(where: { $0.stockWidgetId == id || $0.id == id })
    }
}
