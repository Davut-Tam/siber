# Siber

Neon bir gökyüzünde geçen, çift çubuklu bir uzay savaşı oyunu. Flutter ile yazıldı; iOS, Android ve web'de çalışır. abell_pro'daki Siber mini oyununun genişletilmiş, bağımsız sürümüdür.

## Oyun

- **Uçak:** vektörle çizilmiş jet; dönüşlerde kanat yatışı, iki motordan art yakıcı alevi, namlu alevi.
- **Kontrol:** ekranın sol yarısı hareket, sağ yarısı nişan ve ateş (parmağın değdiği yerde açılan yüzen çubuklar). Klavyede WASD/oklar hareket, fare nişan ve ateş, boşluk bomba, P/Esc duraklat.
- **Güçler:** çift ateş, yelpaze atış, hızlı ateş, güdümlü füze (süreli, üst üste binebilir); kalkan (3 darbe), +1 bomba, +1 can.
- **Bomba:** uçaktan yayılan şok dalgası ekrandaki düşmanlara ağır hasar verir, düşman mermilerini siler.
- **Düşmanlar:** avcı dron, zikzak, tank (üçlü atış), nişancı (lazerle nişan alır), bölünen hücre (üç küçük drona ayrılır), kamikaze (gerilip atılır) ve her 5 dalgada üç evreli ana gemi.
- **Puan:** dalga sistemi, dalga bonusu, art arda vuruşlarda x8'e kadar kombo çarpanı.
- **Efektler:** ekran sarsıntısı, patlama parçacıkları ve şok halkaları, ağır çekim anları, paralaks yıldızlar, neon ızgara, sesler ve titreşim.
- **Temalar:** Neon, Synthwave, Matris, Lav, Altın, Buz (açık).
- **Dil:** Türkçe ve İngilizce (ilk açılışta cihaz diline göre).
- **Sıralama:** takma adla; şimdilik bu cihazdaki skorlar. Firebase ile dünya sıralaması eklenecek (`lib/services/scores.dart` içindeki `ScoreService` arayüzü).

## Çalıştırma

```bash
flutter pub get
flutter test                 # oyun motoru ve çizim testleri
flutter run                  # simülatör, telefon ya da tarayıcı (-d chrome)
flutter run --release        # telefonda kalıcı kurulum
```

## Yapı

```
lib/
  core/       temalar, Türkçe/İngilizce metinler, tercihler, ses ve titreşim
  game/       oyun motoru (engine), varlıklar, çizim (painter), sanal çubuklar
  services/   skor ve sıralama
  ui/         ana sayfa, oyun ekranı ve göstergeler, sıralama, ortak parçalar
tool/make_sounds.py   ses efektlerini sentezler (assets/sounds)
```

Oyun motoru saniyede 60 sabit adımla ilerler ve ekrandan bağımsızdır; arayüz yalnızca okur. Bu sayede `test/engine_test.dart` oyunu ekran olmadan baştan sona oynatabilir.

Lisanslar: Exo 2 ve Orbitron yazı tipleri SIL OFL (`assets/fonts/OFL-*.txt`). Orbitron'da Türkçe harfler olmadığından yalnızca rakamlarda kullanılır.
