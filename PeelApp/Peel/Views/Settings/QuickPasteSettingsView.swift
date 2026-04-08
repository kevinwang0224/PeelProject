import AppKit
import SwiftUI

struct PeelSettingsView: View {
    @Environment(SettingsNavigationState.self) private var settingsNavigationState
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    @Environment(SystemAppearanceMonitor.self) private var systemAppearanceMonitor
    @ObservedObject var controller: QuickPasteController

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(selection: categorySelection)
                .frame(width: 220)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            settingsDetailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .font(editorLayoutSettings.uiFont(12))
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            WindowThemeConfigurator(
                themePreference: editorLayoutSettings.appThemePreference,
                systemColorScheme: systemAppearanceMonitor.colorScheme,
                useSettingsStyle: true
            )
        )
        .frame(minWidth: 900, minHeight: 560)
    }

    @ViewBuilder
    private var settingsDetailView: some View {
        switch settingsNavigationState.selectedCategory {
        case .shortcuts:
            QuickPasteSettingsView(controller: controller)
        case .appearance:
            AppearanceSettingsView()
        case .about:
            AboutSettingsView()
        }
    }

    private var categorySelection: Binding<PeelSettingsCategory?> {
        Binding(
            get: { settingsNavigationState.selectedCategory },
            set: { newValue in
                guard let newValue else {
                    return
                }

                settingsNavigationState.select(newValue)
            }
        )
    }
}

struct QuickPasteSettingsView: View {
    @ObservedObject var controller: QuickPasteController

    var body: some View {
        SettingsFormContainer(title: "快捷键") {
            Form {
                Section {
                    LabeledContent {
                        ShortcutRecorderView(controller: controller)
                    } label: {
                        SettingsRowLabel(
                            title: "全局快捷键",
                            description: "调起 Peel，并导入剪切板内容。"
                        )
                    }
                } header: {
//                    Text("全局快捷粘贴")
                } footer: {
//                    Text("触发后会直接拉起 Peel，并把剪贴板内容作为一条新记录导入进来。")
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct AppearanceSettingsView: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings

    var body: some View {
        SettingsFormContainer(title: "外观") {
            Form {
                Section {
                    LabeledContent {
                        Picker(
                            "界面主题",
                            selection: Binding(
                                get: { editorLayoutSettings.appThemePreference },
                                set: { editorLayoutSettings.updateAppThemePreference($0) }
                            )
                        ) {
                            ForEach(AppThemePreference.allCases) { theme in
                                Label(theme.title, systemImage: theme.systemImage)
                                    .tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    } label: {
                        SettingsRowLabel(
                            title: "界面主题",
                            description: "使用浅色、深色，或匹配系统设置。"
                        )
                    }
                } header: {
                    Text("主题")
                }

                Section {
                    LabeledContent {
                        FontSizeStepper(
                            value: Binding(
                                get: { editorLayoutSettings.interfaceFontSize },
                                set: { editorLayoutSettings.updateInterfaceFontSize($0) }
                            )
                        )
                    } label: {
                        SettingsRowLabel(
                            title: "界面字体",
                            description: "调整侧边栏、面板标题和常用说明文字的大小。"
                        )
                    }

                    LabeledContent {
                        FontSizeStepper(
                            value: Binding(
                                get: { editorLayoutSettings.editorFontSize },
                                set: { editorLayoutSettings.updateEditorFontSize($0) }
                            )
                        )
                    } label: {
                        SettingsRowLabel(
                            title: "编辑器字体",
                            description: "调整编辑器的内容字体大小。"
                        )
                    }
                } header: {
                    Text("字体大小")
                }

                Section {
                    LabeledContent {
                        Picker(
                            "编辑器布局",
                            selection: Binding(
                                get: { editorLayoutSettings.resultLayout },
                                set: { editorLayoutSettings.updateResultLayout($0) }
                            )
                        ) {
                            ForEach(ExtractionResultLayout.allCases) { layout in
                                Text(layout.title).tag(layout)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    } label: {
                        SettingsRowLabel(
                            title: "显示方式",
                            description: editorLayoutSettings.resultLayout.detail
                        )
                    }
                } header: {
                    Text("编辑器布局")
                } footer: {
//                    Text("代码编辑区会始终固定在底部。")
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        SettingsFormContainer(title: "关于") {
            Form {
                Section {
                    HStack(alignment: .center, spacing: 14) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appName)
                                .font(.headline)

                            Text("轻量、启动快、界面简洁的 JSON 格式化和编辑工具。")
                                .foregroundStyle(.secondary)

//                            Text("版本 \(version)（构建 \(build)）")
//                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("应用信息")
                }

                Section {
                    LabeledContent("版本", value: version)
                    LabeledContent("构建", value: build)
                } header: {
                    Text("版本信息")
                }
            }
            .formStyle(.grouped)
        }
    }

    private var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String,
           !bundleName.isEmpty {
            return bundleName
        }

        return "Peel"
    }

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }

    private var build: String {
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String) ?? "1"
    }
}

private struct SettingsSidebarView: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    @Binding var selection: PeelSettingsCategory?

    var body: some View {
        List(selection: $selection) {
            ForEach(PeelSettingsCategory.allCases) { category in
                Label(category.title, systemImage: category.systemImage)
                    .font(editorLayoutSettings.uiFont(13, weight: .medium))
                    .padding(.vertical, 4)
                    .tag(category)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
        .padding(.top, 12)
    }
}

private struct SettingsFormContainer<Content: View>: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    private let titleLeadingInset: CGFloat = 30
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(editorLayoutSettings.uiFont(20, weight: .semibold))
                .padding(.leading, titleLeadingInset)
                .padding(.trailing, 24)
                .padding(.top, 22)
                .padding(.bottom, 4)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct SettingsRowLabel: View {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(editorLayoutSettings.uiFont(12, weight: .medium))

            Text(description)
                .font(editorLayoutSettings.uiFont(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

private struct FontSizeStepper: View {
    @Binding var value: CGFloat
    @FocusState private var isInputFocused: Bool
    @State private var inputText = ""

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                TextField("", text: $inputText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 34)
                    .padding(.leading, 10)
                    .padding(.trailing, 8)
                    .focused($isInputFocused)
                    .onSubmit(commitInput)
                    .onChange(of: isInputFocused) { _, newValue in
                        if !newValue {
                            commitInput()
                        }
                    }

                Divider()
                    .frame(height: 32)

                VStack(spacing: 0) {
                    stepperButton(
                        systemImage: "chevron.up",
                        action: incrementValue
                    )
                    .disabled(value >= EditorLayoutSettings.maximumFontSize)

                    Divider()

                    stepperButton(
                        systemImage: "chevron.down",
                        action: decrementValue
                    )
                    .disabled(value <= EditorLayoutSettings.minimumFontSize)
                }
                .frame(width: 30, height: 34)
            }
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            Text("px")
                .foregroundStyle(.secondary)
        }
        .controlSize(.small)
        .onAppear {
            syncInputText()
        }
        .onChange(of: value) { _, _ in
            syncInputText()
        }
    }

    private func commitInput() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let inputValue = Int(trimmedInput), !trimmedInput.isEmpty else {
            syncInputText()
            return
        }

        let clampedValue = min(
            max(CGFloat(inputValue), EditorLayoutSettings.minimumFontSize),
            EditorLayoutSettings.maximumFontSize
        )
        value = clampedValue
        syncInputText()
    }

    private func syncInputText() {
        inputText = String(Int(value.rounded()))
    }

    private func incrementValue() {
        value = min(value + 1, EditorLayoutSettings.maximumFontSize)
    }

    private func decrementValue() {
        value = max(value - 1, EditorLayoutSettings.minimumFontSize)
    }

    private func stepperButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(.clear)

                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutRecorderView: View {
    @ObservedObject var controller: QuickPasteController

    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: toggleRecording) {
                    currentShortcutBadge
                }
                .buttonStyle(.plain)

                Button {
                    stopRecording()
                    controller.removeShortcut()
                    message = nil
                } label: {
                    Image(systemName: "trash")
                }
                .help("删除快捷键")
                .disabled(controller.shortcut == nil && !isRecording)

                Button {
                    stopRecording()
                    controller.restoreDefaultShortcut()
                    message = controller.registrationIssue == nil ? nil : controller.registrationIssue
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("恢复默认")
                .disabled(controller.shortcut == .default && !isRecording)
            }

            if let message = message ?? controller.registrationIssue {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.trailing)
            } else if isRecording {
                Text("现在直接按下新的快捷键，按 Esc 取消。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else if controller.shortcut == nil {
                Text("当前没有快捷键，点左侧框开始录入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minWidth: 250, alignment: .trailing)
        .onDisappear {
            stopRecording()
        }
    }

    private var currentShortcutBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: badgeIconName)
                .foregroundStyle(isRecording ? Color.accent : .secondary)

            Text(badgeTitle)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isRecording ? Color.accent.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isRecording ? Color.accent : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var badgeIconName: String {
        if isRecording {
            return "keyboard.badge.ellipsis"
        }

        return "keyboard"
    }

    private var badgeTitle: String {
        if isRecording {
            return "按下快捷键"
        }

        return controller.shortcut?.displayString ?? "未设置"
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard localMonitor == nil else {
            return
        }

        message = nil
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            stopRecording()
            message = nil
            return
        }

        guard let shortcut = QuickPasteShortcut.captureCandidate(from: event) else {
            return
        }

        switch controller.updateShortcut(shortcut) {
        case .success:
            message = nil
        case .failure(let error):
            message = error.message
        }

        stopRecording()
    }
}
