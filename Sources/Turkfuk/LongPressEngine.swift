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
        var consumed: Bool      // Turkce harf basildi mi
    }

    private var tap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    private var thread: Thread?
    private var pending: Pending?
    private var cfTimer: CFRunLoopTimer?

    /// Onplandaki uygulamanin bundle id'si. Ana is parcaciginda yazilir, tap
    /// parcaciginda okunur; kilitle korunuyor.
    private let frontLock = NSLock()
    private var _frontmost = ""
    var frontmostBundleID: String {
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
                if !p.consumed { postText(plainText(for: p)) }
                pending = nil
                return nil                      // keyDown'i yuttugumuz icin keyUp da yutulur
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

        // Bekleyen harfin otomatik tekrari: yut, zamanlayiciyi beklemeye devam et.
        if let p = pending, code == p.key.keyCode, autorepeat { return nil }
        // Ayni tusun keyUp'siz ikinci basimi (kacan olay): asagidaki genel yol
        // bekleyeni duz haliyle basip yeni bir bekleme baslatir.

        // Baska bir tusa basildi: bekleyen harfi ONCE bas, sonra bu tusu isle.
        // Sirayi garanti altina almak icin yeni tusu gecirmek yerine kopyasini basiyoruz.
        var flushed = false
        if pending != nil {
            flushPending()
            flushed = true
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
        pending = Pending(key: key, uppercase: upper, consumed: false)
        scheduleTimer(ms: Settings.shared.threshold(for: key.ascii))
        return nil
    }

    /// Uzun basim suresi doldu: Turkce harfi bas.
    private func timerFired() {
        guard var p = pending, !p.consumed else { return }
        if Settings.shared.useOptionOutput {
            postOptionKey(p.key.keyCode, uppercase: p.uppercase)
        } else {
            postText(p.uppercase ? p.key.upper : p.key.lower)
        }
        p.consumed = true
        pending = p
    }

    /// Bekleyen harfi duz haliyle bas (tus ustune tus binmesi durumu).
    private func flushPending() {
        cancelTimer()
        guard let p = pending else { return }
        if !p.consumed { postText(plainText(for: p)) }
        pending = nil
    }

    private func plainText(for p: Pending) -> String {
        p.uppercase ? p.key.ascii.uppercased() : p.key.ascii
    }

    private func isActive() -> Bool {
        guard Settings.shared.enabled else { return false }
        let front = frontmostBundleID
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

    /// Klavye duzeninden bagimsiz: harfi dogrudan unicode olarak yollar.
    private func postText(_ text: String) {
        let src = CGEventSource(stateID: .privateState)
        let chars = Array(text.utf16)
        for isDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: isDown) else { continue }
            chars.withUnsafeBufferPointer { buf in
                e.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
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
