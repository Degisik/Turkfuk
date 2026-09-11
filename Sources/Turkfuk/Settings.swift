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
        case hotkeyKeyCode    = "hotkeyKeyCode"
        case hotkeyFlags      = "hotkeyFlags"
        case hotkeyEnabled    = "hotkeyEnabled"
        case mechanism        = "mechanism"         // "beklet" | "anlik"
        case repeatLetter     = "repeatLetter"      // "orijinal" | "turkce"
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
            Key.hotkeyKeyCode.rawValue: 17,                                   // t
            Key.hotkeyFlags.rawValue: Hotkey.cmd | Hotkey.ctrl | Hotkey.opt,  // ⌃⌥⌘
            Key.hotkeyEnabled.rawValue: true,
            Key.mechanism.rawValue: Mechanism.anlik.rawValue,
            Key.repeatLetter.rawValue: RepeatLetter.orijinal.rawValue,
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

    /// nil verilirse harf genel esige doner.
    func setThreshold(_ ms: Int?, for letter: String) {
        var m = perKey
        if let ms { m[letter] = max(40, min(1000, ms)) } else { m.removeValue(forKey: letter) }
        perKey = m
    }

    /// Uzun basimin tusu nasil ele aldigi.
    enum Mechanism: String {
        /// Tus bastirilir, harf birakista ya da esikte cikar. Titreme yok,
        /// ama uygulama tusun basili kaldigini hic gormez — oyunlar calismaz.
        case beklet
        /// Tus dogrudan gecirilir, harf aninda cikar; esikte geri silinip
        /// Turkcesi yazilir. Tus gercekten basili kalir, oyunlar calisir.
        case anlik
    }

    var mechanism: Mechanism {
        get { Mechanism(rawValue: d.string(forKey: Key.mechanism.rawValue) ?? "") ?? .anlik }
        set { d.set(newValue.rawValue, forKey: Key.mechanism.rawValue); notify() }
    }

    /// Turkce harf yazildiktan sonra tus hala basiliysa ne tekrarlanacak.
    enum RepeatLetter: String {
        /// Orijinal harf (s s s). Klavyenin normal davranisi; oyunlarda tusun
        /// basili kaldigini surekli yeniden bildirdigi icin hareket kesilmez.
        case orijinal
        /// Turkce harf (ş ş ş).
        case turkce
    }

    var repeatLetter: RepeatLetter {
        get { RepeatLetter(rawValue: d.string(forKey: Key.repeatLetter.rawValue) ?? "") ?? .orijinal }
        set { d.set(newValue.rawValue, forKey: Key.repeatLetter.rawValue); notify() }
    }

    /// Ac/kapat kisayolu. Kapaliysa nil.
    var hotkey: Hotkey? {
        guard d.bool(forKey: Key.hotkeyEnabled.rawValue) else { return nil }
        return Hotkey(keyCode: Int64(d.integer(forKey: Key.hotkeyKeyCode.rawValue)),
                      flags: d.integer(forKey: Key.hotkeyFlags.rawValue))
    }

    func setHotkey(_ hk: Hotkey?) {
        if let hk {
            d.set(Int(hk.keyCode), forKey: Key.hotkeyKeyCode.rawValue)
            d.set(hk.flags, forKey: Key.hotkeyFlags.rawValue)
            d.set(true, forKey: Key.hotkeyEnabled.rawValue)
        } else {
            d.set(false, forKey: Key.hotkeyEnabled.rawValue)
        }
        notify()
    }

    static let changed = Notification.Name("TurkfukSettingsChanged")
    private func notify() {
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }
}
