import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // Dock'ta gorunmez, sadece menu cubugu
        menuBar.install()
        izleOnplandakiUygulama()

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
            LongPressEngine.shared.frontmostBundleID =
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        }
        guncelle()
        wsnc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                         object: nil, queue: .main) { _ in guncelle() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LongPressEngine.shared.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
