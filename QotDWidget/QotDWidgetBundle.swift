import WidgetKit
import SwiftUI

@main
struct QotDWidgetBundle: WidgetBundle {
    init() {
        QuoteFont.registerIfNeeded()
    }

    var body: some Widget {
        QotDWidget()
    }
}
