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
        WindowGroup(id: JSONWorkspace.mainWindowSceneID) {
            MainWindowRootView(
                workspace: workspace,
                editorLayoutSettings: editorLayoutSettings,
                quickPasteController: quickPasteController
            )
        }
        .modelContainer(for: HistoryItem.self)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 650)
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
    @ObservationIgnored
    private var openMainWindow: (() -> Void)?

    static let mainWindowSceneID = "main-window"
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("PeelMainWindow")

    func bind(modelContext: ModelContext) {
        self.modelContext = modelContext
        removeEmptyHistoryItems()
        restoreSelectionIfNeeded()
    }

    func bindMainWindowOpener(_ openMainWindow: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
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

    func rename(_ item: HistoryItem, to proposedTitle: String) {
        let resolvedTitle = resolvedTitle(from: proposedTitle, for: item)
        guard item.title != resolvedTitle else {
            return
        }

        item.title = resolvedTitle
        try? modelContext?.save()
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
        if MonacoEditorCommandCenter.shared.performCut() {
            return
        }

        _ = NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
    }

    func performCopyCommand() {
        if MonacoEditorCommandCenter.shared.performCopy() {
            return
        }

        if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
            return
        }

        guard !editorText.isEmpty else {
            return
        }

        copyCurrent()
    }

    func performPasteCommand() {
        if let pasted = NSPasteboard.general.string(forType: .string),
           MonacoEditorCommandCenter.shared.performPaste(pasted) {
            return
        }

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
        if MonacoEditorCommandCenter.shared.performSelectAll() {
            return
        }

        _ = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }

    func performFocusedJSONFindCommand() {
        if MonacoEditorCommandCenter.shared.performFind() {
            return
        }

        guard let textView = NSApp.keyWindow?.firstResponder as? JSONFormattingTextView else {
            return
        }

        textView.showFindInterface()
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

    func closeActiveWindow() {
        if NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) {
            return
        }

        let fallbackWindow = NSApp.keyWindow ??
            NSApp.mainWindow ??
            mainWindows.first ??
            NSApp.windows.first(where: \.canBecomeMain)

        fallbackWindow?.performClose(nil)
    }

    private var exportFileName: String {
        let baseName = selectedItem?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let baseName, !baseName.isEmpty {
            return baseName.replacingOccurrences(of: "/", with: "-") + ".json"
        }

        return "Peel Export.json"
    }

    private func resolvedTitle(from proposedTitle: String, for item: HistoryItem) -> String {
        let trimmedTitle = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return HistoryItem.defaultTitle(at: item.createdAt)
        }

        return trimmedTitle
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

        if mainWindows.isEmpty && !NSApp.windows.contains(where: \.canBecomeMain) {
            openMainWindow?()
        }

        bringMainWindowToFront()
        DispatchQueue.main.async { [weak self] in
            self?.bringMainWindowToFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.bringMainWindowToFront()
        }
    }

    private var mainWindows: [NSWindow] {
        NSApp.windows.filter { $0.identifier == Self.mainWindowIdentifier }
    }

    private func bringMainWindowToFront() {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)

        guard let window = mainWindows.first ?? NSApp.windows.first(where: \.canBecomeMain) else {
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct MainWindowRootView: View {
    @Environment(\.openWindow) private var openWindow

    let workspace: JSONWorkspace
    let editorLayoutSettings: EditorLayoutSettings
    let quickPasteController: QuickPasteController

    var body: some View {
        ContentView()
            .environment(workspace)
            .environment(editorLayoutSettings)
            .background(MainWindowMarker())
            .task {
                workspace.bindMainWindowOpener {
                    openWindow(id: JSONWorkspace.mainWindowSceneID)
                }
                quickPasteController.bind(workspace: workspace)
            }
    }
}

private struct MainWindowMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowMarkerView {
        WindowMarkerView()
    }

    func updateNSView(_ nsView: WindowMarkerView, context: Context) {
        nsView.markCurrentWindowIfNeeded()
    }
}

private final class WindowMarkerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        markCurrentWindowIfNeeded()
    }

    func markCurrentWindowIfNeeded() {
        guard let window else {
            return
        }

        window.identifier = JSONWorkspace.mainWindowIdentifier
        window.titleVisibility = .hidden
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

        CommandGroup(after: .saveItem) {
            Button("Close Window") {
                workspace.closeActiveWindow()
            }
            .keyboardShortcut("w")
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
            Button("Find") {
                workspace.performFocusedJSONFindCommand()
            }
            .keyboardShortcut("f")

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
