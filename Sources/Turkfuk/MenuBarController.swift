import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    func install() {
        guard Settings.shared.showMenuBarIcon, statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "character.cursor.ibeam",
                                     accessibilityDescription: "Turkfuk")
        item.button?.image?.isTemplate = true
        statusItem = item
        refresh()
    }

    func remove() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
    }

    /// Menuyu ve simge gorunumunu mevcut ayarlara gore yeniden kurar.
    func refresh() {
        guard let item = statusItem else { return }
        item.button?.alphaValue = Settings.shared.enabled ? 1.0 : 0.4
        item.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if !Permissions.isTrusted {
            menu.addItem(madde("⚠︎ Erişilebilirlik izni gerekli — tıkla", #selector(izinAc)))
            menu.addItem(.separator())
        }

        let ac = madde(Settings.shared.enabled ? "Türkçe uzun basım: AÇIK" : "Türkçe uzun basım: KAPALI",
                       #selector(acKapat))
        ac.state = Settings.shared.enabled ? .on : .off
        menu.addItem(ac)
        menu.addItem(NSMenuItem(title: "Kısayol: ⌃⌥⌘T", action: nil, keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(esikMenusu())

        menu.addItem(.separator())
        let giris = madde("Girişte başlat", #selector(giristeBaslat))
        giris.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(giris)

        menu.addItem(.separator())
        menu.addItem(madde("Turkfuk'tan çık", #selector(cik)))
        return menu
    }

    /// Genel esik icin hazir degerler.
    private func esikMenusu() -> NSMenuItem {
        let ust = NSMenuItem(title: "Eşik: \(Settings.shared.threshold) ms", action: nil, keyEquivalent: "")
        let alt = NSMenu()
        for ms in [80, 100, 120, 150, 180, 220, 300] {
            let m = madde("\(ms) ms", #selector(esikSec))
            m.tag = ms
            m.state = (Settings.shared.threshold == ms) ? .on : .off
            alt.addItem(m)
        }
        ust.submenu = alt
        return ust
    }

    private func madde(_ baslik: String, _ eylem: Selector) -> NSMenuItem {
        let m = NSMenuItem(title: baslik, action: eylem, keyEquivalent: "")
        m.target = self
        return m
    }

    // MARK: - Eylemler

    @objc private func izinAc() { Permissions.openSettingsPane() }
    @objc private func acKapat() { Settings.shared.enabled.toggle() }
    @objc private func esikSec(_ sender: NSMenuItem) { Settings.shared.threshold = sender.tag }
    @objc private func giristeBaslat() { LaunchAtLogin.set(!LaunchAtLogin.isEnabled); refresh() }
    @objc private func cik() { NSApp.terminate(nil) }
}
