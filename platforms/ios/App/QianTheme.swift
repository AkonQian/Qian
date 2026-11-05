import SwiftUI

enum QianTheme {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.055)
    static let panel = Color(red: 0.078, green: 0.094, blue: 0.102)
    static let elevated = Color(red: 0.12, green: 0.14, blue: 0.15)
    static let accent = Color(red: 0.78, green: 0.96, blue: 0.36)
    static let border = Color.white.opacity(0.09)
    static let accentUI = UIColor(red: 0.78, green: 0.96, blue: 0.36, alpha: 1)
}

struct QianInstrumentSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(QianTheme.background)
            .toolbarBackground(QianTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(QianTheme.accent)
    }
}

struct QianStatusBadge: View {
    let title: String
    var active = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(active ? QianTheme.accent : Color.secondary).frame(width: 5, height: 5)
                .accessibilityHidden(true)
            Text(title).font(.caption.weight(.semibold))
        }
        .foregroundStyle(active ? QianTheme.accent : Color.secondary)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(active ? QianTheme.accent.opacity(0.09) : QianTheme.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(active ? QianTheme.accent.opacity(0.25) : QianTheme.border))
        .accessibilityElement(children: .combine)
    }
}
