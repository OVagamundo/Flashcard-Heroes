import sys

filepath = '/Users/danhh/Desktop/Flashcard Heroes/scripts/GachaBallInstance.gd'
with open(filepath, 'r') as f:
    content = f.read()

# Add clear_initial_spawn_stats method
new_method = """

func clear_initial_spawn_stats() -> void:
	initial_spawn_hp = -1
	initial_spawn_pwr = -1
"""

content += new_method

with open(filepath, 'w') as f:
    f.write(content)

print("Patch applied to GachaBallInstance.gd")
