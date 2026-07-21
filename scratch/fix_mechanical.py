import re

path = "/Users/danhh/Desktop/Flashcard Heroes/docs/MechanicalSpecification.md"
with open(path, "r") as f:
    content = f.read()

# 1. Remove preamble
content = re.sub(r"^Perfect.*?# Flashcard Heroes", "# Flashcard Heroes", content, flags=re.DOTALL)

# 2. Fix 5.2 duplicate
content = content.replace("## 5.2 Management Actions", "## 5.3 Management Actions")

# 3. Fix 8.x duplicates
content = content.replace("## 8.2 Default Attack", "## 8.3 Default Attack")
content = content.replace("## 8.3 Damage", "## 8.4 Damage")
content = content.replace("## 8.4 Battlefield Slots", "## 8.5 Battlefield Slots")

# 4. Trait fixes
content = content.replace("| **Water** | Resilience | 2 | Heals adjacent allies at turn start. |", "| **Water** | Resilience | 2/4/6/8 | Heals adjacent allies at turn start. |")
content = content.replace("| **Wind** | Disruption | 2 | Steals PWR from mirrored enemy slot. |", "| **Air** | Disruption | 2/4/6/8 | Steals PWR from mirrored enemy slot. |")

# 5. Fix 11 duplicate -> 12
content = content.replace("# 11. Flashcard Resource Engine", "# 12. Flashcard Resource Engine")

# 6. Fix 12 -> 13
content = content.replace("# 12. Risk Calculation Framework", "# 13. Risk Calculation Framework")
content = content.replace("## 12.1", "## 13.1")
content = content.replace("## 12.2", "## 13.2")
content = content.replace("## 12.3", "## 13.3")
content = content.replace("## 12.4", "## 13.4")

# 7. Add 14 and shift remaining
content = content.replace("## 13.1 Encounter Budget", "# 14. Encounter & Shop System\n\n## 14.1 Encounter Budget")
content = content.replace("## 13.2", "## 14.2")
content = content.replace("## 13.3", "## 14.3")
content = content.replace("## 13.4", "## 14.4")

content = content.replace("# 14. UI/UX", "# 15. UI/UX")
content = content.replace("## 14.1", "## 15.1")

content = content.replace("# 15. The Economic Theory", "# 16. The Economic Theory")
content = content.replace("## 15.1", "## 16.1")

content = content.replace("# 15. Adjustable Balance", "# 17. Adjustable Balance")

content = content.replace("# 16. Strategic Risk", "# 18. Strategic Risk")
content = content.replace("## 16.", "## 18.")

# 8. Postamble & 17 -> 19
content = re.sub(r"# Result.*?# 17. Progression & Meta-Systems", "# 19. Progression & Meta-Systems", content, flags=re.DOTALL)
content = content.replace("## 17.1", "## 19.1")
content = content.replace("## 17.2", "## 19.2")

with open(path, "w") as f:
    f.write(content)

print("Fixes applied.")
