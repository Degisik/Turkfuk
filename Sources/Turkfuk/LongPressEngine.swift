import AppKit
import CoreGraphics

/// Kendi urettigimiz olaylari isaretlemek icin. Isaret dusse bile sonsuz donguye
/// girmeyiz: unicode olaylarini sanal tus 0 ile basiyoruz, o da izlenen harflerde degil.
private let kTurkfukMagic: Int64 = 0x54524B46   // "TRKF"

private func turkfukTapCallback(proxy: CGEventTapProxy,
                                type: CGEventType,
                                event: CGEvent,
                                refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<LongPressEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handle(type: type, event: event)
}

final class LongPressEngine {
    static let shared = LongPressEngine()

    /// Uzun basim durumunu bekleyen tus.
    private struct Pending {
        let key: TurkishKey
        let uppercase: Bool
        var consumed: Bool          // Turkce harf basildi mi
        var passedThrough: Bool     // gercek olaylar uygulamaya ulasti mi
    }

    private var tap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    private var thread: Thread?
    private var pending: Pending?
    private var cfTimer: CFRunLoopTimer?

    /// Onplandaki uygulama. Ana is parcaciginda yazilir, tap parcaciginda okunur.
    /// Turkfuk'un kendisi hic yazilmaz: menu acildiginda onplandaki uygulamanin
    /// kimligi kaybolmasin diye.
    private let frontLock = NSLock()
    private var _frontmost = (bundleID: "", ad: "")

    var onplandaki: (bundleID: String, ad: String) {
        get { frontLock.lock(); defer { frontLock.unlock() }; return _frontmost }
        set { frontLock.lock(); _frontmost = newValue; frontLock.unlock() }
    }

    private(set) var isRunning = false

    /// Kisayol kaydi: ana is parcaciginda kurulur, tap parcaciginda okunur.
    private let recLock = NSLock()
    private var recorder: ((Hotkey?) -> Void)?

    func beginHotkeyRecording(_ done: @escaping (Hotkey?) -> Void) {
        recLock.lock(); recorder = done; recLock.unlock()
    }

    func endHotkeyRecording() {
        recLock.lock(); recorder = nil; recLock.unlock()
    }

    private func takeRecorder() -> ((Hotkey?) -> Void)? {
        recLock.lock(); defer { recLock.unlock() }
        let r = recorder; recorder = nil; return r
    }

    private var isRecording: Bool {
        recLock.lock(); defer { recLock.unlock() }; return recorder != nil
    }

    // MARK: - Yasam dongusu

    func start() {
        guard thread == nil else { return }
        let t = Thread { [weak self] in self?.threadMain() }
        t.name = "com.degisik.turkfuk.tap"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let rl = tapRunLoop { CFRunLoopStop(rl) }
        tap = nil; tapRunLoop = nil; thread = nil; isRunning = false
    }

    private func threadMain() {
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: turkfukTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            NSLog("Turkfuk: olay yakalayıcı kurulamadı — Erişilebilirlik izni yok.")
            return
        }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let rl = CFRunLoopGetCurrent()
        self.tapRunLoop = rl
        CFRunLoopAddSource(rl, src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        CFRunLoopRun()
    }

    // MARK: - Olay isleme (yalnizca tap parcaciginda calisir)

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Sistem yakalayiciyi askiya aldiysa geri ac.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }
        // Kendi urettigimiz olaylar dokunulmadan gecer.
        if event.getIntegerValueField(.eventSourceUserData) == kTurkfukMagic {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let code = event.getIntegerValueField(.keyboardEventKeycode)

        // Kisayol kaydi acikken tuslar uygulamaya gitmez, kombinasyon yakalanir.
        if isRecording {
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            if code == 53 {                                  // Esc — vazgec
                takeRecorder()?(nil)
            } else if Hotkey.mask(from: flags) != 0 {         // en az bir degistirici sart
                takeRecorder()?(Hotkey(keyCode: code, flags: Hotkey.mask(from: flags)))
            }
            return nil
        }

        if type == .flagsChanged {
            // ⌘/⌃/⌥ devreye girdiyse bekleyen harfi hemen bas.
            if flags.contains(.maskCommand) || flags.contains(.maskControl)
                || flags.contains(.maskAlternate) { flushPending() }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp {
            if let p = pending, code == p.key.keyCode {
                cancelTimer()
                pending = nil
                // Uygulama gercek keyDown'lari gorduyse keyUp'i da gormeli,
                // yoksa tus sonsuza kadar basili sanilir.
                if p.passedThrough { return Unmanaged.passUnretained(event) }
                if !p.consumed { postPlain(p) }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Ac/kapat kisayolu. Tam eslesme araniyor ki ustune Shift eklenince tetiklenmesin.
        if let hk = Settings.shared.hotkey,
           code == hk.keyCode, Hotkey.mask(from: flags) == hk.flags {
            flushPending()
            DispatchQueue.main.async { Settings.shared.enabled.toggle() }
            return nil
        }

        let autorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        // Bekleyen harfin otomatik tekrari.
        if let p = pending, code == p.key.keyCode, autorepeat {
            // Esik dolmadan tekrar olmaz: hangi harf oldugu henuz belli degil.
            guard p.consumed else { return nil }
            switch Settings.shared.repeatLetter {
            case .orijinal:
                // Gercek olay gecer: hem orijinal harf tekrarlar hem de tusun
                // basili oldugu uygulamaya surekli yeniden bildirilir.
                pending?.passedThrough = true
                return Unmanaged.passUnretained(event)
            case .turkce:
                postKey(keyCode: p.key.keyCode, uppercase: p.uppercase,
                        text: p.uppercase ? p.key.upper : p.key.lower, downOnly: true)
                return nil
            }
        }
        // Ayni tusun keyUp'siz ikinci basimi (kacan olay): asagidaki genel yol
        // bekleyeni duz haliyle basip yeni bir bekleme baslatir.

        // Baska bir tusa basildi: bekleyen harfi ONCE bas, sonra bu tusu isle.
        // Sirayi garanti altina almak icin yeni tusu gecirmek yerine kopyasini basiyoruz.
        var flushed = false
        if pending != nil {
            let beklet = Settings.shared.mechanism != .anlik
            flushPending()
            flushed = beklet
        }

        guard isActive(), let key = TurkishKeys.byKeyCode[code], isPlainOrShift(flags) else {
            if flushed, let copy = event.copy() {
                copy.setIntegerValueField(.eventSourceUserData, value: kTurkfukMagic)
                copy.post(tap: .cgSessionEventTap)
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        let upper = flags.contains(.maskShift) != flags.contains(.maskAlphaShift)
        pending = Pending(key: key, uppercase: upper, consumed: false,
                          passedThrough: Settings.shared.mechanism == .anlik)
        scheduleTimer(ms: Settings.shared.threshold(for: key.ascii))

        // Anlik modda olay bastirilmaz: tus gercekten basili kalir, bu yuzden
        // oyunlar tusun tutuldugunu gorur. Bedeli, esikte harfin silinip
        // yerine Turkcesinin yazilmasi — yani gorunur bir titreme.
        return Settings.shared.mechanism == .anlik ? Unmanaged.passUnretained(event) : nil
    }

    /// Uzun basim suresi doldu: Turkce harfi bas.
    private func timerFired() {
        guard var p = pending, !p.consumed else { return }
        if Settings.shared.mechanism == .anlik {
            // Harf zaten yazildi: geri al, sonra Turkcesini koy. Yerine koyarken
            // SADECE keyDown gonderiliyor — sahte bir keyUp, tusu hala basili
            // tutan oyuna "biraktin" der ve karakteri durdururdu.
            postBackspace()
            postKey(keyCode: p.key.keyCode, uppercase: p.uppercase,
                    text: p.uppercase ? p.key.upper : p.key.lower, downOnly: true)
        } else if Settings.shared.useOptionOutput {
            postOptionKey(p.key.keyCode, uppercase: p.uppercase)
        } else {
            postTurkish(p)
        }
        p.consumed = true
        pending = p
    }

    /// Bekleyen harfi duz haliyle bas (tus ustune tus binmesi durumu).
    private func flushPending() {
        cancelTimer()
        guard let p = pending else { return }
        // Anlik modda harf zaten cikmisti, telafi gerekmiyor.
        if Settings.shared.mechanism != .anlik, !p.consumed { postPlain(p) }
        pending = nil
    }

    private func isActive() -> Bool {
        guard Settings.shared.enabled else { return false }
        let front = onplandaki.bundleID
        return front.isEmpty || !Settings.shared.disabledApps.contains(front)
    }

    /// Yalnizca sade tus ya da Shift/CapsLock ile basilmissa devreye gir.
    private func isPlainOrShift(_ f: CGEventFlags) -> Bool {
        !f.contains(.maskCommand) && !f.contains(.maskControl)
            && !f.contains(.maskAlternate) && !f.contains(.maskSecondaryFn)
    }

    // MARK: - Zamanlayici (tap parcaciginin run loop'unda)

    private func scheduleTimer(ms: Int) {
        cancelTimer()
        guard let rl = tapRunLoop else { return }
        let fire = CFAbsoluteTimeGetCurrent() + Double(ms) / 1000.0
        let t = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fire, 0, 0, 0) { [weak self] _ in
            self?.timerFired()
        }
        cfTimer = t
        CFRunLoopAddTimer(rl, t, .commonModes)
    }

    private func cancelTimer() {
        if let t = cfTimer { CFRunLoopTimerInvalidate(t) }
        cfTimer = nil
    }

    // MARK: - Harf basma

    /// Duz harf: basilan tusun kendisi gonderilir, karakteri sistem duzenden turetir.
    private func postPlain(_ p: Pending) {
        postKey(keyCode: p.key.keyCode, uppercase: p.uppercase, text: nil)
    }

    /// Turkce harf: ayni tus kodu, karakter unicode olarak ekleniyor.
    private func postTurkish(_ p: Pending) {
        postKey(keyCode: p.key.keyCode, uppercase: p.uppercase,
                text: p.uppercase ? p.key.upper : p.key.lower)
    }

    /// Tus kodu HER ZAMAN basilan harfin gercek kodu olmali. Sabit 0 kullanmak
    /// (ANSI'de "a" tusu) metin alanlarinda fark ettirmez ama tus kodunu okuyan
    /// her uygulamaya — oyunlar, tus atama ekranlari — yanlis tus bildirir.
    private func postBackspace() {
        postKey(keyCode: 51, uppercase: false, text: nil)   // kVK_Delete
    }

    private func postKey(keyCode: Int64, uppercase: Bool, text: String?, downOnly: Bool = false) {
        let src = CGEventSource(stateID: .privateState)
        let flags: CGEventFlags = uppercase ? [.maskShift] : []
        for isDown in (downOnly ? [true] : [true, false]) {
            guard let e = CGEvent(keyboardEventSource: src,
                                  virtualKey: CGKeyCode(keyCode), keyDown: isDown) else { continue }
            e.flags = flags
            if let text {
                let chars = Array(text.utf16)
                chars.withUnsafeBufferPointer { buf in
                    e.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
                }
            }
            e.setIntegerValueField(.eventSourceUserData, value: kTurkfukMagic)
            e.post(tap: .cgSessionEventTap)
        }
    }

    /// Yedek yol: ⌥<tus> simule eder. Klavye duzeni Turkce harfi ⌥ katmaninda
    /// tasiyorsa calisir (Turkish Q – Legacy gibi).
    private func postOptionKey(_ keyCode: Int64, uppercase: Bool) {
        let src = CGEventSource(stateID: .privateState)
        var flags: CGEventFlags = [.maskAlternate]
        if uppercase { flags.insert(.maskShift) }
        for isDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src,
                                  virtualKey: CGKeyCode(keyCode), keyDown: isDown) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: kTurkfukMagic)
            e.post(tap: .cgSessionEventTap)
        }
    }
}
