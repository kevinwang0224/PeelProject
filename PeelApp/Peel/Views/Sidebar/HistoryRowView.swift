import SwiftUI

struct HistoryRowView: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(item.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(item.rawJSON.jsonByteSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.updatedAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
