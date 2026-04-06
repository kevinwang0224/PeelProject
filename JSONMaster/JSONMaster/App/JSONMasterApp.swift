import AppKit
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@main
struct JSONMasterApp: App {
    @State private var workspace = JSONWorkspace()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
        }
        .modelContainer(for: HistoryItem.self)
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            JSONMasterCommands(workspace: workspace)
        }
    }
}

@MainActor
@Observable
final class JSONWorkspace {
    var selectedItem: HistoryItem?
    var editorText = ""
    @ObservationIgnored
    var modelContext: ModelContext?

    func bind(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func reloadEditorFromSelection() {
        editorText = selectedItem?.rawJSON ?? ""
    }

    func createNewItem(with rawJSON: String = "{}") {
        guard let modelContext else {
            editorText = rawJSON
            return
        }

        let title = rawJSON.isValidJSON ? rawJSON.jsonTitle : "Untitled"
        let item = HistoryItem(
            title: title,
            rawJSON: rawJSON,
            formattedJSON: rawJSON.prettyJSON ?? rawJSON
        )
        modelContext.insert(item)
        selectedItem = item
        editorText = rawJSON
        try? modelContext.save()
    }

    func saveCurrent() {
        guard !editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard let modelContext else {
            return
        }

        let item = selectedItem ?? {
            let newItem = HistoryItem(rawJSON: editorText)
            modelContext.insert(newItem)
            selectedItem = newItem
            return newItem
        }()

        let existingTitle = item.title
        item.rawJSON = editorText
        item.formattedJSON = editorText.prettyJSON ?? editorText
        item.updatedAt = Date()

        if existingTitle == "Untitled" || existingTitle == "Invalid JSON" {
            item.title = editorText.isValidJSON ? editorText.jsonTitle : "Untitled"
        }

        try? modelContext.save()
    }

    func persistSelectedItem() {
        guard let selectedItem else {
            return
        }

        selectedItem.rawJSON = editorText
        selectedItem.formattedJSON = editorText.prettyJSON ?? editorText
        selectedItem.updatedAt = Date()
        try? modelContext?.save()
    }

    func formatEditor() {
        switch JSONFormatterService.format(editorText, style: .pretty) {
        case .success(let output):
            editorText = output
        case .failure:
            break
        }
    }

    func compactEditor() {
        switch JSONFormatterService.minify(editorText) {
        case .success(let output):
            editorText = output
        case .failure:
            break
        }
    }

    func clearEditor() {
        editorText = ""
        persistSelectedItem()
    }

    func copyCurrent() {
        let output: String
        switch JSONFormatterService.format(editorText, style: .pretty) {
        case .success(let formatted):
            output = formatted
        case .failure:
            output = editorText
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    func pasteFromClipboardAndFormat() {
        guard let pasted = NSPasteboard.general.string(forType: .string) else {
            return
        }

        if selectedItem == nil {
            createNewItem(with: pasted)
        } else {
            editorText = pasted
        }

        if let prettyJSON = pasted.prettyJSON {
            editorText = prettyJSON
        }

        persistSelectedItem()
    }

    func openJSONFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        importJSON(from: url)
    }

    func importJSON(from url: URL) {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        createNewItem(with: contents)
        if selectedItem?.title == "Untitled" {
            selectedItem?.title = url.deletingPathExtension().lastPathComponent
        }
        saveCurrent()
    }

    func exportCurrent() {
        guard !editorText.isEmpty else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFileName

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        try? editorText.write(to: url, atomically: true, encoding: .utf8)
    }

    private var exportFileName: String {
        let baseName = selectedItem?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let baseName, !baseName.isEmpty {
            return baseName.replacingOccurrences(of: "/", with: "-") + ".json"
        }

        return "JSON Export.json"
    }
}

struct JSONMasterCommands: Commands {
    let workspace: JSONWorkspace

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New JSON") {
                workspace.createNewItem()
            }
            .keyboardShortcut("n")
        }

        CommandGroup(after: .newItem) {
            Button("Open JSON File") {
                workspace.openJSONFile()
            }
            .keyboardShortcut("o")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                workspace.saveCurrent()
            }
            .keyboardShortcut("s")
            .disabled(workspace.editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Export") {
                workspace.exportCurrent()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])
            .disabled(workspace.editorText.isEmpty)
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Format JSON") {
                workspace.formatEditor()
            }
            .keyboardShortcut("b")
            .disabled(workspace.editorText.isEmpty)

            Button("Compact JSON") {
                workspace.compactEditor()
            }
            .keyboardShortcut("B", modifiers: [.command, .shift])
            .disabled(workspace.editorText.isEmpty)
        }
    }
}
