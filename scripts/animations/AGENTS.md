# Animations & Presentation Domain Guidelines

## 1. Bound Tween Lifecycle
- Always bind Tweens directly to the node being animated using `node.create_tween()`.
- NEVER use unbound `get_tree().create_tween()`, which causes freed-instance crashes and leaks CanvasItem RIDs on shutdown.

## 2. Speed Factor & Single-Scaling Rule
- Scale animation durations using `AnimationConstants.scaled(duration)` exactly once.
- Never pre-scale a duration or delay before passing it to a VFX helper that applies `scaled()` internally (avoiding quadratic speed scaling).

## 3. Fixed Rest Pose Contract
- Never capture an in-flight `rotation` or `scale` as a rest pose.
- Tweens must always return the visual element to canonical rest values (`rotation = 0.0`, `scale = Vector2.ONE`, `position = Vector2.ZERO`).
- Do not set `top_level = true` on root Controls owned by Godot container layouts.

## 4. Animation Registry Routing
- Route combat event presentations through `AnimationRegistry` rather than adding inline animation branches to `BattleAnimator.gd`.
