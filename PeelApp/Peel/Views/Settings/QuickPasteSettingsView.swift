import AppKit
import SwiftUI

struct QuickPasteSettingsView: View {
    @ObservedObject var controller: QuickPasteController

    var body: some View {
        Form {
            Section("Quick Paste") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("全局快捷键")
                        .font(.headline)

                    Text("按下你想要的组合键后，它会马上生效。")
                        .foregroundStyle(.secondary)

                    ShortcutRecorderView(controller: controller)

                    Text("触发后会直接拉起 Peel，并把剪贴板内容作为一条新记录导入进来。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 500)
    }
}

private struct ShortcutRecorderView: View {
    @ObservedObject var controller: QuickPasteController

    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                currentShortcutBadge

                Button(isRecording ? "Press Shortcut" : "Record Shortcut") {
                    toggleRecording()
                }

                Button("Restore Default") {
                    stopRecording()
                    controller.restoreDefaultShortcut()
                    message = controller.registrationIssue == nil ? nil : controller.registrationIssue
                }
            }

            if let message = message ?? controller.registrationIssue {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            } else if isRecording {
                Text("现在直接按下新的快捷键，按 Esc 取消。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var currentShortcutBadge: some View {
        Text(controller.shortcut.displayString)
            .font(.system(.body, design: .monospaced).weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
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
