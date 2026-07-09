import os
import csv

file_path = "localization/game.csv"

# Add missing name keys
missing_keys = [
    'ability.unit_t3_l.name,Wealth Accumulation,Acúmulo de Riqueza\n',
    'ability.unit_t3_j_ability.name,Standard\'s Legacy,Legado do Estandarte\n'
]

with open(file_path, "a", encoding="utf-8") as f:
    f.writelines(missing_keys)

# Read all lines and replace specific descriptions
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    # Shadow Cloner
    if line.startswith('ability.unit_t3_shadow_l1.desc'):
        lines[i] = 'ability.unit_t3_shadow_l1.desc,"Grants an additional copy of any buff received by an adjacent ally at 100% effectiveness.","Concede uma cópia adicional de qualquer buff recebido por um aliado adjacente com 100% de eficácia."\n'
    elif line.startswith('ability.unit_t3_shadow_l2.desc'):
        lines[i] = 'ability.unit_t3_shadow_l2.desc,"Grants an additional copy of any buff received by an adjacent ally at 150% effectiveness.","Concede uma cópia adicional de qualquer buff recebido por um aliado adjacente com 150% de eficácia."\n'
    elif line.startswith('ability.unit_t3_shadow_l3.desc'):
        lines[i] = 'ability.unit_t3_shadow_l3.desc,"Grants an additional copy of any buff received by an adjacent ally at 200% effectiveness.","Concede uma cópia adicional de qualquer buff recebido por um aliado adjacente com 200% de eficácia."\n'
        
    # Golden Hermit
    elif line.startswith('ability.unit_t3_l_l1.desc'):
        lines[i] = 'ability.unit_t3_l_l1.desc,"At the start of each turn, permanently gain +3 HP and +3 PWR for every 5 Gold you currently have.","No início de cada turno, ganha permanentemente +3 HP e +3 PWR para cada 5 de Ouro que você possuir no momento."\n'
    elif line.startswith('ability.unit_t3_l_l2.desc'):
        lines[i] = 'ability.unit_t3_l_l2.desc,"At the start of each turn, permanently gain +4 HP and +4 PWR for every 5 Gold you currently have.","No início de cada turno, ganha permanentemente +4 HP e +4 PWR para cada 5 de Ouro que você possuir no momento."\n'
    elif line.startswith('ability.unit_t3_l_l3.desc'):
        lines[i] = 'ability.unit_t3_l_l3.desc,"At the start of each turn, permanently gain +5 HP and +5 PWR for every 5 Gold you currently have.","No início de cada turno, ganha permanentemente +5 HP e +5 PWR para cada 5 de Ouro que você possuir no momento."\n'

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("game.csv updated successfully")
