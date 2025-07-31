# Signal Migration Guide

## Overview

This guide provides step-by-step instructions for migrating from the old EventBus system to the new SignalBus system. The migration should be done systematically to ensure all components are updated correctly.

## Migration Process

### Phase 1: Preparation

1. **Backup Current System**
   - Ensure all current EventBus connections are documented
   - Create a backup of the current EventBus.gd file

2. **Add SignalBus to Project**
   - Add SignalBus.gd to the AutoLoad list in Project Settings
   - Set the name as "SignalBus"

3. **Update Project Settings**
   - Remove EventBus from AutoLoad list
   - Add SignalBus to AutoLoad list

### Phase 2: Signal Mapping

#### EventBus to SignalBus Signal Mapping

| EventBus Signal | SignalBus Signal | Notes |
|----------------|------------------|-------|
| `battle_start_requested` | `battle_start_requested` | Direct mapping |
| `battle_ended` | `battle_ended` | Direct mapping |
| `unit_stats_changed` | `unit_stats_changed` | Direct mapping |
| `battle_inventory_changed` | `battle_inventory_changed` | Direct mapping |
| `battle_log_event` | `battle_log_event` | Direct mapping |
| `run_data_changed` | `run_data_changed` | Direct mapping |
| `gold_changed` | `gold_changed` | Direct mapping |
| `selection_changed` | `selection_changed` | Direct mapping |
| `selection_clear_requested` | `selection_clear_requested` | Direct mapping |
| `shop_stock_refreshed` | `shop_stock_refreshed` | Direct mapping |
| `shop_purchase_requested` | `shop_purchase_requested` | Direct mapping |
| `shop_reroll_requested` | `shop_reroll_requested` | Direct mapping |
| `reward_chosen` | `reward_chosen` | Direct mapping |
| `path_choice_scene_requested` | `path_choice_scene_requested` | Direct mapping |
| `shop_scene_requested` | `shop_scene_requested` | Direct mapping |
| `battle_scene_requested` | `battle_scene_requested` | Direct mapping |
| `rest_site_scene_requested` | `rest_site_scene_requested` | Direct mapping |
| `flashcard_minigame_requested` | `flashcard_minigame_requested` | Direct mapping |
| `interaction_context_received` | `interaction_context_received` | Direct mapping |
| `inspection_windows_close_requested` | `inspection_windows_close_requested` | Direct mapping |
| `all_inspection_windows_close_requested` | `all_inspection_windows_close_requested` | Direct mapping |
| `flashcard_minigame_ended` | `flashcard_minigame_ended` | Direct mapping |
| `flashcard_progress_updated` | `flashcard_progress_updated` | Direct mapping |
| `debug_log` | `debug_log` | Direct mapping |
| `game_save_requested` | `game_save_requested` | Direct mapping |
| `game_load_requested` | `game_load_requested` | Direct mapping |

### Phase 3: Code Updates

#### Step 1: Update Signal Connections

**Before (EventBus):**
```gdscript
func _ready():
    EventBus.battle_ended.connect(_on_battle_ended)
    EventBus.unit_stats_changed.connect(_on_unit_stats_changed)
```

**After (SignalBus):**
```gdscript
func _ready():
    SignalBus.battle_ended.connect(_on_battle_ended)
    SignalBus.unit_stats_changed.connect(_on_unit_stats_changed)
```

#### Step 2: Update Signal Emissions

**Before (EventBus):**
```gdscript
func _on_battle_ended():
    EventBus.emit_signal("battle_ended", results)
    EventBus.emit_signal("unit_stats_changed", unit_uuid)
```

**After (SignalBus):**
```gdscript
func _on_battle_ended():
    SignalBus.battle_ended.emit(results)
    SignalBus.unit_stats_changed.emit(unit_uuid)
```

#### Step 3: Update Signal Disconnections

**Before (EventBus):**
```gdscript
func _exit_tree():
    EventBus.battle_ended.disconnect(_on_battle_ended)
```

**After (SignalBus):**
```gdscript
func _exit_tree():
    SignalBus.battle_ended.disconnect(_on_battle_ended)
```

### Phase 4: File-by-File Migration

#### Priority 1: Core Systems
1. **GameManager.gd** - High priority, many signals
2. **BattleManager.gd** - High priority, battle signals
3. **Main.gd** - High priority, scene management
4. **InteractionManager.gd** - High priority, interaction signals

#### Priority 2: UI Components
1. **Shop.gd** - Medium priority
2. **Reward.gd** - Medium priority
3. **BattleView.gd** - Medium priority
4. **Loadout.gd** - Medium priority

#### Priority 3: Utility Systems
1. **FlashcardManager.gd** - Low priority
2. **WindowManager.gd** - Low priority
3. **Database.gd** - Low priority

### Phase 5: Testing

#### Test Checklist
- [ ] All signal connections work correctly
- [ ] All signal emissions work correctly
- [ ] No missing signal connections
- [ ] No orphaned signal connections
- [ ] All UI updates work correctly
- [ ] All game state changes work correctly
- [ ] All scene transitions work correctly

#### Common Issues and Solutions

**Issue 1: Signal not found**
- **Cause**: Signal name mismatch or SignalBus not in AutoLoad
- **Solution**: Check signal name spelling and AutoLoad configuration

**Issue 2: Signal connection fails**
- **Cause**: Signal handler method doesn't exist or has wrong signature
- **Solution**: Ensure signal handler method exists and has correct parameters

**Issue 3: Signal emission fails**
- **Cause**: SignalBus not accessible or signal doesn't exist
- **Solution**: Check SignalBus AutoLoad configuration and signal definition

**Issue 4: UI not updating**
- **Cause**: Signal connection missing or incorrect
- **Solution**: Verify signal connection in _ready() method

### Phase 6: Cleanup

#### Remove EventBus References
1. Remove EventBus.gd file
2. Remove EventBus from AutoLoad list
3. Remove any remaining EventBus references in code
4. Update documentation to reference SignalBus

#### Update Documentation
1. Update all code comments referencing EventBus
2. Update README files
3. Update technical documentation
4. Update API documentation

## Migration Script

### Automated Migration Helper

```gdscript
# Migration helper script (run once)
extends Node

func migrate_eventbus_to_signalbus():
    var files_to_update = [
        "scripts/GameManager.gd",
        "scripts/BattleManager.gd",
        "scripts/Main.gd",
        "scripts/InteractionManager.gd",
        "scripts/Shop.gd",
        "scripts/Reward.gd",
        "scripts/BattleView.gd",
        "scripts/Loadout.gd"
    ]
    
    for file_path in files_to_update:
        var file = FileAccess.open(file_path, FileAccess.READ)
        if file:
            var content = file.get_as_text()
            file.close()
            
            # Replace EventBus with SignalBus
            content = content.replace("EventBus.", "SignalBus.")
            content = content.replace("EventBus.emit_signal(", "SignalBus.")
            
            # Write updated content
            file = FileAccess.open(file_path, FileAccess.WRITE)
            if file:
                file.store_string(content)
                file.close()
                print("Updated: ", file_path)
```

## Rollback Plan

If issues arise during migration:

1. **Immediate Rollback**
   - Restore EventBus.gd from backup
   - Remove SignalBus from AutoLoad
   - Add EventBus back to AutoLoad

2. **Partial Rollback**
   - Keep SignalBus but revert specific files
   - Use both systems temporarily
   - Migrate files one by one

3. **Testing Rollback**
   - Create test branch for migration
   - Test thoroughly before main branch
   - Keep EventBus as fallback

## Post-Migration Checklist

- [ ] All signals working correctly
- [ ] All UI components updating properly
- [ ] All game systems functioning
- [ ] No console errors or warnings
- [ ] Performance not degraded
- [ ] Documentation updated
- [ ] EventBus.gd removed
- [ ] Backup created and stored

## Benefits of Migration

1. **Better Organization**: Signals are categorized by system
2. **Improved Documentation**: All signals have detailed documentation
3. **Type Safety**: Parameter types are clearly defined
4. **Easier Maintenance**: Clear signal patterns and guidelines
5. **Better Debugging**: Improved error handling and logging
6. **Future-Proof**: Ready for additional features and systems

## Support

If issues arise during migration:

1. Check the signal documentation in `docs/SIGNAL_DOCUMENTATION.md`
2. Verify AutoLoad configuration in Project Settings
3. Test signal connections in isolation
4. Use debug signals for troubleshooting
5. Refer to the rollback plan if necessary 