# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

FlClashX is a Flutter desktop/Android proxy client forked from FlClash and based on ClashMeta/mihomo. The Flutter app is only one layer of the system: it depends on generated native core artifacts from `core/` and platform glue in `android/`, `linux/`, `macos/`, and `windows/`.

The app supports Android and desktop platforms. Android talks to the Go core through a native shared library loaded by Dart FFI; desktop platforms run `FlClashCore` as a separate process and communicate over a socket. Windows also uses the Rust helper service under `services/helper`.

## Common commands

### Flutter dependencies and code generation

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Generated Riverpod/Freezed/JSON files are redirected by `build.yaml` into:

- `lib/models/generated/`
- `lib/providers/generated/`

### Analysis and formatting

```sh
flutter analyze
dart analyze setup.dart
dart format lib setup.dart
```

The analyzer uses `analysis_options.yaml` with strict lint coverage and excludes generated plugin/l10n/build outputs.

### Tests

There is no top-level `test/` directory currently. If tests are added, use standard Flutter commands:

```sh
flutter test
flutter test test/path/to_test.dart
flutter test test/path/to_test.dart --plain-name 'test name'
```

### Local debug with `flutter run`

Before `flutter run`, prepare the native core artifacts. `libclash/` is generated and ignored by git.

Linux desktop:

```sh
dart setup.dart dev --target linux --print-flutter-run
flutter run -d linux --dart-define=APP_ENV=pre
```

Android:

```sh
dart setup.dart dev --target android --print-flutter-run
flutter run -d <android-device-id> --dart-define=APP_ENV=pre
```

Android + current Linux desktop in parallel:

```sh
dart setup.dart dev --targets android,linux --print-flutter-run
flutter run -d all --dart-define=APP_ENV=pre
```

For clearer logs, prefer two terminals for simultaneous mobile + desktop debugging:

```sh
flutter run -d <android-device-id> --dart-define=APP_ENV=pre
flutter run -d linux --dart-define=APP_ENV=pre
```

Windows requires the SHA printed by the dev command:

```sh
dart setup.dart dev --target windows --print-flutter-run
flutter run -d windows --dart-define=APP_ENV=pre --dart-define=CORE_SHA256=<printed-sha256>
```

macOS uses the prepared core referenced by the Xcode project:

```sh
dart setup.dart dev --target macos --print-flutter-run
flutter run -d macos --dart-define=APP_ENV=pre
```

Linux runtime/build dependencies from README:

```sh
sudo apt-get install libayatana-appindicator3-dev
sudo apt-get install libkeybinder-3.0-dev
```

### Release/package builds

`setup.dart` is the canonical build orchestrator for native core artifacts and packaged app builds.

```sh
dart setup.dart android
dart setup.dart android --arch arm64 --out core
dart setup.dart linux --arch amd64
dart setup.dart macos --arch arm64 --env stable
dart setup.dart windows --arch amd64
```

Makefile shortcuts currently include:

```sh
make android_arm64
make android_app
make android_arm64_core
make macos_arm64
make macos_arm64_core
make macLocal
make macLocal_amd64
make cleanLocal
```

CI release builds are defined in `.github/workflows/build.yaml`; standalone desktop core builds are in `.github/workflows/build-core.yaml`.

## Native core and generated artifacts

- `setup.dart` reads the core version from `core/constant/version.go` and writes `lib/core_version.dart`.
- Go core artifacts are generated under `libclash/<platform>/`.
- Android expects `libclash/android/<abi>/libclash.so` plus generated headers copied into `android/core/src/main/jniLibs` during Gradle `preBuild`.
- Linux installs `libclash/linux/FlClashCore` into the debug/release bundle.
- Windows installs `libclash/windows/FlClashCore.exe` and `FlClashHelperService.exe`.
- macOS references `libclash/macos/FlClashCore`; `macos/Runner/AppDelegate.swift` copies it into Application Support and adjusts permissions.

If a native artifact is missing, run the corresponding `dart setup.dart dev --target ...` command instead of editing platform build files around the failure.

## High-level architecture

### Flutter entry and app lifecycle

- `lib/main.dart` initializes Flutter bindings, preloads `clashCore`, initializes `globalState`, Android/window plugins, and starts `Application` inside a Riverpod `ProviderScope`.
- The same file defines the Android background service entrypoint `_service`, which handles VPN/tile service events and communicates with the native core isolate.
- `lib/application.dart` builds the Material app and composes platform/runtime manager widgets. Desktop wraps the app with window, tray, hotkey, and proxy managers; Android wraps it with Android, tile, and VPN managers.
- `lib/controller.dart` is the main app orchestration layer for profiles, Clash config application, proxy changes, foreground notification state, auto updates, and core restart/status flows.
- `lib/state.dart` contains the `GlobalState` singleton. It stores persisted config, runtime app state, global notifiers, compile-time env (`APP_ENV`, `CORE_VERSION`, `CORE_SHA256`), and start/stop task handling.

### State management and models

- Riverpod providers live under `lib/providers/`; generated provider files live under `lib/providers/generated/`.
- Persistent user/config state is exposed mainly through `lib/providers/config.dart`, where provider updates write back into `globalState.config`.
- Runtime state such as logs, requests, traffic, providers, local IP, and view size is exposed through `lib/providers/app.dart` and writes back into `globalState.appState`.
- Freezed/JSON model source files live under `lib/models/`; generated files live under `lib/models/generated/`.

### Clash core integration

- `lib/clash/core.dart` is the high-level Dart facade used by the app. It selects the platform-specific implementation and exposes operations such as init, config setup/update, proxy changes, traffic, logs, providers, and listener lifecycle.
- `lib/clash/lib.dart` is the Android FFI path. It opens `libclash.so`, bridges to generated FFI bindings in `lib/clash/generated/clash_ffi.dart`, and coordinates the service isolate through ports.
- `lib/clash/service.dart` is the desktop process path. It starts `FlClashCore` from `appPath.corePath`, communicates via a Unix socket or localhost port, and uses the Windows helper when available/admin.
- `lib/common/path.dart` defines platform paths for data, profiles, core executable, helper executable, and temporary/download directories.

### Platform plugins and native layers

- `lib/plugins/` contains Dart wrappers for platform channels such as Android app functions, VPN, tile service, and desktop service interactions.
- `plugins/proxy` and `plugins/window_ext` are local Flutter plugins used by the main app.
- `android/core/` contains the Android native core module that packages JNI libraries generated into `libclash/android`.
- `core/` contains the Go/mihomo-based native core and Dart bridge sources.
- `services/helper/` contains the Rust helper service used on Windows.

### UI structure

- `lib/pages/` contains top-level pages such as home, editor, scanner, and send-to-TV.
- `lib/views/` contains feature views for dashboard, profiles, proxies, config, connections, tools, logs, theme, hotkeys, and settings.
- `lib/widgets/` contains reusable UI components.
- Localization source ARB files are under `arb/`; generated localization output is under `lib/l10n/`.

## Product-specific behavior from README

The app parses custom subscription headers that affect dashboard/proxy layout and provider-controlled settings. Relevant header families documented in README include:

- `flclashx-widgets`
- `flclashx-view`
- `flclashx-custom`
- `flclashx-denywidgets`
- `flclashx-servicename`
- `flclashx-servicelogo`
- `flclashx-serverinfo`
- `flclashx-background`
- `flclashx-settings`

Android external actions documented in README:

```text
com.follow.clashx.action.START
com.follow.clashx.action.STOP
com.follow.clashx.action.CHANGE
```

When changing profile parsing, dashboard widgets, proxy views, foreground notifications, or provider override behavior, check README/README_EN for the documented header contract.
