---
name: create-ui-vfx
description: Authors UI animations, visual effects, shaders, projectiles, and BattleAnimation presentation components with strict node-bound tweening and puppet-safe contracts.
---

# Creating UI Animations & Visual Effects (VFX)

This skill guides the implementation of tactile UI polish, juice, card animations, custom shaders, and battle visual cues without violating puppet-mode separation or breaking deterministic replays.

## 1. Bound Tween Lifecycle (Zero Dangling Tweens)
- Always bind Tweens directly to the node being animated:
  ```gdscript
  var tween: Tween = create_tween()
  ```
- **Banned**: `get_tree().create_tween()` causes crashes if the animated node is freed mid-tween and leaks `CanvasItem` RIDs on game exit.
- Set tween behavior via chaining: `tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)`.

## 2. Speed Scaling (Single-Scaling Rule)
- Scale animation durations using `AnimationConstants.scaled(duration)` exactly once:
  ```gdscript
  var dur: float = AnimationConstants.scaled(0.3)
  tween.tween_property(self, "scale", Vector2(1.1, 1.1), dur)
  ```
- **Anti-Pattern**: Do NOT scale a duration before passing it into a helper or VFX function that calls `scaled()` internally. This causes quadratic speed acceleration (`speed_factor * speed_factor`).

## 3. Container-Safe Transforms & Rest Poses
- **Never mutate root Control containers**:
  - Never set `top_level = true` on a card or view owned by a Godot `Container` (e.g. `SlotView`, `HBoxContainer`).
  - Animate internal visual child pivots (e.g. `MotionPivot`, `DeformPivot`), leaving the container layout root undisturbed.
- **Fixed Rest Pose**:
  - Tweens must always return nodes to canonical rest transforms (`position = Vector2.ZERO`, `rotation = 0.0`, `scale = Vector2.ONE`).
  - Never capture a mid-animation transform as a baseline rest state.

## 4. Puppet Mode & Visual Snapshot Contracts
- During combat VCR playback, presentation components must NEVER query the live `GachaBallInstance` (which is already at its end-of-turn state).
- Read data strictly from `CombatPayload` event fields and render onto views using `set_visual_state(...)`.
- `GameAction` classes must never serialize runtime instance IDs (`Object.get_instance_id()`). Use logical identifiers (`LocationIdentifier`).

## 5. Tooling: Aseprite & Godot MCP
- Use the `aseprite` MCP server to inspect slices, export spritesheets, and verify tag animations for unit and FX art.
- Use the `godot` MCP server (`run_project`, `get_debug_output`) to inspect animated scenes in real time.
