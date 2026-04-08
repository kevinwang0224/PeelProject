import SwiftUI

extension Color {
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let subtleText = Color(nsColor: .secondaryLabelColor)
    static let accent = Color.accentColor
    static let errorRed = Color(nsColor: .systemRed)
    static let successGreen = Color(nsColor: .systemGreen)
}

extension EditorLayoutSettings {
    func uiPointSize(_ baseSize: CGFloat) -> CGFloat {
        max(9, baseSize + (interfaceFontSize - Self.defaultFontSize))
    }

    func uiFont(
        _ baseSize: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        .system(size: uiPointSize(baseSize), weight: weight, design: design)
    }

    func editorFont(weight: Font.Weight = .regular) -> Font {
        .system(size: editorFontSize, weight: weight, design: .monospaced)
    }

    var editorMonacoFontSize: Int {
        Int(editorFontSize.rounded())
    }
}
