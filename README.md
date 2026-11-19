# jet-icons

Design an app icon once, export icon sets for every platform.

jet-icons is a desktop app (plus reusable Dart packages) for building a layered
app icon on a 1024x1024 canvas and generating the platform-specific icon files
from it.

## M1 scope

- Six target platforms: iOS, Android, macOS, Windows, web and Linux.
- Three tabs: **Tasarla** (design), **Platformlar** (per-platform overrides and
  shapes) and **Dışa aktar** (export).
- Export to a zip file or a folder, with the output split into one directory per
  platform (`ios/`, `android/`, `macos/`, `windows/`, `web/`, `linux/`).
- Icons are saved as `.jeticon` files (JSON).

The desktop app targets macOS, Windows and Linux; mobile is planned for a later
milestone.

## Workspace layout

This is a Flutter pub workspace.

- `packages/jet_icons_core` - pure Dart: document model, `.jeticon` codec,
  SVG/PNG import, platform outputs, encoders and the export runner.
- `packages/jet_icons_render` - Flutter: drawing and rasterizing icons.
- `app` - the Flutter desktop app.

## Setup

```sh
flutter pub get
```

## Run

```sh
cd app && flutter run -d macos
```

## Tests

```sh
cd packages/jet_icons_core && dart test
cd packages/jet_icons_render && flutter test
cd app && flutter test
cd app && flutter test integration_test -d macos
```

## Docs

Design specs and implementation plans live in
[`docs/superpowers/specs`](docs/superpowers/specs) and
[`docs/superpowers/plans`](docs/superpowers/plans).

## License

Apache-2.0.
