import Foundation

/// Tum ayarlar UserDefaults'ta yasar; menu cubugu ve kurulum betigi ayni anahtarlari kullanir.
final class Settings {
    static let shared = Settings()

    private let d = UserDefaults.standard

    enum Key: String {
        case enabled          = "enabled"           // uzun basim acik mi
        case threshold        = "threshold"         // genel esik (ms)
        case perKey           = "perKey"            // harf basina esik [String: Int]
        case showMenuBarIcon  = "showMenuBarIcon"   // menu cubugunda gorunsun mu
        case launchAtLogin    = "launchAtLogin"
        case useOptionOutput  = "useOptionOutput"   // unicode yerine ⌥ tusu simulasyonu
        case disabledApps     = "disabledApps"      // bundle id listesi
    }

    private init() {
        d.register(defaults: [
            Key.enabled.rawValue: true,
            Key.threshold.rawValue: 150,
            Key.perKey.rawValue: [String: Int](),
            Key.showMenuBarIcon.rawValue: true,
            Key.launchAtLogin.rawValue: false,
            Key.useOptionOutput.rawValue: false,
            Key.disabledApps.rawValue: [String](),
        ])
    }

    var enabled: Bool {
        get { d.bool(forKey: Key.enabled.rawValue) }
        set { d.set(newValue, forKey: Key.enabled.rawValue); notify() }
    }

    var threshold: Int {
        get { max(40, min(1000, d.integer(forKey: Key.threshold.rawValue))) }
        set { d.set(newValue, forKey: Key.threshold.rawValue); notify() }
    }

    var perKey: [String: Int] {
        get { d.dictionary(forKey: Key.perKey.rawValue) as? [String: Int] ?? [:] }
        set { d.set(newValue, forKey: Key.perKey.rawValue); notify() }
    }

    var showMenuBarIcon: Bool {
        get { d.bool(forKey: Key.showMenuBarIcon.rawValue) }
        set { d.set(newValue, forKey: Key.showMenuBarIcon.rawValue); notify() }
    }

    var launchAtLogin: Bool {
        get { d.bool(forKey: Key.launchAtLogin.rawValue) }
        set { d.set(newValue, forKey: Key.launchAtLogin.rawValue) }
    }

    var useOptionOutput: Bool {
        get { d.bool(forKey: Key.useOptionOutput.rawValue) }
        set { d.set(newValue, forKey: Key.useOptionOutput.rawValue); notify() }
    }

    var disabledApps: [String] {
        get { d.stringArray(forKey: Key.disabledApps.rawValue) ?? [] }
        set { d.set(newValue, forKey: Key.disabledApps.rawValue); notify() }
    }

    /// Bir harfin gecerli esigi: ozel deger varsa o, yoksa genel.
    func threshold(for letter: String) -> Int {
        perKey[letter] ?? threshold
    }

    static let changed = Notification.Name("TurkfukSettingsChanged")
    private func notify() {
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }
}
