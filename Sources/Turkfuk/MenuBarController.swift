import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    /// Esik menulerinde gosterilen hazir degerler.
    private let hazirEsikler = [80, 100, 120, 150, 180, 220, 300]

    func install() {
        guard Settings.shared.showMenuBarIcon, statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = IconArt.menuCubuguSimgesi()
        statusItem = item
        refresh()
    }

    func remove() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
    }

    func refresh() {
        guard let item = statusItem else { return }
        item.button?.alphaValue = Settings.shared.enabled ? 1.0 : 0.4
        item.menu = buildMenu()
    }

    // MARK: - Menu

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

        menu.addItem(kisayolMenusu())

        menu.addItem(.separator())
        menu.addItem(genelEsikMenusu())
        menu.addItem(harfEsikleriMenusu())

        menu.addItem(.separator())
        let giris = madde("Girişte başlat", #selector(giristeBaslat))
        giris.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(giris)

        menu.addItem(.separator())
        menu.addItem(madde("Turkfuk'tan çık", #selector(cik)))
        return menu
    }

    /// Ac/kapat kisayolu.
    private func kisayolMenusu() -> NSMenuItem {
        let hk = Settings.shared.hotkey
        let ust = NSMenuItem(title: "Kısayol: \(hk?.display ?? "yok")", action: nil, keyEquivalent: "")
        let alt = NSMenu()
        alt.addItem(madde("Kısayolu değiştir…", #selector(kisayolDegistir)))
        if hk != nil { alt.addItem(madde("Kısayolu kaldır", #selector(kisayolKaldir))) }
        ust.submenu = alt
        return ust
    }

    /// Butun harfler icin gecerli olan taban esik.
    private func genelEsikMenusu() -> NSMenuItem {
        let ust = NSMenuItem(title: "Genel eşik: \(Settings.shared.threshold) ms",
                             action: nil, keyEquivalent: "")
        let alt = NSMenu()
        for ms in hazirEsikler {
            let m = madde("\(ms) ms", #selector(genelEsikSec))
            m.tag = ms
            m.state = (Settings.shared.threshold == ms) ? .on : .off
            alt.addItem(m)
        }
        alt.addItem(.separator())
        alt.addItem(madde("Özel değer…", #selector(genelEsikOzel)))
        ust.submenu = alt
        return ust
    }

    /// Harf basina esik. Ozel deger verilmemis harf genel esigi kullanir.
    private func harfEsikleriMenusu() -> NSMenuItem {
        let ozelSayisi = Settings.shared.perKey.count
        let ust = NSMenuItem(
            title: ozelSayisi == 0 ? "Harf eşikleri" : "Harf eşikleri (\(ozelSayisi) özel)",
            action: nil, keyEquivalent: "")
        let alt = NSMenu()

        for key in TurkishKeys.all {
            let ozel = Settings.shared.perKey[key.ascii]
            let deger = ozel.map { "\($0) ms" } ?? "genel · \(Settings.shared.threshold) ms"
            let harf = NSMenuItem(title: "\(key.ascii) → \(key.lower)     \(deger)",
                                  action: nil, keyEquivalent: "")
            harf.submenu = harfAltMenusu(key: key, ozel: ozel)
            alt.addItem(harf)
        }

        if ozelSayisi > 0 {
            alt.addItem(.separator())
            alt.addItem(madde("Tüm özel eşikleri sıfırla", #selector(harfEsikleriSifirla)))
        }
        ust.submenu = alt
        return ust
    }

    private func harfAltMenusu(key: TurkishKey, ozel: Int?) -> NSMenu {
        let sub = NSMenu()
        let genel = madde("Genel eşiği kullan", #selector(harfEsikGenel))
        genel.representedObject = key.ascii
        genel.state = (ozel == nil) ? .on : .off
        sub.addItem(genel)
        sub.addItem(.separator())
        for ms in hazirEsikler {
            let m = madde("\(ms) ms", #selector(harfEsikSec))
            m.tag = ms
            m.representedObject = key.ascii
            m.state = (ozel == ms) ? .on : .off
            sub.addItem(m)
        }
        sub.addItem(.separator())
        let o = madde("Özel değer…", #selector(harfEsikOzel))
        o.representedObject = key.ascii
        sub.addItem(o)
        return sub
    }

    private func madde(_ baslik: String, _ eylem: Selector) -> NSMenuItem {
        let m = NSMenuItem(title: baslik, action: eylem, keyEquivalent: "")
        m.target = self
        return m
    }

    /// Milisaniye soran kucuk diyalog. nil = iptal.
    private func msSor(baslik: String, aciklama: String, mevcut: Int) -> Int? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = baslik
        alert.informativeText = aciklama
        alert.addButton(withTitle: "Tamam")
        alert.addButton(withTitle: "Vazgeç")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(mevcut)
        field.placeholderString = "40 – 1000"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard let ms = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) else { return nil }
        return max(40, min(1000, ms))
    }

    // MARK: - Eylemler

    @objc private func izinAc() { Permissions.openSettingsPane() }
    @objc private func acKapat() { Settings.shared.enabled.toggle() }
    @objc private func cik() { NSApp.terminate(nil) }
    @objc private func giristeBaslat() { LaunchAtLogin.set(!LaunchAtLogin.isEnabled); refresh() }

    @objc private func genelEsikSec(_ sender: NSMenuItem) { Settings.shared.threshold = sender.tag }

    @objc private func genelEsikOzel() {
        if let ms = msSor(baslik: "Genel eşik",
                          aciklama: "Türkçe harfin devreye girmesi için tuşun kaç milisaniye basılı tutulması gerektiği.",
                          mevcut: Settings.shared.threshold) {
            Settings.shared.threshold = ms
        }
    }

    @objc private func harfEsikSec(_ sender: NSMenuItem) {
        guard let harf = sender.representedObject as? String else { return }
        Settings.shared.setThreshold(sender.tag, for: harf)
    }

    @objc private func harfEsikGenel(_ sender: NSMenuItem) {
        guard let harf = sender.representedObject as? String else { return }
        Settings.shared.setThreshold(nil, for: harf)
    }

    @objc private func harfEsikOzel(_ sender: NSMenuItem) {
        guard let harf = sender.representedObject as? String,
              let key = TurkishKeys.all.first(where: { $0.ascii == harf }) else { return }
        if let ms = msSor(baslik: "\(key.ascii) → \(key.lower) eşiği",
                          aciklama: "Yalnızca bu harf için geçerli olur. Parmağın uzun kaldığı harflerde bu değeri yükselt.",
                          mevcut: Settings.shared.threshold(for: harf)) {
            Settings.shared.setThreshold(ms, for: harf)
        }
    }

    @objc private func harfEsikleriSifirla() { Settings.shared.perKey = [:] }

    @objc private func kisayolKaldir() { Settings.shared.setHotkey(nil) }

    @objc private func kisayolDegistir() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Yeni kısayol"
        alert.informativeText = """
            Kullanmak istediğin tuş birleşimine bas.
            En az bir değiştirici gerekli: ⌘ ⌃ ⌥ ⇧
            Vazgeçmek için Esc.
            """
        alert.addButton(withTitle: "Vazgeç")

        // Kayit motorun kendi olay yakalayicisindan geliyor; pencere odagina bagli degil.
        LongPressEngine.shared.beginHotkeyRecording { yeni in
            DispatchQueue.main.async {
                if let yeni { Settings.shared.setHotkey(yeni) }
                NSApp.stopModal()
            }
        }
        alert.runModal()
        LongPressEngine.shared.endHotkeyRecording()
        refresh()
    }
}
