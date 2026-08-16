class GachaBallInstance:
    def __init__(self, hp):
        self.base_hp = hp
        self.current_hp = hp
        self.trinket_hp = 0
    def recalculate_stats(self):
        prev_hp = self.current_hp
        self.current_hp = prev_hp

def test_merge_and_move():
    # Simulate parent 1 and 2 with Rusty Ring (+1 hp)
    parent1 = GachaBallInstance(4)
    parent1.trinket_hp = 1
    parent1.current_hp = 5
    
    parent2 = GachaBallInstance(4)
    parent2.trinket_hp = 1
    parent2.current_hp = 5
    
    # Merge Manager
    final_hp = parent1.base_hp + parent2.base_hp - parent2.base_hp # simplified
    
    # New unit spawns
    new_unit = GachaBallInstance(final_hp)
    print(f"Spawn HP: {new_unit.current_hp}")
    
    # VCR plays, Rusty Ring triggers
    new_unit.trinket_hp += 1
    new_unit.current_hp += 1
    print(f"After Rusty Ring: {new_unit.current_hp}")
    
    # Move unit
    new_unit.recalculate_stats()
    print(f"After Move: {new_unit.current_hp}")

test_merge_and_move()
