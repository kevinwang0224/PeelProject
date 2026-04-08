import SwiftUI

struct HistoryRowView: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(editorLayoutSettings.uiFont(9))
                        .foregroundStyle(.secondary)
//                        .foregroundStyle(.orange)
                }

                Text(item.title)
                    .font(editorLayoutSettings.uiFont(12, weight: .medium))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(item.rawJSON.jsonByteSize)
                    .font(editorLayoutSettings.uiFont(11))
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(editorLayoutSettings.uiFont(11))
                    .foregroundStyle(.secondary)

                Text(item.updatedAt.timeAgoDisplay())
                    .font(editorLayoutSettings.uiFont(11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
