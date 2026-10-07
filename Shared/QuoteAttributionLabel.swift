import SwiftUI

/// Author line with stable dash placement (bidi-safe).
/// Hebrew: left-aligned `Author —`. Latin: right-aligned `— Author`.
struct QuoteAttributionLabel: View {
    let author: String
    let isHebrew: Bool
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            if isHebrew {
                Text(verbatim: author)
                Text(verbatim: "—")
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text(verbatim: "—")
                Text(verbatim: author)
            }
        }
        .font(QuoteFont.author(size, isHebrew: isHebrew))
        .foregroundStyle(.secondary)
        // Force LTR so Spacer / dash side are not flipped by a Hebrew parent.
        .environment(\.layoutDirection, .leftToRight)
    }
}
