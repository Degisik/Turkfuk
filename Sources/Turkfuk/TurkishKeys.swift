import Foundation

/// Uzun basimla uretilen alti Turkce harf ve ANSI sanal tus kodlari.
struct TurkishKey {
    let keyCode: Int64
    let ascii: String       // kisa dokunusta cikan harf
    let lower: String       // uzun basimda cikan kucuk harf
    let upper: String       // uzun basim + shift

    /// ⌥ simulasyon modunda kullanilacak tus (Turkish Q – Legacy duzeninde ⌥<tus>).
    var optionKeyCode: Int64 { keyCode }
}

enum TurkishKeys {
    /// ANSI sanal tus kodlari (kCGKeyboard...): a=0, s=1, c=8, g=5, o=31, u=32, i=34
    static let all: [TurkishKey] = [
        TurkishKey(keyCode: 34, ascii: "i", lower: "ı", upper: "İ"),
        TurkishKey(keyCode: 1,  ascii: "s", lower: "ş", upper: "Ş"),
        TurkishKey(keyCode: 5,  ascii: "g", lower: "ğ", upper: "Ğ"),
        TurkishKey(keyCode: 8,  ascii: "c", lower: "ç", upper: "Ç"),
        TurkishKey(keyCode: 31, ascii: "o", lower: "ö", upper: "Ö"),
        TurkishKey(keyCode: 32, ascii: "u", lower: "ü", upper: "Ü"),
    ]

    static let byKeyCode: [Int64: TurkishKey] = {
        var m = [Int64: TurkishKey]()
        for k in all { m[k.keyCode] = k }
        return m
    }()
}
