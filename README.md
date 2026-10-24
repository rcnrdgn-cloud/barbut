# Barbut

İki kişilik barbut zar oyunu. Zar atışı telefonda ses ve titreşimle hissedilir; telefonu kupa gibi sallayarak da zar atılabilir.

## Telefona yükleme (Android)

1. Bu depoya her `main` gönderiminde **Actions** sekmesinde “Uygulamayı derle” çalışır (yaklaşık 6–10 dakika).
2. Biten çalışmanın sayfasında en altta **barbut-android** dosyası çıkar. İndir, zip’i aç, içindeki `app-release.apk` dosyasını telefona at.
3. Telefonda dosyaya dokun. “Bilinmeyen kaynaklardan yükleme” izni sorarsa izin ver.

## Nasıl hissettiriyor

| An | Ses | Titreşim |
|---|---|---|
| Atış başlar | Def vuruşu, sarnıç uğultusu | Tek güçlü darbe |
| Kupada çalkalama | Kemik zar tıkırtıları | Kısa, düzensiz tıklar |
| Tepsiye düşüş | 5 sekme, giderek hafifler | Güçlüden zayıfa 5 darbe |
| Barbut (kazanç) | Hicaz çan arpeji | Üç darbe |
| Kaybettiren atış | Gong + inen ney | Uzun, ağır titreşim |
| Sonuçsuz | Kısa ney nefesi | Hafif dokunuş |

Sallayarak atışta kupa kısmını zaten elinde hissettiğin için atlanır; zar, sallamayı bıraktığın an tepsiye düşer.

## Klasörler

- `lib/game.dart` — kurallar ve akçe hesabı
- `lib/feel.dart` — ses + titreşim zaman çizelgesi
- `lib/shake.dart` — sallama algılama
- `lib/die.dart` — zar çizimi ve atış animasyonu
- `assets/sounds/` — sesler (`tool/make_sounds.py` ile sıfırdan üretildi)

`android/` ve `ios/` klasörleri depoda tutulmuyor; GitHub Actions her derlemede `flutter create` ile üretiyor.

## Sonraki adımlar

- Çevrimiçi iki oyuncu (sunucu gerekir, ör. Firebase)
- iPhone’a yükleme (Apple Developer hesabı ve imzalama gerekir)
