
- When writing temporary utility scripts (like Python scripts for fixing bugs, parsing files, or Godot test scripts), ALWAYS create them in a temporary folder like `scratch/` and remove them when they are no longer needed. Do not clutter the project root directory with one-off scripts.
- NEVER modify game mechanics, unit abilities, stats, or visual aesthetics without explicitly asking the user for permission first. Restrict all unprompted fixes strictly to code syntax, data routing, and crash resolution.
