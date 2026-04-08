import AppKit
import Observation
import SwiftUI

struct WindowThemeConfigurator: NSViewRepresentable {
    let themePreference: AppThemePreference
    let systemColorScheme: ColorScheme
    var useSettingsStyle = false

    func makeNSView(context: Context) -> WindowThemeObserverView {
        let view = WindowThemeObserverView()
        view.onWindowChange = applyTheme
        return view
    }

    func updateNSView(_ nsView: WindowThemeObserverView, context: Context) {
        nsView.onWindowChange = applyTheme
        nsView.configureWindowIfPossible()
    }

    private func applyTheme(to window: NSWindow) {
        window.appearance = themePreference.resolvedWindowAppearance(
            systemColorScheme: systemColorScheme
        )
        window.contentView?.needsLayout = true
        window.displayIfNeeded()

        if useSettingsStyle {
            window.toolbarStyle = .preference
            window.titlebarSeparatorStyle = .none
        } else {
            window.titlebarSeparatorStyle = .automatic
        }
    }
}

final class WindowThemeObserverView: NSView {
    var onWindowChange: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowIfPossible()
    }

    func configureWindowIfPossible() {
        guard let window else {
            return
        }

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            self.onWindowChange?(window)
        }
    }
}

@MainActor
@Observable
final class SystemAppearanceMonitor {
    var colorScheme: ColorScheme

    @ObservationIgnored
    private var distributedObserver: Any?

    @ObservationIgnored
    private var activeObserver: Any?

    init() {
        colorScheme = SystemAppearanceMonitor.readColorScheme()

        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        colorScheme = Self.readColorScheme()
    }

    private static func readColorScheme() -> ColorScheme {
        let globalDefaults = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
        let interfaceStyle = (globalDefaults?["AppleInterfaceStyle"] as? String)?.lowercased()
        return interfaceStyle == "dark" ? .dark : .light
    }
}
