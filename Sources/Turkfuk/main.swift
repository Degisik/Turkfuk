import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // Dock'ta gorunmez, sadece menu cubugu
        menuBar.install()
        izleOnplandakiUygulama()

        // Kurulum betigi girise ekleme istediyse burada kaydediyoruz:
        // SMAppService cagrisini uygulamanin kendisi yapmak zorunda.
        if Settings.shared.launchAtLogin && !LaunchAtLogin.isEnabled {
            LaunchAtLogin.set(true)
        }

        if Permissions.isTrusted {
            LongPressEngine.shared.start()
        } else {
            Permissions.requestTrust()
            beklePermission()
        }

        NotificationCenter.default.addObserver(
            forName: Settings.changed, object: nil, queue: .main
        ) { [weak self] _ in self?.menuBar.refresh() }
    }

    /// Izin verilene kadar saniyede bir bak; verilince motoru baslat.
    private func beklePermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard Permissions.isTrusted else { return }
            t.invalidate()
            self?.permissionTimer = nil
            LongPressEngine.shared.start()
            self?.menuBar.refresh()
        }
    }

    /// Uygulama bazli devre disi birakma icin onplandaki uygulamayi takip et.
    private func izleOnplandakiUygulama() {
        let wsnc = NSWorkspace.shared.notificationCenter
        let guncelle = {
            guard let app = NSWorkspace.shared.frontmostApplication else { return }
            // Java ile calisan oyunlarin bundle id'si olmayabiliyor; o durumda
            // yurutulebilir adina dusuyoruz ki istisna yine de eklenebilsin.
            let id = app.bundleIdentifier
                ?? app.executableURL.map { "proc:" + $0.lastPathComponent }
                ?? ""
            guard !id.isEmpty, id != Bundle.main.bundleIdentifier else { return }
            LongPressEngine.shared.onplandaki = (id, app.localizedName ?? id)
        }
        guncelle()
        wsnc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                         object: nil, queue: .main) { _ in guncelle() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LongPressEngine.shared.stop()
    }
}

// Derleme zamani simge uretimi: build.sh bu bayrakla cagirir.
if let i = CommandLine.arguments.firstIndex(of: "--write-iconset"),
   i + 1 < CommandLine.arguments.count {
    _ = NSApplication.shared
    try IconArt.iconsetYaz(URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
