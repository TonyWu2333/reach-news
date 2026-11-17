# Reach News

Reach News is a native two-platform prototype inspired by Ground News. It presents the same core idea: compare coverage across the political spectrum, spot blindspots, and read a story with its sources in context.

## Projects

- `ReachNews/` — SwiftUI iOS app, generated with XcodeGen from `project.yml`.
- `android/` — Kotlin and Jetpack Compose Android app.
- `.github/workflows/build.yml` — builds and tests both platforms on every push and pull request.

The apps use bundled sample stories so the prototype works without an API key or network connection. Search, topic filters, story details, save/bookmark, following topics, collections, and reading history are included.

## Local builds

On macOS with XcodeGen:

```sh
xcodegen generate
xcodebuild test -project ReachNews.xcodeproj -scheme ReachNews \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

On a machine with Android SDK and Java 17:

```sh
cd android
gradle wrapper --gradle-version 8.11.1
./gradlew assembleDebug
```

