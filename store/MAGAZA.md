# Siber — Mağaza yayın rehberi

Bu dosya App Store Connect ve Google Play Console'daki formlara ne cevap verileceğini toplar.
Cevaplar uygulamanın gerçekte yaptığıyla birebir uyumlu olmalı; uymazsa inceleme reddedilir.

## Ortak bilgiler

| Alan | Değer |
| --- | --- |
| Uygulama adı | Siber |
| Paket / Bundle ID | `com.davuttam.siber` |
| Sürüm | `pubspec.yaml` → `version` (her yüklemede `+` sonrası yapı numarasını artır) |
| Kategori | Oyunlar → Aksiyon (Arcade) |
| Gizlilik politikası | `https://siber-oyun-ilf4c.web.app/gizlilik` (`public/gizlilik.html`, Firebase Hosting) |
| Destek / iletişim | `S.contactEmail` (`lib/core/i18n.dart`) — mağazadaki adresle aynı olmalı |
| Reklam | Yok |
| Uygulama içi satın alma | Yok |
| Hesap / giriş | Yok (sıralama için arka planda anonim Firebase kimliği) |

## Derleme

```bash
flutter build ipa --release
```

```bash
flutter build appbundle --release
```

- iOS: `build/ios/ipa/*.ipa` dosyasını Transporter ya da Xcode Organizer ile yükle.
- Android: `build/app/outputs/bundle/release/app-release.aab` dosyasını Play Console'a yükle.
- Android imza anahtarı: `~/.android-keys/siber-upload.jks`, şifresi `android/key.properties` içinde.
  **İkisini de güvenli bir yere yedekle** (ör. parola yöneticisi). Kaybolursa güncelleme yüklemek için Google'dan anahtar sıfırlama istemen gerekir.
  Yükleme sertifikası SHA-256: `66:B7:F7:02:B7:29:1B:58:A2:0E:10:CF:DF:5B:36:0B:3A:0A:E1:13:FC:AE:0E:7C:85:2A:D1:AF:A3:EA:30:E6`
- Play App Signing'i açık bırak (varsayılan).

## App Store Connect

### Uygulama gizliliği (App Privacy)

"Veri topluyor musunuz?" → **Evet**. İzleme (tracking) → **Hayır**, hiçbir veri türünde.

| Veri türü | Amaç | Kullanıcıya bağlı | İzleme |
| --- | --- | --- | --- |
| Tanımlayıcılar → Kullanıcı Kimliği (anonim Firebase kimliği) | Uygulama İşlevselliği | Evet | Hayır |
| Kullanıcı İçeriği → Oyun İçeriği (takma ad, skor, dalga, düşürülen) | Uygulama İşlevselliği | Evet | Hayır |

Konum, kişiler, e-posta, reklam kimliği, tanılama/analitik: **toplanmıyor**.

### Yaş sınıflandırması

- Çizgi film / fantastik şiddet: **Seyrek / hafif** (soyut gemiler ve patlamalar, kan yok)
- Kullanıcı tarafından oluşturulan içerik: **Evet** (herkese açık takma adlar)
- Mesajlaşma / sohbet: Hayır · Kumar: Hayır · Reklam: Hayır
- Beklenen sonuç: 9+

### Şifreleme (Export Compliance)

`Info.plist` içinde `ITSAppUsesNonExemptEncryption = false` var; soru sorulmaz.

### İnceleme notu (App Review Information → Notes)

> Siber is a single-player arcade shooter. No login is required.
> The world leaderboard uses anonymous Firebase Authentication; players only choose a nickname.
> Offensive nicknames are blocked on entry and masked on the leaderboard.
> Tap any other player on the leaderboard to report the name or hide the player (Guideline 1.2).
> Settings → "Delete my scores from the leaderboard" removes the online entry and the anonymous account (Guideline 5.1.1(v)).
> Settings → "Privacy" shows the privacy policy in the app.

Giriş bilgisi gerekmiyor: "Sign-in required" kutusunu boş bırak.

### Ekran görüntüleri

- iPhone 6.9" (1320×2868) — zorunlu
- iPad 13" (2064×2752) — uygulama iPad'i de desteklediği için zorunlu
- Öneri: ana ekran, oyun içi (patlamalar), ana gemi savaşı, sıralama, tema seçimi

## Google Play Console

### Veri güvenliği (Data safety)

- Veri topluyor mu: **Evet** · Paylaşıyor mu: **Hayır**
- Aktarımda şifreleniyor: **Evet** (HTTPS) · Kullanıcı silme isteyebilir: **Evet** (uygulama içinden)

| Kategori → Tür | Toplanıyor | Amaç | Zorunlu mu |
| --- | --- | --- | --- |
| Kişisel bilgiler → Kullanıcı kimlikleri (anonim kimlik) | Evet | Uygulama işlevselliği | Zorunlu (sıralama için) |
| Uygulama etkinliği → Diğer kullanıcı içeriği (takma ad) | Evet | Uygulama işlevselliği | Zorunlu |
| Uygulama etkinliği → Diğer işlemler (skor, dalga) | Evet | Uygulama işlevselliği | Zorunlu |

Konum, kişiler, finans, sağlık, mesajlar, fotoğraf, ses, dosya, takvim, cihaz kimliği: **Hayır**.

### Diğer formlar

- **İçerik derecelendirmesi (IARC)**: Kategori "Oyun". Şiddet: fantastik/soyut, kan yok. "Kullanıcılar etkileşime giriyor mu / içerik paylaşıyor mu": **Evet** (herkese açık takma adlar). Beklenen sonuç: PEGI 7 / Everyone 10+.
- **Hedef kitle**: **13 ve üzeri**. 13 altını seçme; Aileler politikası ek şartlar getirir.
- **Reklam içeriyor mu**: Hayır.
- **Uygulama erişimi**: Tüm işlevler kısıtlama olmadan kullanılabilir (giriş yok).
- **Haber uygulaması / COVID / finans / sağlık**: Hayır.
- İzinler: yalnızca `INTERNET` ve `ACCESS_NETWORK_STATE` (çalışma anında izin sorulmaz).

### Görseller

- Uygulama simgesi 512×512: `store/play-icon-512.png`
- Öne çıkan grafik 1024×500: `store/play-feature-graphic.png`
- Telefon ekran görüntüleri: en az 2 adet (9:16)

### Yeni geliştirici hesabı uyarısı

Kişisel Play geliştirici hesabı Kasım 2023'ten sonra açıldıysa üretime çıkmadan önce
**en az 12 test kullanıcısıyla 14 gün kesintisiz kapalı test** zorunludur. Önce "Kapalı test" kanalına yükle.

## Yayından önce son kontrol

- [ ] `S.contactEmail` ve mağazalardaki destek e-postası aynı
- [ ] Gizlilik sayfası adresi tarayıcıda açılıyor
- [ ] `pubspec.yaml` yapı numarası bir önceki yüklemeden büyük
- [ ] Gerçek cihazda: açılış, oyun, ses, sıralama, şikâyet/gizle, veri silme denendi
- [ ] Firebase kuralları güncel: `firebase deploy --only database`
- [ ] Şikâyetler Firebase konsolunda `raporlar/` altında; uygunsuz kaydı `skorlar/<kimlik>` silerek kaldır
