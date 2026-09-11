import AppKit
import UniformTypeIdentifiers

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
        menu.addItem(mekanizmaMenusu())
        menu.addItem(tekrarMenusu())
        menu.addItem(genelEsikMenusu())
        menu.addItem(harfEsikleriMenusu())
        menu.addItem(uygulamaIstisnalariMenusu())

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

    /// Tusun nasil ele alindigi. Oyunlarda tek fark yaratan ayar bu.
    private func mekanizmaMenusu() -> NSMenuItem {
        let m = Settings.shared.mechanism
        let ust = NSMenuItem(title: "Mekanizma: \(m == .beklet ? "titremesiz" : "anlık")",
                             action: nil, keyEquivalent: "")
        let alt = NSMenu()

        let a = madde("Titremesiz — harf tuş bırakılınca çıkar", #selector(mekanizmaBeklet))
        a.state = m == .beklet ? .on : .off
        alt.addItem(a)

        let b = madde("Anlık — harf hemen çıkar, eşikte Türkçesiyle değişir", #selector(mekanizmaAnlik))
        b.state = m == .anlik ? .on : .off
        alt.addItem(b)

        alt.addItem(.separator())
        let not = NSMenuItem(title: m == .beklet
            ? "Oyunlarda tuş basılı kalmaz — istisna eklemen gerekir"
            : "Oyunlarda tuş basılı kalır — istisnaya gerek yok",
            action: nil, keyEquivalent: "")
        not.isEnabled = false
        alt.addItem(not)

        ust.submenu = alt
        return ust
    }

    /// Turkce harf yazildiktan sonra tus hala basiliysa ne tekrarlanacak.
    private func tekrarMenusu() -> NSMenuItem {
        let r = Settings.shared.repeatLetter
        let ust = NSMenuItem(title: "Basılı tutmaya devam edince", action: nil, keyEquivalent: "")
        let alt = NSMenu()

        let a = madde("Orijinal harf tekrarlasın   s s s", #selector(tekrarOrijinal))
        a.state = r == .orijinal ? .on : .off
        alt.addItem(a)

        let b = madde("Türkçe harf tekrarlasın   ş ş ş", #selector(tekrarTurkce))
        b.state = r == .turkce ? .on : .off
        alt.addItem(b)

        ust.submenu = alt
        return ust
    }

    /// Belirli uygulamalarda uzun basimi kapatir. Oyunlar icin gerekli: oyun
    /// tusun BASILI kalmasini bekler, uzun basim ise tusu tutup birakista basar.
    private func uygulamaIstisnalariMenusu() -> NSMenuItem {
        let kapali = Settings.shared.disabledApps
        let ust = NSMenuItem(
            title: kapali.isEmpty ? "Uygulama istisnaları" : "Uygulama istisnaları (\(kapali.count))",
            action: nil, keyEquivalent: "")
        let alt = NSMenu()

        let onplan = LongPressEngine.shared.onplandaki
        if !onplan.bundleID.isEmpty {
            let acik = kapali.contains(onplan.bundleID)
            let m = madde(acik ? "\(onplan.ad): kapalı" : "\(onplan.ad) için kapat",
                          #selector(onplandakiniDegistir))
            m.state = acik ? .on : .off
            alt.addItem(m)
            alt.addItem(.separator())
        }

        for id in kapali.sorted() {
            let m = madde(id, #selector(istisnaKaldir))
            m.representedObject = id
            m.state = .on
            alt.addItem(m)
        }
        if !kapali.isEmpty { alt.addItem(.separator()) }
        alt.addItem(madde("Uygulama seç…", #selector(uygulamaSec)))
        ust.submenu = alt
        return ust
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

    @objc private func tekrarOrijinal() { Settings.shared.repeatLetter = .orijinal }
    @objc private func tekrarTurkce()   { Settings.shared.repeatLetter = .turkce }

    @objc private func mekanizmaBeklet() { Settings.shared.mechanism = .beklet }
    @objc private func mekanizmaAnlik()  { Settings.shared.mechanism = .anlik }

    @objc private func onplandakiniDegistir() {
        let id = LongPressEngine.shared.onplandaki.bundleID
        guard !id.isEmpty else { return }
        var liste = Settings.shared.disabledApps
        if let i = liste.firstIndex(of: id) { liste.remove(at: i) } else { liste.append(id) }
        Settings.shared.disabledApps = liste
    }

    @objc private func istisnaKaldir(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Settings.shared.disabledApps = Settings.shared.disabledApps.filter { $0 != id }
    }

    @objc private func uygulamaSec() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.message = "Turkfuk'un devre dışı kalacağı uygulamaları seç"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }

        var liste = Settings.shared.disabledApps
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !liste.contains(id) { liste.append(id) }
        }
        Settings.shared.disabledApps = liste
    }

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
