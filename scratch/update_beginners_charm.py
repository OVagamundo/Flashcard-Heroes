import os

file_path = "localization/game.csv"
missing_keys = [
    'ability.beginners_charm.name,Beginner\'s Charm,Amuleto de Principiante\n',
    'ability.beginners_charm.desc,Increases minigame score.,Aumenta a pontuação no minigame.\n'
]

with open(file_path, "a", encoding="utf-8") as f:
    f.writelines(missing_keys)

print("added beginners charm")
