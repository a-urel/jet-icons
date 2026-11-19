# jet-icons — Tasarım Dokümanı

Tarih: 2026-11-19 · Durum: Taslak (onay bekliyor)

## 1. Amaç ve neden

Uygulama geliştiricileri ikonlarını **bir kez tasarlayıp** tüm hedef platformların istediği app icon dosyalarını tek seferde üretebilmeli. Bugün bu iş ya her platform için ayrı ayrı elle yapılıyor ya da tek platformlu / yalnızca CLI / web tabanlı sınırlı araçlarla (flutter_launcher_icons, IconKitchen, appicon.co, Apple Icon Composer) parça parça çözülüyor. Hiçbiri tüm platformları katman mantığıyla, canlı önizlemeyle ve projeye doğrudan yazarak birlikte sunmuyor.

Hedef kullanıcı: **uygulama geliştiricisi**, illüstratör değil. Tipik ihtiyacı "renkli arka plan + sembol/logo + belki harf", tüm platformlarda doğru görünsün.

Proje açık kaynak (Apache 2.0).

## 2. Hedefler

- Tek ortak tasarımdan iOS, Android, macOS, Windows, Web/PWA ve Linux için doğru app icon setleri üretmek.
- Her platformun nasıl göreceğini (maskeler, güvenli bölge, açık/koyu/tint, küçük boyutlar) tasarlarken canlı göstermek.
- İsteğe bağlı platforma özgü özelleştirme (override): ortak tasarımın üstüne platform bazında farklılıklar.
- Hem elindeki logoyu getirmeyi (SVG/PNG) hem de araç içinde kompozisyon kurmayı desteklemek.
- Çıktıyı zip/klasör olarak vermek veya doğrudan geliştiricinin projesine yazmak.

## 3. Hedef dışı (bu sürümde yok)

- Store ekran görüntüsü üretimi (gelecekte düşünülebilir).
- Tam vektör editör: kalem aracı, bezier düğüm düzenleme, boolean işlemler (sonra; mimari engellememeli).
- CLI (sonra; mimari hazırlamalı).
- watchOS, tvOS, visionOS çıktıları (sonra).
- iOS 26 Liquid Glass katmanlı `.icon` paketi (v1 sonrası öncelikli iş; iOS 26 düz ikonu kabul etmeye devam ediyor).
- Mobilde projeye doğrudan yazma.

## 4. Anti-hedefler (çalışsa bile başarısızlık sayılır)

- Store'ların veya IDE'lerin reddettiği / uyarı verdiği çıktı (yanlış boyut, şeffaflık olmaması gereken yerde şeffaflık, eksik asset).
- Geliştiricinin proje dosyalarını **sessizce** ezmek veya bozmak.
- Kullanıcıyı tasarımcı olmaya zorlamak; basit bir ikon dakikalar içinde çıkmalı.
- Kapalı/ikili proje formatı; tasarım dosyası git'te okunabilir ve diff alınabilir olmalı.
- Kendi tasarım modelimizin tam SVG desteğini ileride imkânsız kılması.

## 5. Kısıtlar

- UI: Flutter (repo Flutter'a göre başlatılmış). Tek kod tabanı: macOS, Windows, Linux, iOS, Android.
- Lisans: Apache 2.0; kullanılacak ikon kütüphaneleri ve fontlar açık lisanslı ve dağıtılabilir olmalı.

## 6. Yaklaşımlar

| | Yaklaşım | Artı | Eksi |
|---|---|---|---|
| **A (seçildi)** | Tamamen Dart/Flutter. Çekirdek Dart paket(ler)i; render/dışa aktarma `dart:ui` ile. | Tek dil/toolchain, hızlı ilerleme, tuval ile çıktı aynı motordan, katkı kolay. | Gelecekteki CLI Flutter engine'i taşır; SVG desteği kendi model dönüşümümüzle sınırlı. |
| B | Flutter UI + Rust çekirdek (resvg/usvg/tiny-skia, flutter_rust_bridge). | Çok yüksek SVG uyumluluğu, küçük bağımsız CLI. | İki dil, 6 platform için Rust cross-compile, tuval (Flutter) ile önizleme (Rust) arasında piksel farkı riski. |
| Elendi | Electron/Tauri (web) | — | Repo Flutter; mobil zayıf. |
| Elendi | Platform başına native | — | Multi-platform hedefiyle çelişir. |

**Seçim: A.** Kullanıcı koşulu: **gelecekte tam SVG desteği dışlanmamalı.** Bu, mimaride iki uzatma noktasıyla karşılanır (bkz. §8.3).

## 7. Ürün kararları

### 7.1 İkon modeli (çekirdek kavram)

Bir ikon projesi şunlardan oluşur:

- **Arka plan katmanı**: düz renk, gradyan veya görsel. Tam kare, opak.
- **Ön plan katmanı**: bir veya daha fazla öğe (şekil, metin, ikon kütüphanesi sembolü, içe aktarılmış SVG/PNG). Şeffaf zemin.
- **Monokrom katman**: tek renkli siluet (Android themed icon, iOS tinted). Varsayılan olarak ön plandan türetilir (alfa → tek renk), istenirse ayrı içerik verilebilir.
- **Varyantlar**: iOS açık / koyu / tinted. Koyu varyant varsayılan olarak türetilir (arka plan şeffaf/koyu), override edilebilir.
- **Platform override'ları**: her platform için ortak tasarımın üstüne yazılan ayarlar (ör. macOS'ta ek kenar boşluğu, Android'de farklı arka plan, Windows küçük boyutlarda sadeleştirilmiş ön plan). Override yoksa ortak tasarım kullanılır. Kurallar (kullanıcı kararı):
  - **Varsayılan: özellik yaması.** Override yalnızca değişen özellikleri tutar (kenar boşluğu, dolgu, renk, ölçek, bir öğenin gizlenmesi vb.). Ortak tasarımdaki sonraki düzenlemeler, yamalanmamış özellikler üzerinden platforma akmaya devam eder.
  - **İsteğe bağlı: katman ayırma.** Kullanıcı tek bir katmanı (arka plan, ön plan veya monokrom) bir platform için "kopyalayıp ayırabilir"; o katman artık ortak tasarımı takip etmez. UI bunu açıkça gösterir ve "ortak tasarıma geri bağla" seçeneği sunar.
  - **Anahtar: platform + isteğe bağlı boyut aralığı.** Override bir platforma, isteğe bağlı olarak da o platformun bir çıktı boyutu aralığına (ör. Windows 16–32 px) bağlanır. Çözümleme sırası: ortak tasarım → platform override'ı → boyut aralığı override'ı.
- **Şekil (maskesiz platformlar)**: sistemin maske uygulamadığı platformlarda çıktının şeklini araç verir (kullanıcı kararı):
  - **macOS**: varsayılan olarak Apple macOS ikon şablonu otomatik uygulanır — yuvarlatılmış gövde, kenar boşluğu, gölge.
  - **Windows, Linux, favicon**: platform başına "şekil" ayarı — yuvarlatılmış kare (varsayılan) / tam kare / daire / arka plansız (yalnızca ön plan, şeffaf zemin).
  - iOS, Android ve PWA maskable için şekli sistem verir; araç tam kare opak çıktı üretir.

Platform çıktıları bu modelden **türetilir**; kullanıcı platform dosyalarıyla doğrudan uğraşmaz.

### 7.2 Editör kapsamı (v1)

- **İçe aktarma**: SVG (vektör olarak korunur, desteklenen alt küme modele çevrilir — bkz. §8.3) ve PNG (raster öğe; hedef boyutlar için çözünürlük yetersizse uyarı).
- **Kompozisyon araçları**: hazır şekiller (daire, yuvarlatılmış kare, çokgen, yıldız), metin/monogram, dolgu (düz/doğrusal/radyal gradyan), gölge, kenarlık, açık lisanslı ikon kütüphanesi (ör. Material Symbols, Lucide), katman taşıma/döndürme/ölçekleme/hizalama, geri al/yinele.
- **Metin** *(tasarımcı kararı)*: canlı metin olarak saklanır; yalnızca uygulamayla paketlenen açık lisanslı fontlar kullanılır (böylece `.jeticon` her makinede aynı çizilir). "Path'e çevir" seçeneği vardır. Kullanıcının kendi fontunu getirmesi sonraya kaldı.
- **Veri modeli baştan vektör** (path tabanlı); kalem aracı ve boolean işlemler ileride mimariyi kırmadan eklenebilmeli.

### 7.3 Proje dosyası

- Uzantı: `.jeticon`. Okunabilir metin formatı: JSON; SVG'ler metin olarak gömülü, PNG'ler base64 veya yanındaki dosyaya referans (builder'a bırakıldı, bkz. §11).
- Format sürümlü (`formatVersion`), ileri uyumluluk için bilinmeyen alanlar korunur.
- Repo'ya commit edilmesi ve diff alınması amaçlanır.

### 7.4 Arayüz (masaüstü)

Üç sekme (seçilen yerleşim: "klasik araç + adım sekmeleri" karışımı):

```
[ 1 · Tasarla ]  [ 2 · Platformlar ]  [ 3 · Dışa aktar ]
┌─────────┬──────────────────────┬──────────┐
│ Araçlar │                      │Özellikler│
│Katmanlar│        TUVAL         │          │
├─────────┴──────────────────────┴──────────┤
│ canlı önizleme şeridi: iOS·Android·macOS·Win·Web·Linux │
└───────────────────────────────────────────┘
```

1. **Tasarla**: ortak tasarım. Sol: araçlar + katmanlar; orta: tuval; sağ: seçili öğenin özellikleri; alt: tüm platformların küçük canlı önizleme şeridi. Tuvalde Android güvenli bölge ve macOS ikon ızgarası kılavuz olarak açılıp kapatılabilir.
2. **Platformlar**: her platform büyük önizleme — Android maske şekilleri (daire, squircle, yuvarlatılmış kare vb.) ve güvenli bölge; iOS açık/koyu/tinted; macOS gövde + gölge; Windows 16/24/32/48/256 px; Web maskable; Linux. Platform override'ları burada yapılır.
3. **Dışa aktar**: hedef platform seçimi, mod seçimi (zip/klasör veya proje klasörü), yazılacak/üzerine yazılacak dosyaların önizlemesi, onay.

### 7.5 Mobil sürümün rolü (masaüstü öncelikli, mobil yardımcı)

- Sekmeler alt navigasyona dönüşür; Tasarla sekmesi sadeleşir (hafif düzenleme).
- **Cihazda dene**: ikonu gerçek ana ekran benzeri bir görünümde (kullanıcının seçtiği duvar kâğıdı üstünde, gerçek boyutta) gösterir.
- `.jeticon` açma/paylaşma (dosya sistemi, paylaşım menüsü, iCloud/Drive gibi sistem dosya sağlayıcıları).
- Zip olarak dışa aktarma var; projeye doğrudan yazma yok.

### 7.6 Hedef platformlar ve çıktılar (v1)

| Platform | Çıktı |
|---|---|
| iOS | `AppIcon.appiconset`: 1024×1024 tek boyut (universal), açık + koyu + tinted varyantları, `Contents.json`. Açık varyant opak olmalı. |
| Android | Adaptive icon: `mipmap-anydpi-v26/ic_launcher.xml` (+ `ic_launcher_round.xml`) içinde `background`, `foreground`, `monochrome`; yoğunluk başına ön/arka plan PNG'leri (108dp: mdpi–xxxhdpi); eski cihazlar için `ic_launcher.png` / `ic_launcher_round.png` (48dp); Play Store 512×512. |
| macOS | `AppIcon.appiconset` (16–512 @1x/@2x, `Contents.json`) ve Xcode dışı kullanım için `.icns`. Apple macOS ikon ızgarasına uygun gövde + kenar boşluğu. |
| Windows | `.ico` (16, 24, 32, 48, 64, 128, 256). |
| Web/PWA | `favicon.ico`, `icon-192.png`, `icon-512.png`, maskable 192/512, `apple-touch-icon.png` (180), manifest `icons` girdileri. |
| Linux | PNG seti (16–512, hicolor tema boyutları). |

Kesin dosya adları, boyut listeleri ve `Contents.json` şemaları builder tarafından güncel platform dokümantasyonuyla doğrulanmalı; yukarıdaki liste niyeti tanımlar.

### 7.7 Dışa aktarma modları

1. **Zip / klasör**: seçilen platformların çıktısı platform klasörlerine ayrılmış hâlde.
2. **Projeye doğrudan yazma** (yalnızca masaüstü): kullanıcı proje kök klasörünü seçer; araç proje tipini tanır ve dosyaları doğru yerlere yazar:
   - **Flutter projesi** (`pubspec.yaml` + `ios/`, `android/`, `macos/`, `windows/`, `web/`, `linux/` alt klasörleri; hangisi varsa).
   - **Native iOS/macOS** (`.xcodeproj` → `Assets.xcassets/AppIcon.appiconset`).
   - **Native Android** (`app/src/main/res`, `AndroidManifest.xml`).
   - Yazmadan önce: değişecek dosyaların listesi (yeni / üzerine yazılacak / silinecek), açık onay, üzerine yazılan dosyaların yedeği. Manifest/Contents.json gibi dosyalara yalnızca gerekli minimum değişiklik.
   - Tanınmayan proje → zip/klasör moduna yönlendirme.
   - **Birden fazla aday hedef** *(tasarımcı kararı)*: flavor'lar (`src/<flavor>/res`), birden fazla Xcode target/asset catalog, monorepo içinde birden fazla uygulama veya manifest'in `ic_launcher` dışında bir ikon adına işaret etmesi durumunda araç bulduğu adayları listeler, kullanıcı hangilerine yazılacağını seçer (varsayılan: ana/main hedef seçili). Manifest'in işaret ettiği mevcut ikon adı korunur.
   - **Dosya erişimi** *(tasarımcı kararı)*: araç yalnızca kullanıcının dosya seçiciyle verdiği klasör içinde okur/yazar (yedekler dahil). Bu, sandbox'lı dağıtım kanallarıyla (Mac App Store security-scoped bookmark, Flatpak portal, MSIX) uyumludur. Dağıtım kanalı seçimi bu tasarımın dışında; sonra kararlaştırılacak.

## 8. Mimari

### 8.1 Paket yapısı (monorepo)

- **`jet_icons_core`** — saf Dart (Flutter bağımlılığı yok): ikon modeli, `.jeticon` serileştirme, platform spesifikasyonları (boyutlar, güvenli bölgeler, maskeler, dosya adları), override çözümleme, dosya kodlayıcılar (`.ico`, `.icns`, `Contents.json`, adaptive icon XML, web manifest), proje tanıma ve proje yazıcıları (PNG byte'ları alır, dosya sistemine yazar), SVG içe aktarıcı (SVG → model).
- **`jet_icons_render`** — Flutter: modeli `dart:ui` ile çizen ve PNG'ye pikselleştiren `IconRasterizer` uygulaması. Tuval, önizleme ve dışa aktarma aynı çizim kodunu kullanır.
- **`app`** — Flutter uygulaması (masaüstü + mobil UI).

`core`'un Flutter'dan bağımsız olması, ileride CLI'ın veya alternatif bir render motorunun (ör. resvg tabanlı) aynı modeli ve yazıcıları kullanabilmesini sağlar.

### 8.2 Akış

```
Kullanıcı düzenlemesi → İkon modeli (core)
   → Override çözümleme (platform başına efektif model)
   → IconRasterizer (render) → PNG byte'ları (her boyut/varyant)
   → Kodlayıcılar (core) → .ico/.icns/Contents.json/XML
   → Zip yazıcı | Proje yazıcı (core)
```

### 8.3 Tam SVG desteğini açık tutma (kullanıcı koşulu)

- **SVG içe aktarıcı arayüzü**: v1, desteklenen alt kümeyi (path, temel şekiller, düz/gradyan dolgu, stroke, transform, group, opacity) düzenlenebilir model öğelerine çevirir.
- **Ham SVG öğesi**: alt kümeye uymayan SVG'ler reddedilmez; ham SVG metni olarak saklanıp bir SVG render kütüphanesiyle (ör. `vector_graphics`/`flutter_svg`) bütün hâlinde çizilir (taşınabilir/ölçeklenebilir, iç düzenleme yok). Kullanıcıya hangi öğelerin düzenlenemeyeceği gösterilir.
- **Değiştirilebilir rasterizer**: `IconRasterizer` bir arayüz; ileride tam SVG uyumlu bir motor (ör. resvg FFI) takılabilir.

## 9. Teslim sırası (v1 içi kilometre taşları — kullanıcı kararı)

1. **M1 — Çekirdek + içe aktarma + tüm çıktılar**: ikon modeli, `.jeticon`, SVG/PNG içe aktarma, override ve şekil çözümleme, render, altı platformun tüm çıktıları, zip/klasör dışa aktarma; masaüstü UI'nin bunları kullanan asgari hâli (Tasarla tuvalinde yerleştirme/ölçekleme, Platformlar, Dışa aktar). "Logo getir → her yere ikon al" çalışır.
2. **M2 — Projeye doğrudan yazma**: proje tanıma (Flutter, native iOS/macOS, native Android), aday hedef seçimi, değişiklik önizlemesi, yedek, yazma. §10'daki "5 dakikada projeye yaz" ölçütü burada karşılanır.
3. **M3 — Kompozisyon araçları**: şekiller, metin/monogram, gradyan, gölge, kenarlık, ikon kütüphanesi.
4. **M4 — Mobil yardımcı**: mobil UI, "Cihazda dene", `.jeticon` paylaşma, zip dışa aktarma.

## 10. Başarı ölçütleri

- Yeni bir kullanıcı, elindeki SVG logodan 5 dakikadan kısa sürede tüm platform ikonlarını bir Flutter projesine yazabiliyor.
- Üretilen çıktılar Xcode, Android Studio/Gradle, Windows build ve PWA manifest doğrulamasından uyarısız geçiyor.
- `.jeticon` dosyası git diff'inde anlamlı ve okunabilir.

## 11. Builder'a bırakılanlar

- Flutter state management, routing ve klasör düzeni.
- `.jeticon` içinde PNG'lerin gömülmesi (base64) ya da yan dosya referansı.
- İkon kütüphanelerinin seçimi ve paketlenme şekli (lisansa uygun olmak şartıyla).
- Varsayılan Android maske önizleme seti ve macOS ızgarasının kesin ölçüleri (güncel Apple/Google dokümantasyonuna göre).
- Linux çıktısının Flutter Linux projesinde nereye yazılacağı (standart yeri yok; makul bir varsayılan + dokümantasyon).
- Test stratejisi (özellikle çekirdek kodlayıcılar ve proje yazıcıları için golden/fixture testleri önerilir).
