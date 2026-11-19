# jet-icons M1 — Follow-ups

Items found by per-task and whole-branch reviews during M1 that were deliberately deferred (none blocks M1). Already fixed in the final fix wave: non-finite numbers in `.jeticon`, unsaved-changes prompt on Open, zip `.zip` overwrite confirm, stale assets after Open, ICNS `icp6`, README.

## Product / behavior
- **SVG `fill-rule="evenodd"`** imports as raw (non-editable) SVG. Add `fillRule` to `PathElement` + painter support — many real logos use it.
- SVG allowlist sends `enable-background`, `overflow`, `shape-rendering`, `stroke-dashoffset`, `class`, `color=currentColor` to raw (safe, but more raw imports than necessary).
- Overrides scoped to a size range other than the selected one are not listed in the Platforms tab — they affect exports while invisible. Add a list/indicator.
- Platform-wide (variant=null) iOS background patch also fills the dark variant (only reachable via hand-edited files; UI writes variant-specific iOS overrides). Decide and document the rule.
- Window-close guard for unsaved changes.
- Save is not atomic; Save As does not append `.jeticon`.
- Android adaptive background *elements* are scaled by 72/108 (fill is not) → border visible during launcher parallax.
- Hidden layer: fill editor / scale slider show the resolved (empty) value while a patch may exist.
- `revealFolder` errors unhandled; not verified under macOS sandbox.
- Drag on empty canvas moves the selected element (unspecified).
- Codec: `shapes` keys other than windows/linux/web are dropped on save; `formatVersion <= 0` accepted; duplicate element ids in hand-edited files are not validated.

## Performance
- Export decodes every raster/SVG again per render (~67 renders) and runs `stripAlpha`/zip on the UI isolate — cache `PreparedAssets` per export, use `Isolate.run`.
- Path `d` re-parsed on every paint; `shouldRepaint` deep-compares `ResolvedIcon`.

## Robustness
- Rasterizer: assets not disposed if `paint` throws; codec leak on image decode error.
- `elementBounds` bare catch → `Rect.zero` (element becomes unselectable silently).
- Canvas `_side` 0 guard.

## Test gaps
- Pixel tests: radial gradient, 0/1-stop gradients, group opacity.
- Export runner: per-variant resolution, zip roundtrip content for all entries, text outputs carry encoder content.
- Output tables: shape `none` for Windows/Web, macOS file names.
- Export tab: bundle reuse on overwrite, progress/busy state.
- Design/Platforms: preview request details, asset-load failure path, detach before/after full equality.

## Not yet verified manually
- Drop generated `ios/AppIcon.appiconset` into an Xcode project (no warnings).
- Copy `android/res` into an Android project and run `./gradlew assembleDebug`.
- Open `windows/app_icon.ico` in Windows Explorer.
