import SwiftUI

struct StatusBarView: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    let isValid: Bool
    let jsonType: String
    let byteSize: String
    let keyCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(jsonType)
            Text("\(keyCount) items")
            Text(byteSize)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isValid ? Color.successGreen : Color.errorRed)
                    .frame(width: 8, height: 8)

                Text(isValid ? "Valid" : "Invalid")
            }
        }
        .font(editorLayoutSettings.uiFont(11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
