import re

with open("scenes/DiscardPileWindow.tscn", "r") as f:
    content = f.read()

# Make Left Wall thicker and move it left
content = re.sub(
    r'(?sm)\[sub_resource type="RectangleShape2D" id="RectangleShape2D_left"\]\nsize = Vector2\(100, 1165\)',
    r'[sub_resource type="RectangleShape2D" id="RectangleShape2D_left"]\nsize = Vector2(500, 1165)',
    content
)
content = re.sub(
    r'\[node name="LeftWall" type="CollisionShape2D" parent="DiscardPhysicsContainer/Bounds" index="0"\]\nposition = Vector2\(-64, 582\.5\)',
    r'[node name="LeftWall" type="CollisionShape2D" parent="DiscardPhysicsContainer/Bounds" index="0"]\nposition = Vector2(-250, 582.5)',
    content
)

# Make Right Wall thicker and move it right
content = re.sub(
    r'(?sm)\[sub_resource type="RectangleShape2D" id="RectangleShape2D_right"\]\nsize = Vector2\(100, 1165\)',
    r'[sub_resource type="RectangleShape2D" id="RectangleShape2D_right"]\nsize = Vector2(500, 1165)',
    content
)
content = re.sub(
    r'\[node name="RightWall" type="CollisionShape2D" parent="DiscardPhysicsContainer/Bounds" index="1"\]\nposition = Vector2\(1344, 582\.5\)',
    r'[node name="RightWall" type="CollisionShape2D" parent="DiscardPhysicsContainer/Bounds" index="1"]\nposition = Vector2(1530, 582.5)',
    content
)

# Move SpawnPoint down to y=10
content = re.sub(
    r'\[node name="SpawnPoint" parent="DiscardPhysicsContainer" index="0"\]\nposition = Vector2\(640, -60\)',
    r'[node name="SpawnPoint" parent="DiscardPhysicsContainer" index="0"]\nposition = Vector2(640, 10)',
    content
)

with open("scenes/DiscardPileWindow.tscn", "w") as f:
    f.write(content)

print("Updated DiscardPileWindow.tscn")
