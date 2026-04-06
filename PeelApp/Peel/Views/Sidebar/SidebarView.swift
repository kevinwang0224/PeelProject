import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(JSONWorkspace.self) private var workspace
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\HistoryItem.updatedAt, order: .reverse)]) private var items: [HistoryItem]

    @Binding var selectedItem: HistoryItem?
    var onCreateNew: () -> Void = {}

    @State private var searchText = ""
    @State private var renameTarget: HistoryItem?
    @State private var renameText = ""

    private var filteredItems: [HistoryItem] {
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
                item.rawJSON.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedItems: [HistoryItem] {
        filteredItems.filter(\.isPinned)
    }

    private var unpinnedItems: [HistoryItem] {
        filteredItems.filter { !$0.isPinned }
    }

    private var selection: Binding<UUID?> {
        Binding<UUID?>(
            get: { selectedItem?.id },
            set: { newID in
                selectedItem = items.first { $0.id == newID }
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            if !pinnedItems.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedItems) { item in
                        historyRow(for: item)
                    }
                }
            }

            Section("History") {
                if unpinnedItems.isEmpty {
                    Text(searchText.isEmpty ? "No history yet" : "No matching items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(unpinnedItems) { item in
                        historyRow(for: item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("History")
        // 3. 替换为原生搜索
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        // 4. 将新建按钮移至 Toolbar
           .toolbar {
               ToolbarItemGroup(placement: .navigation) {
                   ControlGroup {
                       Button(action: onCreateNew) {
                           Label("New", systemImage: "plus")
                       }
                    
                   }
                   
               }
           }
        // 5. 底部仅保留必要的轻量化设置按钮（或直接移除，放到主菜单）
           .safeAreaInset(edge: .bottom, spacing: 0) {
               VStack(spacing: 0) {
                   // 1. 顶部分割线（调淡一点，更原生）
                   Divider()
                       .opacity(0.3)

                   HStack {
                       SettingsLink {
                           Label("Settings", systemImage: "gearshape")
                               .font(.system(size: 12))
                               .foregroundStyle(.secondary)
                       }
                       .buttonStyle(.plain)
                       
                       Spacer()
                   }
                   .padding(.horizontal, 16)
                   .padding(.vertical, 12)
                   .frame(maxWidth: .infinity) // 确保撑满整个宽度
                   // 2. 关键：使用和你侧边栏完全一致的背景色
                   .background(Color.sidebarBackground)
               }
           }
        .alert("Rename Item", isPresented: renamePresentedBinding) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Save") {
                commitRename()
            }
        } message: {
            Text("Give this JSON item a short name.")
        }
    }

    private func historyRow(for item: HistoryItem) -> some View {
        HistoryRowView(item: item)
            .tag(item.id)
            .contentShape(Rectangle())
            .contextMenu {
                Button(item.isPinned ? "Unpin" : "Pin") {
                    togglePin(for: item)
                }

                Button("Rename") {
                    beginRename(item)
                }

                Button("Copy JSON") {
                    copyToPasteboard(item.rawJSON)
                }

                Divider()

                Button("Delete", role: .destructive) {
                    delete(item)
                }
            }
    }

    private var renamePresentedBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { isPresented in
                if !isPresented {
                    renameTarget = nil
                }
            }
        )
    }

    private func beginRename(_ item: HistoryItem) {
        renameTarget = item
        renameText = item.title
    }

    private func commitRename() {
        guard let renameTarget else {
            return
        }

        workspace.rename(renameTarget, to: renameText)
        self.renameTarget = nil
    }

    private func togglePin(for item: HistoryItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func delete(_ item: HistoryItem) {
        if selectedItem?.id == item.id {
            selectedItem = nil
        }

        modelContext.delete(item)
        try? modelContext.save()
    }
}
