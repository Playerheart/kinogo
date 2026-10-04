# 🎬 Кино — личное iOS-приложение

Приложение-обёртка для просмотра `mix.kinogo.mu` на iPhone. Сборка IPA выполняется автоматически через GitHub Actions и публикуется в Releases.

<!-- IPA_INFO_START -->
Информация о последней сборке появится здесь после первого успешного запуска workflow.
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
