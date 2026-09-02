import ApplicationServices
import AppKit

enum Permissions {
    /// Olay yakalama (CGEventTap) icin Erisilebilirlik izni sart.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Sistem diyalogunu acar; kullanici izni verene kadar false doner.
    @discardableResult
    static func requestTrust() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func openSettingsPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
