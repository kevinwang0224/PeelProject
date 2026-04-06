import AppKit
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@main
struct PeelApp: App {
    @State private var workspace = JSONWorkspace()
    @State private var editorLayoutSettings = EditorLayoutSettings()
    @StateObject private var quickPasteController = QuickPasteController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
                .environment(editorLayoutSettings)
                .task {
                    quickPasteController.bind(workspace: workspace)
                }
        }
        .modelContainer(for: HistoryItem.self)
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            PeelCommands(
                workspace: workspace,
                quickPasteController: quickPasteController
            )
        }

        Settings {
            QuickPasteSettingsView(controller: quickPasteController)
                .environment(editorLayoutSettings)
        }
    }
}

@MainActor
@Observable
final class JSONWorkspace {
    var selectedItem: HistoryItem?
    var editorText = ""
    var noticeMessage: String?
    @ObservationIgnored
    var modelContext: ModelContext?
    @ObservationIgnored
    private var noticeDismissTask: DispatchWorkItem?

    func bind(modelContext: ModelContext) {
        self.modelContext = modelContext
        removeEmptyHistoryItems()
        restoreSelectionIfNeeded()
    }

    func reloadEditorFromSelection() {
        guard let selectedItem else {
            editorText = ""
            return
        }

        let rawJSON = selectedItem.rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawJSON.isEmpty {
            editorText = selectedItem.rawJSON
            return
        }

        let formattedJSON = selectedItem.formattedJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formattedJSON.isEmpty {
            editorText = selectedItem.formattedJSON
            return
        }

        self.selectedItem = nil
        restoreSelectionIfNeeded()
    }

    func createNewItem(with rawJSON: String = "{}") {
        guard let modelContext else {
            editorText = rawJSON
            return
        }

        let title = HistoryItem.defaultTitle()
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
            let newItem = HistoryItem(
                title: HistoryItem.defaultTitle(),
                rawJSON: editorText,
                formattedJSON: editorText.prettyJSON ?? editorText
            )
            modelContext.insert(newItem)
            selectedItem = newItem
            return newItem
        }()

        let formattedJSON = editorText.prettyJSON ?? editorText
        let hasChanged = item.rawJSON != editorText

        if hasChanged {
            item.rawJSON = editorText
            item.formattedJSON = formattedJSON
            item.updatedAt = Date()
        }

        try? modelContext.save()
    }

    func persistSelectedItem() {
        guard let selectedItem else {
            return
        }

        if editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        let formattedJSON = editorText.prettyJSON ?? editorText
        let hasChanged = selectedItem.rawJSON != editorText

        guard hasChanged else {
            return
        }

        selectedItem.rawJSON = editorText
        selectedItem.formattedJSON = formattedJSON
        selectedItem.updatedAt = Date()
        try? modelContext?.save()
    }

    func deleteSelectedItemIfEditorEmpty() {
        guard let selectedItem,
              editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        modelContext?.delete(selectedItem)
        self.selectedItem = nil
        editorText = ""
        try? modelContext?.save()
    }

    func deleteItemIfNeeded(afterLeaving previousSelectionID: UUID?) {
        guard let previousSelectionID,
              previousSelectionID != selectedItem?.id,
              editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let modelContext else {
            return
        }

        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.id == previousSelectionID
            }
        )

        guard let item = try? modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(item)
        try? modelContext.save()
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

    func performCutCommand() {
        _ = NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
    }

    func performCopyCommand() {
        if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
            return
        }

        guard !editorText.isEmpty else {
            return
        }

        copyCurrent()
    }

    func performPasteCommand() {
        if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) {
            return
        }

        pasteFromClipboardAndFormat()
    }

    func performQuickPasteImport(shouldActivateApp: Bool) {
        guard let pasted = NSPasteboard.general.string(forType: .string),
              !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if shouldActivateApp {
                activateAppWindow()
            }
            showNotice("剪贴板里没有可用内容。")
            return
        }

        let importedText = pasted.prettyJSON ?? pasted
        createNewItem(with: importedText)
        saveCurrent()

        if shouldActivateApp {
            activateAppWindow()
        }
    }

    func performSelectAllCommand() {
        _ = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
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

    func showNotice(_ message: String) {
        noticeDismissTask?.cancel()
        noticeMessage = message

        let dismissTask = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.noticeMessage = nil
            }
        }

        noticeDismissTask = dismissTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: dismissTask)
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

        return "Peel Export.json"
    }

    private func removeEmptyHistoryItems() {
        guard let modelContext else {
            return
        }

        let descriptor = FetchDescriptor<HistoryItem>()
        if let items = try? modelContext.fetch(descriptor) {
            let emptyItems = items.filter { item in
                item.rawJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            guard !emptyItems.isEmpty else {
                return
            }

            emptyItems.forEach { item in
                modelContext.delete(item)
            }

            try? modelContext.save()
        }
    }

    private func restoreSelectionIfNeeded() {
        guard let modelContext else {
            return
        }

        let selectedHasContent = {
            guard let selectedItem else {
                return false
            }

            return !selectedItem.rawJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !selectedItem.formattedJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

        guard !selectedHasContent else {
            reloadEditorFromSelection()
            return
        }

        var descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [SortDescriptor(\HistoryItem.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let item = try? modelContext.fetch(descriptor).first {
            selectedItem = item
            reloadEditorFromSelection()
        } else {
            selectedItem = nil
            editorText = ""
        }
    }

    private func activateAppWindow() {
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows where window.canBecomeMain {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct PeelCommands: Commands {
    let workspace: JSONWorkspace
    @ObservedObject var quickPasteController: QuickPasteController

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

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                workspace.performCutCommand()
            }
            .keyboardShortcut("x")

            Button("Copy") {
                workspace.performCopyCommand()
            }
            .keyboardShortcut("c")

            Button("Paste") {
                workspace.performPasteCommand()
            }
            .keyboardShortcut("v")

            Divider()

            Button("Select All") {
                workspace.performSelectAllCommand()
            }
            .keyboardShortcut("a")
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button(quickPasteController.menuCommandTitle) {
                quickPasteController.runQuickPasteFromMenu()
            }

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
