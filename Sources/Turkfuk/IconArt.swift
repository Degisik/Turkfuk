import AppKit

/// Uygulamanin gorsel kimligi: "Tü" hecesi + metin imleci (I-beam).
/// Ayni cizim hem menu cubugu simgesinde hem uygulama simgesinde kullaniliyor,
/// boylece ikisi hicbir zaman birbirinden ayrilmiyor.
enum IconArt {

    private static let hece = "Tü" as NSString

    private static func nitelikler(boyut: CGFloat, renk: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: boyut, weight: .semibold), .foregroundColor: renk]
    }

    /// Verilen yukseklikte glifin dogal genisligi.
    static func dogalBoyut(yukseklik H: CGFloat) -> NSSize {
        let ts = hece.size(withAttributes: nitelikler(boyut: H * 0.72, renk: .black))
        return NSSize(width: ts.width + H * 0.20 + H * 0.36, height: H)
    }

    /// "Tü" + I-beam. Cerceve icine ortalanir.
    static func glifCiz(_ rect: NSRect, renk: NSColor) {
        let H = rect.height
        let attrs = nitelikler(boyut: H * 0.72, renk: renk)
        let ts = hece.size(withAttributes: attrs)

        let bosluk = H * 0.20
        let ibGenislik = H * 0.36
        let toplam = ts.width + bosluk + ibGenislik
        let x0 = rect.minX + (rect.width - toplam) / 2

        hece.draw(at: NSPoint(x: x0, y: rect.minY + (H - ts.height) / 2), withAttributes: attrs)

        // Metin imleci: dikey cizgi + ust/alt seri.
        let cx = x0 + ts.width + bosluk + ibGenislik / 2
        let kalinlik = max(1, H * 0.10)
        let ust = rect.minY + H * 0.90
        let alt = rect.minY + H * 0.10
        renk.setFill()
        NSRect(x: cx - kalinlik / 2, y: alt, width: kalinlik, height: ust - alt).fill()
        NSRect(x: cx - ibGenislik / 2, y: ust - kalinlik, width: ibGenislik, height: kalinlik).fill()
        NSRect(x: cx - ibGenislik / 2, y: alt, width: ibGenislik, height: kalinlik).fill()
    }

    /// Menu cubugu icin sablon resim — rengi sistem belirler, koyu/acik temaya uyar.
    static func menuCubuguSimgesi(yukseklik: CGFloat = 15) -> NSImage {
        let boyut = dogalBoyut(yukseklik: yukseklik)
        let img = NSImage(size: boyut, flipped: false) { rect in
            glifCiz(rect, renk: .black)
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Uygulama simgesi: yuvarlatilmis kare zemin + beyaz glif.
    static func uygulamaSimgesiCiz(_ rect: NSRect) {
        let s = rect.width
        let zemin = rect.insetBy(dx: s * 0.085, dy: s * 0.085)
        let yol = NSBezierPath(roundedRect: zemin, xRadius: s * 0.2237, yRadius: s * 0.2237)
        NSGradient(colors: [NSColor(srgbRed: 0.91, green: 0.27, blue: 0.23, alpha: 1),
                            NSColor(srgbRed: 0.64, green: 0.08, blue: 0.15, alpha: 1)])?
            .draw(in: yol, angle: -90)

        let gy = s * 0.42
        let gb = dogalBoyut(yukseklik: gy)
        glifCiz(NSRect(x: zemin.midX - gb.width / 2, y: zemin.midY - gy / 2,
                       width: gb.width, height: gy), renk: .white)
    }

    // MARK: - Derleme zamani uretim

    /// build.sh bunu `Turkfuk --write-iconset <dizin>` ile cagirir; iconutil .icns'e cevirir.
    static func iconsetYaz(_ dizin: URL) throws {
        try FileManager.default.createDirectory(at: dizin, withIntermediateDirectories: true)
        for temel in [16, 32, 128, 256, 512] {
            try pngYaz(piksel: temel, dizin.appendingPathComponent("icon_\(temel)x\(temel).png"))
            try pngYaz(piksel: temel * 2, dizin.appendingPathComponent("icon_\(temel)x\(temel)@2x.png"))
        }
    }

    private static func pngYaz(piksel: Int, _ url: URL) throws {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: piksel, pixelsHigh: piksel,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { throw CocoaError(.fileWriteUnknown) }

        rep.size = NSSize(width: piksel, height: piksel)   // 1 birim = 1 piksel
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        uygulamaSimgesiCiz(NSRect(x: 0, y: 0, width: piksel, height: piksel))
        NSGraphicsContext.restoreGraphicsState()

        guard let veri = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try veri.write(to: url)
    }
}
