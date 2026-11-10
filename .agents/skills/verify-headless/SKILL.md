---
name: verify-headless
description: Runs sandbox-safe headless Godot verification tests, checks GDScript compilation, and inspects debug outputs via CLI and Godot MCP tools.
---

# Verify Headless Simulation & Compilation

Use this skill to run fast headless Godot verification checks, execute regression suites, and diagnose GDScript compilation errors without opening graphical windows.

## 1. Quick Compilation & Startup Check
To verify that all GDScript scripts, project settings, and singletons compile and load cleanly with zero parse errors:
```bash
.agents/skills/verify-headless/scripts/run_headless.sh
```
- Exits after 2 frames (`--quit-after 2`).
- Sandboxes user data under `/tmp` to prevent permission issues or persistent cache pollution.
- Must exit with return code `0`.

## 2. Running Headless Test Scenes
To execute a specific test scene or script headlessly:
```bash
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```
- Passes arguments directly to Godot's `--headless` invocation.
- Captures test assertions, error logs, and state digests.

## 3. Godot MCP Integration (When Visual Inspection or Editor Sync is Needed)
When diagnosing complex visual scene bugs or updating asset UIDs, use the lazy-loaded `godot` MCP server:
- `update_project_uids`: Updates `.uid` files for resources in the project.
- `run_project`: Launches the Godot editor or project window for live inspection.
- `get_debug_output`: Fetches console logs from the running Godot instance.
- `stop_project`: Terminates the running project instance.
