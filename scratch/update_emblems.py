import os

file_path = "localization/game.csv"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.startswith('item.emblem_fire.desc'):
        lines[i] = 'item.emblem_fire.desc,"When equipped, grants +2 PWR and the [b]Fire[/b] soul, allowing the unit to benefit from Fire trait synergies.","Quando equipado, concede +2 PWR e a alma de [b]Fogo[/b], permitindo que a unidade se beneficie das sinergias do traço de Fogo."\n'
    elif line.startswith('item.emblem_earth.desc'):
        lines[i] = 'item.emblem_earth.desc,"When equipped, grants +4 HP and the [b]Earth[/b] soul, allowing the unit to benefit from Earth trait synergies.","Quando equipado, concede +4 HP e a alma de [b]Terra[/b], permitindo que a unidade se beneficie das sinergias do traço de Terra."\n'
    elif line.startswith('item.emblem_water.desc'):
        lines[i] = 'item.emblem_water.desc,"When equipped, grants +2 HP, +1 PWR, and the [b]Water[/b] soul, allowing the unit to benefit from Water trait synergies.","Quando equipado, concede +2 HP, +1 PWR e a alma de [b]Água[/b], permitindo que a unidade se beneficie das sinergias do traço de Água."\n'
    elif line.startswith('item.emblem_air.desc'):
        lines[i] = 'item.emblem_air.desc,"When equipped, grants +2 HP, +1 PWR, and the [b]Air[/b] soul, allowing the unit to benefit from Air trait synergies.","Quando equipado, concede +2 HP, +1 PWR e a alma de [b]Ar[/b], permitindo que a unidade se beneficie das sinergias do traço de Ar."\n'

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("emblems updated successfully")
