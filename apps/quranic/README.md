# Quranic

A calm, gold-accented home for the Noble Qur'an, recitation and dhikr.

Quranic is a standalone Flutter app that reuses the Islamic feature from
`apps/suq_client` (reader, recitation player and tasbih) without the shop,
account or subscription layers. The original feature in `suq_client` stays
untouched; this app copies it and rebrands the surfaces.

## Features

- **Mushaf reader** — all 604 pages of the QCF4 mushaf, whole-surah list,
  per-verse translations and tafsir, bookmarks and saved pages.
- **Recitation** — word-by-word highlighting, hundreds of reciters, offline
  downloads and a floating mini player.
- **Tasbih** — 33 / 34 / 99 / 100 presets, haptics and bead sounds.
- **Gold branding** — espresso and brushed-gold palette, gold logo, adaptive
  launcher icon and a dark-gold splash screen.

## Run

```powershell
cd apps/quranic
flutter pub get
flutter run -d windows        # or an Android device/emulator
```

Android application id: `et.quranic.app`.

## Layout

```
quranic/
  assets/
    branding/          gold logo and launcher artwork
    fonts/             AmiriQuran + 604 QCF4 page fonts
    quran/             twelve page-data batches
    sounds/            tasbih bead clicks
  lib/
    core/theme.dart    gold palette and Material 3 theme
    features/islamic/  reader, player, tasbih (copied from suq_client)
    providers.dart     shared preferences provider
    widgets/common.dart
    app.dart           shell, splash and mini player
```
