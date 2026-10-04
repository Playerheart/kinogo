# 🎬 Кино — личное iOS-приложение

Приложение-обёртка для просмотра `mix.kinogo.mu` на iPhone. Сборка IPA выполняется автоматически через GitHub Actions и публикуется в Releases.

<!-- IPA_INFO_START -->
## 📥 Последняя сборка

| Параметр | Значение |
|---|---|
| **Версия** | `1.0` |
| **Номер сборки** | `#43` |
| **Дата** | 04.10.2026 17:28 UTC |
| **Скачать IPA** | [**CinemaApp.ipa** ⬇](https://github.com/Playerheart/kinogo/releases/download/v1.0-build.43/CinemaApp.ipa) |
| **Страница релиза** | [Открыть](https://github.com/Playerheart/kinogo/releases/tag/v1.0-build.43) |

> Прямая ссылка на файл — https://github.com/Playerheart/kinogo/releases/download/v1.0-build.43/CinemaApp.ipa
>
> Если она не открывается, перейдите в раздел [Releases](https://github.com/Playerheart/kinogo/releases) и выберите последнюю сборку вручную.
<!-- IPA_INFO_END -->

---

## 🚀 Как запустить сборку

1. Откройте вкладку **Actions** в репозитории.
2. Слева выберите workflow **Build Unsigned IPA**.
3. Нажмите **Run workflow** → **Run workflow** (ветка `main`).
4. Через 5–15 минут появится релиз, а эта страница обновится автоматически.

## 📲 Как установить

1. Скачайте `CinemaApp.ipa` по ссылке выше (на iPhone удобнее через Safari).
2. Подпишите файл на устройстве (TrollStore / ESign / Scarlet / SignTools).
3. Установите приложение.

## 🔧 Как изменить сайт

Откройте `CinemaApp/ContentView.swift` и замените строку:

```swift
private let targetURL = URL(string: "https://mix.kinogo.mu")!
