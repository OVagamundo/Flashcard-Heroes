# Android Porting & Mobile Notes

Status: Active reference

This document records the Android-specific work already done for Flashcard Heroes and the non-obvious constraints discovered during the first mobile port. It is meant to prevent repeating setup mistakes and to isolate the current unresolved mobile-only issues.

## 1. Toolchain & Export Baseline

- Engine target: Godot `4.6.1`
- Android preset: `Android`
- Current APK output path: `build/android/flashcard-heroes-debug.apk`
- Current package ID: `com.danhh.flashcardheroes`

### Required local setup

- Matching Godot export templates for the exact engine version.
- A valid JDK 17 install configured in Godot Editor Settings.
- A valid Android SDK install configured in Godot Editor Settings.
- A debug export is sufficient for local device testing. A connected phone is **not** required to build the APK; it is only required for `adb install`, `adb logcat`, and direct launch/debugging.

### Current project-side Android requirements

- [project.godot](../project.godot) uses `debug/file_logging/log_path="user://log.txt"`.
  - This avoids the previous desktop-only absolute path problem that broke Android startup.
- [project.godot](../project.godot) enables `rendering/textures/vram_compression/import_etc2_astc=true`.
  - This is required for Android export warnings to clear and for texture compression support to match the Android target.

## 2. Exported Resource Gotchas

Desktop and Android do **not** expose project resources the same way at runtime.

### What broke on Android

- Translations initially failed and UI showed raw keys such as `ui.start_run`.
- Loadout hero data initially failed to populate.

### Actual cause

- Android/exported builds do not behave like a loose desktop project folder.
- Translation loading must use exported `.translation` resources, not the raw CSV file.
- Runtime directory scans must accept exported `.remap` entries (`.tres.remap`, `.res.remap`) and load the original resource path.

### Current implementation

- [Database.gd](../scripts/Database.gd)
  - Loads `res://localization/game.en.translation` and `res://localization/game.pt_BR.translation`
  - Accepts `.tres`, `.res`, `.tres.remap`, and `.res.remap` during definition scans
  - Sorts hero definitions by `id` to keep loadout ordering deterministic across desktop and Android
- [StatusEffectRegistry.gd](../scripts/StatusEffectRegistry.gd)
  - Accepts `.tres`, `.res`, `.tres.remap`, and `.res.remap`

### Troubleshooting rule

If Android shows untranslated keys, missing heroes, or partially empty registries, check the following **before** changing gameplay code:

1. [Database.gd](../scripts/Database.gd)
2. [StatusEffectRegistry.gd](../scripts/StatusEffectRegistry.gd)
3. [export_presets.cfg](../export_presets.cfg)

## 3. Mobile Input Model

Touch input was adapted to preserve the desktop interaction model as closely as possible without letting mobile behavior leak back into mouse/desktop paths.

### Shared touch adapter

- [InputUtils.gd](../scripts/InputUtils.gd)
  - `prefers_touch_input()` is the single gate for touch-first behavior
  - `TOUCH_LONG_PRESS_SEC = 0.32`
  - `TOUCH_DRAG_THRESHOLD_PX = 24.0`

### GachaBall interactions

- [GachaBallView.gd](../scripts/GachaBallView.gd)
  - Touch press starts a long-press timer
  - Long-press temporarily emulates hover-inspect
  - Moving more than the drag threshold cancels the long-press peek
  - Releasing after a long-press closes the temporary inspection instead of triggering a tap
- [PhysicsGachaBall.gd](../scripts/PhysicsGachaBall.gd)
  - Mirrors the same touch-first long-press inspect behavior for the physics inventory/discard representations

### Window/background event handling

Touch events now explicitly consume the primary press in the relevant window/background handlers so Android taps do not immediately fall through into global-close behavior.

Key files:

- [Main.gd](../scripts/Main.gd)
- [InventoryWindow.gd](../scripts/InventoryWindow.gd)
- [BackgroundBlocker.gd](../scripts/BackgroundBlocker.gd)
- [DiscardPileWindow.gd](../scripts/DiscardPileWindow.gd)

### Desktop parity rule

Touch adaptations must remain gated behind [InputUtils.gd](../scripts/InputUtils.gd). Desktop mouse behavior is expected to remain unchanged unless a change is explicitly intended for both platforms.

## 4. Discard Pile Mobile-Specific Work

The discard pile needed Android-specific alignment work because its mobile rendering/physics alignment did not initially match desktop behavior.

### Current implementation

- [DiscardPileWindow.gd](../scripts/DiscardPileWindow.gd)
  - Uses runtime bounds on touch devices
  - Caches valid discard instances
  - Re-syncs physics only when the drawer is in a valid visible/open state
  - Refreshes runtime bounds after the open animation completes
- [PhysicsTierContainer.gd](../scripts/PhysicsTierContainer.gd)
  - Provides runtime-generated bounds and exported spawn/bound parameters
  - Supports `.clear()`, sequential spawning, and out-of-bounds recovery
- [WindowManager.gd](../scripts/WindowManager.gd)
  - Keeps the persistent discard pile window alive rather than rebuilding it every open/close

### Important outcome

Discard pile persistence must be preserved. Closing the drawer should not destroy and recreate all balls by default.

## 5. Known Open Android Issue

The mobile-only run-inventory glow mismatch is still unresolved.

### Facts confirmed so far

- The capsule texture is shared:
  - [gachaballcapsule.png](../assets/ui/textures/gachaballcapsule.png)
- The glow pass is shared:
  - [color_glow_post_process.gdshader](../assets/shaders/color_glow_post_process.gdshader)
  - [Main.tscn](../scenes/Main.tscn)
- Run and battle inventories are rendered inside the same persistent [InventoryWindow.tscn](../scenes/InventoryWindow.tscn) window on the same modal canvas.
- The discrepancy appears only on Android, not desktop.
- The discrepancy is between:
  - Run inventory grid path: [StaggeredGridContainer.gd](../scripts/StaggeredGridContainer.gd) + [GachaBallView.gd](../scripts/GachaBallView.gd)
  - Battle inventory path: [PhysicsTierContainer.gd](../scripts/PhysicsTierContainer.gd) + [PhysicsGachaBall.gd](../scripts/PhysicsGachaBall.gd)

### Failed lead already tested

- Pixel-snapping the staggered grid child positions in [StaggeredGridContainer.gd](../scripts/StaggeredGridContainer.gd) did **not** resolve the Android glow mismatch.

### Do not re-investigate from scratch

The following have already been ruled out as the primary cause:

- Missing Android export resources
- Duplicate top-level glow passes
- Wrong capsule asset file
- Desktop selection logic accidentally selecting every run-inventory ball

Resume the investigation from the render-path difference between the run `Control` tree and the battle physics `Sprite2D` tree.
