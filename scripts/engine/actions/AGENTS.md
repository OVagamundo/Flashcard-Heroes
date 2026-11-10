# Command & Action Pipeline Domain Guidelines

## 1. Serializable Primitive Payloads Only
- `GameAction` payloads must contain ONLY JSON-serializable primitives:
  - `int`, `float`, `bool`, `String`, `StringName`, `Array`, `Dictionary`, `LocationIdentifier`.
- Strictly forbidden in `GameAction` payload properties and serialization:
  - `Vector2`, `Vector3`, `Color`, or any Godot geometric structs
  - `Node`, `Control`, `Resource`, or object pointers
  - Runtime object IDs (`Object.get_instance_id()`, `instance_from_id()`)

## 2. Replay Parity Contract
- `execute()` must execute identically in both live visual client and headless replay modes.
- Authoritative state mutations must occur synchronously on Frame 0 within `execute()`.
- Do NOT delay backend state mutation into visual tween callbacks or UI animation completions.
- Never write `if is_instance_valid(ActionQueue): ... else:` fallback branches in presentation code.
