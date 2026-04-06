import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(JSONWorkspace.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace

        NavigationSplitView {
            SidebarView(selectedItem: $workspace.selectedItem) {
                workspace.createNewItem()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            Group {
                if workspace.selectedItem == nil {
                    emptyState
                } else {
                    EditorContainerView(
                        selectedItem: $workspace.selectedItem,
                        editorText: $workspace.editorText
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            workspace.bind(modelContext: modelContext)
            workspace.reloadEditorFromSelection()
        }
        .onChange(of: workspace.selectedItem?.id, initial: true) { oldValue, _ in
            workspace.deleteItemIfNeeded(afterLeaving: oldValue)
            workspace.reloadEditorFromSelection()
        }
        .onChange(of: workspace.editorText, initial: false) { _, _ in
            workspace.persistSelectedItem()
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No JSON Selected", systemImage: "curlybraces.square")
        } description: {
            Text("Paste JSON or create new")
        } actions: {
            Button("New JSON") {
                workspace.createNewItem()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let data = item as? NSData {
                url = URL(dataRepresentation: data as Data, relativeTo: nil)
            } else if let string = item as? String {
                url = URL(string: string)
            } else {
                url = nil
            }

            guard let url, url.pathExtension.lowercased() == "json" else {
                return
            }

            Task { @MainActor in
                workspace.importJSON(from: url)
            }
        }

        return true
    }
}
