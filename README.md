# Turkfuk

**Turkish Keylayout for US Keylayouts**

ANSI/US klavyede Türkçe harfleri yazmanın en kısa yolu: harfe basılı tut, Türkçesi çıksın.

```
i → ı      s → ş      g → ğ
c → ç      o → ö      u → ü
```

Shift ile basılı tutarsan büyükleri gelir: `İ Ş Ğ Ç Ö Ü`

## Neden

MacBook'un ANSI klavyesinde Türkçe harfler yok. Klavye düzenini Türkçe Q'ya çevirmek
noktalama ve parantezleri de kaydırıyor, bu da kod yazarken can sıkıcı. Turkfuk düzeni
hiç değiştirmeden sadece altı harfe uzun basım ekler.

## Nasıl çalışıyor

Bir `CGEventTap` ile tuşlar dinlenir. Bir harfe basıldığında olay tutulur:

- **Eşikten önce bırakırsan** → normal harf basılır.
- **Eşik dolana kadar tutarsan** → Türkçe harf basılır.
- **Bırakmadan başka tuşa basarsan** → bekleyen harf anında basılır, sonra yeni tuş.

Son madde önemli. Uzun basım kuralı yazan çoğu çözüm bu durumda harfi düşürür ve hızlı
yazarken harf kaybedersin. Turkfuk bekleyen harfi düşürmez; sıranın bozulmaması için yeni
tuşu geçirmek yerine işaretli bir kopyasını kendisi basar.

Harfler `CGEventKeyboardSetUnicodeString` ile doğrudan unicode olarak basılır, `⌥` tuşu
simüle edilmez. Bu yüzden **klavye düzeninden bağımsız** çalışır — düz US düzeninde de,
Türkçe Q Legacy'de de. (Düzeni `⌥` katmanında Türkçe harf taşıyanlar için yedek bir
`⌥` simülasyon modu da var.)

## Kurulum

```bash
git clone https://github.com/Degisik/Turkfuk.git
cd Turkfuk
./install.sh
```

Kurulum sırasında iki şey sorulur: sistem açılışında otomatik başlasın mı, menü çubuğuna
simge eklensin mi. Karabiner-Elements'te aynı işi yapan bir kural varsa onu da tespit edip
kaldırmayı önerir.

Kurulduktan sonra **Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik** altında
Turkfuk'a izin vermen gerekir. Bu izin olmadan tuşlar yakalanamaz.

Kaldırmak için: `./uninstall.sh`

## Ayarlar

Menü çubuğu simgesinden:

| Ayar | Ne yapar |
|---|---|
| Aç / Kapat | Uzun basımı devre dışı bırakır |
| Kısayol | Aç/kapat kısayolunu değiştirir veya kaldırır (varsayılan `⌃⌥⌘T`) |
| Genel eşik | Bütün harfler için taban süre (80–300 ms, ya da özel değer) |
| Harf eşikleri | Her harfe ayrı süre. Parmağın uzun kaldığı harfte yükselt |
| Girişte başlat | `SMAppService` ile oturum açılışına ekler |

Harf eşikleri neden var: her parmağın tuşta kalma süresi aynı değil. Sol orta parmakla
basılan `c` genelde `i`'den uzun kalır; genel eşiği düşük tutup yalnızca `c`'yi
yükselterek ikisini ayrı ayarlayabilirsin.

Menü çubuğu simgesini kapattıysan geri açmak için:

```bash
defaults write com.degisik.turkfuk showMenuBarIcon -bool true
```

## Derleme

Xcode gerekmez, Command Line Tools yeter.

```bash
./build.sh             # yerel mimari
./build.sh universal   # arm64 + x86_64
```

Çıktı: `dist/Turkfuk.app`

## Gereksinimler

macOS 13 veya üstü · Erişilebilirlik izni

## Lisans

MIT
