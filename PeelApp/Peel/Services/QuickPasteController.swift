import AppKit
import Carbon.HIToolbox
import Combine

struct QuickPasteShortcutUpdateError: Error {
    let message: String
}

@MainActor
final class QuickPasteController: ObservableObject {
    @Published private(set) var shortcut: QuickPasteShortcut?
    @Published private(set) var registrationIssue: String?

    private weak var workspace: JSONWorkspace?
    private let registrar = GlobalHotKeyRegistrar()
    private let userDefaults: UserDefaults
    private let storageKey = "quickPasteShortcut"
    private let enabledStorageKey = "quickPasteShortcutEnabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let isEnabled = userDefaults.object(forKey: enabledStorageKey) as? Bool ?? true

        if isEnabled,
           let data = userDefaults.data(forKey: storageKey),
           let storedShortcut = try? JSONDecoder().decode(QuickPasteShortcut.self, from: data) {
            shortcut = storedShortcut
        } else if isEnabled {
            shortcut = .default
        } else {
            shortcut = nil
        }
    }

    var menuCommandTitle: String {
        if let shortcut {
            return "Quick Paste from Clipboard (\(shortcut.displayString))"
        }

        return "Quick Paste from Clipboard (No Shortcut)"
    }

    func bind(workspace: JSONWorkspace) {
        self.workspace = workspace
        registerCurrentShortcut(notifyOnFailure: true)
    }

    @discardableResult
    func updateShortcut(_ candidate: QuickPasteShortcut) -> Result<Void, QuickPasteShortcutUpdateError> {
        if let validationMessage = QuickPasteShortcutValidator.validationMessage(for: candidate) {
            registrationIssue = validationMessage
            return .failure(QuickPasteShortcutUpdateError(message: validationMessage))
        }

        if candidate == shortcut {
            registrationIssue = nil
            return .success(())
        }

        guard workspace != nil else {
            shortcut = candidate
            registrationIssue = nil
            persistShortcut(candidate)
            return .success(())
        }

        let previousShortcut = shortcut
        let status = registrar.register(shortcut: candidate) { [weak self] in
            self?.handleHotKeyTrigger()
        }

        guard status == noErr else {
            if let previousShortcut {
                _ = registrar.register(shortcut: previousShortcut) { [weak self] in
                    self?.handleHotKeyTrigger()
                }
            } else {
                registrar.unregister()
            }

            let message = registrationMessage(for: status)
            registrationIssue = message
            return .failure(QuickPasteShortcutUpdateError(message: message))
        }

        shortcut = candidate
        registrationIssue = nil
        persistShortcut(candidate)
        return .success(())
    }

    func restoreDefaultShortcut() {
        _ = updateShortcut(.default)
    }

    func removeShortcut() {
        registrar.unregister()
        shortcut = nil
        registrationIssue = nil
        persistShortcut(nil)
    }

    func runQuickPasteFromMenu() {
        workspace?.performQuickPasteImport(shouldActivateApp: false)
    }

    private func registerCurrentShortcut(notifyOnFailure: Bool) {
        guard let shortcut else {
            registrar.unregister()
            registrationIssue = nil
            return
        }

        let status = registrar.register(shortcut: shortcut) { [weak self] in
            self?.handleHotKeyTrigger()
        }

        guard status != noErr else {
            registrationIssue = nil
            return
        }

        let message = registrationMessage(for: status)
        registrationIssue = message

        if notifyOnFailure {
            workspace?.showNotice("当前快捷键没有生效，请到设置里重新设置。")
        }
    }

    private func handleHotKeyTrigger() {
        Task { @MainActor [weak self] in
            self?.workspace?.performQuickPasteImport(shouldActivateApp: true)
        }
    }

    private func persistShortcut(_ shortcut: QuickPasteShortcut?) {
        guard let shortcut else {
            userDefaults.removeObject(forKey: storageKey)
            userDefaults.set(false, forKey: enabledStorageKey)
            return
        }

        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
        userDefaults.set(true, forKey: enabledStorageKey)
    }

    private func registrationMessage(for status: OSStatus) -> String {
        if status == eventHotKeyExistsErr {
            return "这个组合已经被系统或其他应用占用，请换一个。"
        }

        return "这个组合现在不能用，请换一个。"
    }
}

private final class GlobalHotKeyRegistrar {
    private static let signature = OSType(0x5045454C)
    private static let hotKeyID = UInt32(1)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    deinit {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(shortcut: QuickPasteShortcut, handler: @escaping () -> Void) -> OSStatus {
        installEventHandlerIfNeeded()
        unregister()
        self.handler = handler

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            self.hotKeyRef = hotKeyRef
        }

        return status
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else {
                    return noErr
                }

                let registrar = Unmanaged<GlobalHotKeyRegistrar>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return registrar.handleHotKeyEvent(eventRef)
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleHotKeyEvent(_ eventRef: EventRef?) -> OSStatus {
        guard let eventRef else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == Self.signature,
              hotKeyID.id == Self.hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }

        handler?()
        return noErr
    }
}
