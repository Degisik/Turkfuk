import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Kisayol: sanal tus kodu + degistirici maskesi.
struct Hotkey: Equatable {
    var keyCode: Int64
    var flags: Int          // 1=⌘ 2=⌃ 4=⌥ 8=⇧

    static let cmd = 1, ctrl = 2, opt = 4, shift = 8

    static func mask(from f: CGEventFlags) -> Int {
        var b = 0
        if f.contains(.maskCommand)   { b |= cmd }
        if f.contains(.maskControl)   { b |= ctrl }
        if f.contains(.maskAlternate) { b |= opt }
        if f.contains(.maskShift)     { b |= shift }
        return b
    }

    /// Apple'in gosterim sirasi: ⌃ ⌥ ⇧ ⌘
    var display: String {
        var s = ""
        if flags & Hotkey.ctrl  != 0 { s += "⌃" }
        if flags & Hotkey.opt   != 0 { s += "⌥" }
        if flags & Hotkey.shift != 0 { s += "⇧" }
        if flags & Hotkey.cmd   != 0 { s += "⌘" }
        return s + KeyNames.name(for: keyCode)
    }
}

enum KeyNames {
    /// Harf uretmeyen tuslarin adlari.
    private static let ozel: [Int64: String] = [
        49: "Boşluk", 36: "↩", 48: "⇥", 53: "Esc", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// Tus kodunu aktif klavye duzenine gore harfe cevirir.
    static func name(for keyCode: Int64) -> String {
        if let s = ozel[keyCode] { return s }
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
        else { return "#\(keyCode)" }

        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let ok = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            guard let base = raw.baseAddress else { return false }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDown), 0,
                                  UInt32(LMGetKbdType()), 0, &deadState,
                                  4, &length, &chars) == noErr
        }
        guard ok, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
