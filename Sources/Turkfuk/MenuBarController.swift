import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    func install() {
        guard Settings.shared.showMenuBarIcon else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam",
                                   accessibilityDescription: "Turkfuk")
            button.image?.isTemplate = true
        }
        item.menu = buildMenu()
        statusItem = item
    }

    func remove() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let durum = NSMenuItem(title: Permissions.isTrusted
                                 ? "Erişilebilirlik izni: verildi"
                                 : "Erişilebilirlik izni GEREKLİ — tıkla",
                               action: Permissions.isTrusted ? nil : #selector(izinAc),
                               keyEquivalent: "")
        durum.target = self
        durum.isEnabled = !Permissions.isTrusted
        menu.addItem(durum)

        menu.addItem(.separator())
        let cikis = NSMenuItem(title: "Turkfuk'tan çık", action: #selector(cik), keyEquivalent: "q")
        cikis.target = self
        menu.addItem(cikis)
        return menu
    }

    @objc private func izinAc() { Permissions.openSettingsPane() }
    @objc private func cik() { NSApp.terminate(nil) }
}
