import SwiftUI

/// Series identity colors, defined once. These are adaptive system colors.
enum Semantic {
    static let download = Color.blue
    static let upload = Color.orange
}

/// A symbol-plus-title label where only the symbol is tinted (used for legends and section headers).
struct TintedLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
    }
}
