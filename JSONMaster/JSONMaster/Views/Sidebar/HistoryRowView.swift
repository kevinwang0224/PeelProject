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
                    .foregroundStyle(Color.subtleText)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)

                Text(item.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
        }
        .padding(.vertical, 4)
    }
}
