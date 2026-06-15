# m3u-tv Guidelines

**Stack**: Flutter (Dart), targeting Android TV and tvOS.
**Platforms**: Android TV, Apple TV (tvOS).

## Project location

All source lives under `flutter_client/`. Run every command from that directory.

## Context

This is the TV frontend for the `m3u-editor` system. It focuses on video playback (Live TV/VOD) and EPG (Electronic Program Guide) rendering. The app is D-pad driven — no touch input assumed on TV targets.

## Architecture

- **Navigation**: `dpad` package v3 (Shortcuts + Actions based spatial traversal) + `Navigator` for in-content routing.
- **State**: `ChangeNotifier` / `ListenableBuilder` via `AppStateController`.
- **Player**: `video_player` / platform player via `PlaybackOrchestrator`.
- **UI**: Material 3, `DpadFocusable` for all interactive items, `DpadRegion` for focus grouping.

## Rules

### TV Interaction
1. **D-Pad Focus**: Every interactive element must be wrapped in `DpadFocusable`.
2. **Border effects**: Use `DpadBorderEffect(borderRadius: …)` matching the widget's own corner radius. Pill/stadium widgets use `circular(50)`. Cards use `circular(8)`.
3. **Edge navigation**: Leaf `DpadRegion`s use `horizontalEdge: DpadEdgeBehavior.stop` + `onEdge` to activate the sidebar on left-edge press.
4. **Back handling**: Handled globally in `AppShell` via `Shortcuts` mapping Escape / GoBack → `_BackIntent`.

### Style
- Material 3 throughout. No `OutlinedButton` — use `FilledButton`, `FilledButton.tonal`, `FilledButton.icon`, or `FilledButton.tonalIcon`.
- Match existing file conventions. No new comments unless the WHY is non-obvious.

### Commands
- **Analyze**: `cd flutter_client && flutter analyze`
- **Test**: `cd flutter_client && flutter test`
- **Run (Android TV)**: `cd flutter_client && flutter run -d <device-id>`
