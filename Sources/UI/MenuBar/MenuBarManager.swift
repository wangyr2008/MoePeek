import AppKit
import Defaults
import KeyboardShortcuts

/// Owns the `NSStatusItem` menu bar presence. Replaces the SwiftUI `MenuBarExtra` scene,
/// which is only available on macOS 13+; the native menu works on macOS 12 and later.
@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {
    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?
    private var iconObservers: [any Defaults.Observation] = []

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        applyIcon()
        rebuildMenuItems(in: menu)
        observeIconChanges()
    }

    deinit {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    // MARK: - Icon

    /// The five icon-related Defaults keys can change live from Settings; re-apply on change.
    private func observeIconChanges() {
        iconObservers = [
            Defaults.observe(.menuBarIconStyle, options: []) { [weak self] _ in self?.applyIcon() },
            Defaults.observe(.menuBarCustomIconSource, options: []) { [weak self] _ in self?.applyIcon() },
            Defaults.observe(.menuBarCustomSymbolName, options: []) { [weak self] _ in self?.applyIcon() },
            Defaults.observe(.menuBarCustomIconIsTemplate, options: []) { [weak self] _ in self?.applyIcon() },
            Defaults.observe(.menuBarCustomIconRevision, options: []) { [weak self] _ in self?.applyIcon() },
        ]
    }

    private func currentIcon() -> NSImage? {
        func fallbackSymbol() -> NSImage? {
            NSImage(systemSymbolName: MenuBarIconCatalog.defaultSymbol, accessibilityDescription: nil)
        }
        let image: NSImage?
        switch Defaults[.menuBarIconStyle] {
        case .filled:
            image = fallbackSymbol()
        case .custom:
            switch Defaults[.menuBarCustomIconSource] {
            case .symbol:
                image = NSImage(systemSymbolName: Defaults[.menuBarCustomSymbolName], accessibilityDescription: nil)
                    ?? fallbackSymbol()
            case .image:
                image = MenuBarIconStore.loadCustomIcon(isTemplate: Defaults[.menuBarCustomIconIsTemplate])
                    ?? fallbackSymbol()
            }
        }
        guard let image else { return nil }
        // Menu bar glyphs should render at the standard thickness; SF Symbols arrive
        // pre-sized, custom uploads get clamped to a 16pt square.
        if image.size.width > 16 || image.size.height > 16 {
            let longest = max(image.size.width, image.size.height)
            let scale = 16 / longest
            image.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        }
        return image
    }

    private func applyIcon() {
        guard let button = statusItem?.button else { return }
        button.image = currentIcon()
        // Custom images honor the user's template toggle; SF Symbols default to template.
        if Defaults[.menuBarIconStyle] == .custom,
           Defaults[.menuBarCustomIconSource] == .image {
            button.image?.isTemplate = Defaults[.menuBarCustomIconIsTemplate]
        } else {
            button.image?.isTemplate = true
        }
    }

    // MARK: - Menu

    private func rebuildMenuItems(in menu: NSMenu) {
        menu.removeAllItems()

        let appDelegate = self.appDelegate
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

        let titleItem = NSMenuItem(
            title: String(localized: "MoePeek \(appVersion)"),
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        addItem(
            to: menu,
            title: String(localized: "Smart Translation"),
            shortcut: .smartTranslation
        ) { appDelegate?.performSmartTranslation() }

        addItem(
            to: menu,
            title: String(localized: "Manual Translation"),
            shortcut: .inputTranslation
        ) {
            guard let appDelegate else { return }
            appDelegate.cancelSmartTranslation()
            appDelegate.coordinator.prepareInputMode()
            appDelegate.panelController.showAtScreenCenter()
        }

        addItem(
            to: menu,
            title: String(localized: "Screenshot OCR"),
            shortcut: .ocrScreenshot
        ) {
            guard let appDelegate else { return }
            appDelegate.cancelSmartTranslation()
            Task { @MainActor in
                let outcome = await appDelegate.coordinator.ocrAndTranslate()
                if outcome.shouldPresent {
                    appDelegate.panelController.showAtCursor()
                }
            }
        }

        addItem(
            to: menu,
            title: String(localized: "Silent OCR"),
            shortcut: .silentOCR
        ) { appDelegate?.performSilentOCR() }

        addItem(
            to: menu,
            title: String(localized: "Selection Translation"),
            shortcut: .translateSelection
        ) {
            guard let appDelegate else { return }
            Task { @MainActor in
                await appDelegate.cancelSmartTranslationAndWait()
                let outcome = await appDelegate.coordinator.translateSelection()
                if outcome.shouldPresent {
                    appDelegate.panelController.showAtCursor()
                }
            }
        }

        addItem(
            to: menu,
            title: String(localized: "Clipboard Translation"),
            shortcut: .clipboardTranslation
        ) {
            guard let appDelegate else { return }
            Task { @MainActor in
                await appDelegate.cancelSmartTranslationAndWait()
                await appDelegate.coordinator.translateClipboard()
                appDelegate.panelController.showAtCursor()
            }
        }

        menu.addItem(.separator())

        addItem(to: menu, title: String(localized: "Onboarding Guide...")) {
            appDelegate?.onboardingController.showWindow()
        }

        let settingsItem = addItem(to: menu, title: String(localized: "Settings...")) {
            appDelegate?.settingsController.showWindow()
        }
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = .command

        menu.addItem(.separator())

        let quitItem = addItem(to: menu, title: String(localized: "Quit MoePeek")) {
            NSApp.terminate(nil)
        }
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = .command
    }

    /// `shortcutNameTag` identifies items whose key equivalent mirrors a global
    /// shortcut; 0 means "no shortcut hint". Tags 1...n map into `shortcutNameTagOrder`.
    private static let shortcutNameTagOrder: [KeyboardShortcuts.Name] = [
        .smartTranslation,
        .inputTranslation,
        .ocrScreenshot,
        .silentOCR,
        .translateSelection,
        .clipboardTranslation,
    ]

    private func addItem(
        to menu: NSMenu,
        title: String,
        shortcut: KeyboardShortcuts.Name? = nil,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(menuItemAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = MenuItemAction(handler: action)
        if let shortcut, let tag = Self.shortcutNameTagOrder.firstIndex(of: shortcut) {
            item.tag = tag + 1
        }
        item.isEnabled = true
        menu.addItem(item)
        applyShortcut(to: item, name: shortcut)
        return item
    }

    private func applyShortcut(to item: NSMenuItem, name: KeyboardShortcuts.Name?) {
        guard let name, let shortcut = KeyboardShortcuts.get(name) else { return }
        item.keyEquivalent = shortcut.nsMenuItemKeyEquivalent ?? ""
        item.keyEquivalentModifierMask = shortcut.modifiers
    }

    @objc private func menuItemAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? MenuItemAction else { return }
        action.run()
    }

    /// Refresh shortcut hints each time the menu is about to open, so bindings changed
    /// in Settings are reflected immediately.
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            for item in menu.items where item.action != nil {
                guard item.tag > 0, item.tag <= Self.shortcutNameTagOrder.count else { continue }
                let name = Self.shortcutNameTagOrder[item.tag - 1]
                item.keyEquivalent = KeyboardShortcuts.get(name)?.nsMenuItemKeyEquivalent ?? ""
                item.keyEquivalentModifierMask = KeyboardShortcuts.get(name)?.modifiers ?? []
            }
        }
    }
}

/// Boxed action stored in `NSMenuItem.representedObject` (closures can't be selectors).
@MainActor
private final class MenuItemAction {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func run() {
        handler()
    }
}
