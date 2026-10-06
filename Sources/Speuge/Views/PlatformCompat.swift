import SwiftUI

// All version-specific UI code lives in this one file.
// Deployment target is macOS 13; each helper uses the newer API where it exists.

extension View {
    /// `onChange(of:)` without the macOS 14 deprecation warning; still works on macOS 13.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

/// System empty state: `ContentUnavailableView` on macOS 14+, a plain stack on macOS 13.
struct EmptyStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    var message: LocalizedStringKey? = nil

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                if let message { Text(message) }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title).font(.headline)
                if let message {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
