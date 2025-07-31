# Pre-Testing Checklist

## System Integration Verification

### ✅ **Autoload Configuration**
- [x] SignalBus added to project.godot autoload list
- [x] All required singletons are in autoload list
- [x] No duplicate autoload entries

### ✅ **Core Systems**
- [x] SignalBus.gd exists and has all required signals
- [x] EventBus.gd compatibility layer implemented
- [x] GlobalInteractionRouter.gd updated to use SignalBus
- [x] All effect classes (EffectDealDamage, EffectHeal, EffectApplyStatus) updated to use SignalBus
- [x] BasicAttackEffect.gd updated to use SignalBus

### ✅ **Class Definitions**
- [x] All class_name declarations are in place
- [x] No missing class_name declarations
- [x] All required resources exist (InteractionContext, ConditionDefinition, etc.)

### ✅ **Signal System**
- [x] SignalBus has comprehensive signal documentation
- [x] EventBus forwards all signals to SignalBus
- [x] Migration guide and documentation created
- [x] Backward compatibility maintained

### ✅ **Integration Points**
- [x] GlobalInteractionRouter connects to SignalBus.interaction_context_received
- [x] Effect system uses SignalBus for battle events
- [x] Window management system uses EventBus (forwarded to SignalBus)
- [x] Battle system uses EventBus (forwarded to SignalBus)

## Expected Behavior

### **Startup**
1. Game should start without errors
2. All singletons should initialize properly
3. SignalBus should be available globally
4. EventBus compatibility layer should work

### **Basic Functionality**
1. Title screen should load
2. Navigation between scenes should work
3. UI interactions should function
4. Window management should work

### **Advanced Systems**
1. Ability system should be ready (but may not be fully tested yet)
2. Encounter generation should work
3. Flashcard system should be available
4. Shop and reward systems should work with new input system

## Potential Issues to Watch For

### **Startup Issues**
- Missing autoload entries
- Class_name conflicts
- Missing resource files
- Signal connection errors

### **Runtime Issues**
- Signal forwarding not working
- UI interactions not responding
- Window management problems
- Battle system errors

### **Performance Issues**
- Memory leaks from signal connections
- Slow UI responsiveness
- Excessive signal emissions

## Testing Priority

### **Phase 1: Basic Functionality**
1. Start the game
2. Navigate to different scenes
3. Test basic UI interactions
4. Verify window management

### **Phase 2: Core Systems**
1. Test inventory operations
2. Test battle system
3. Test shop and reward systems
4. Test flashcard system

### **Phase 3: Advanced Features**
1. Test ability system
2. Test encounter generation
3. Test all interaction modes
4. Test performance

## Rollback Plan

If issues arise:

1. **Immediate Rollback**: Remove SignalBus from autoload and revert to EventBus-only
2. **Partial Rollback**: Keep SignalBus but disable compatibility layer
3. **Gradual Rollback**: Revert specific systems one by one

## Success Criteria

The refactoring is successful if:

1. ✅ Game starts without errors
2. ✅ All basic functionality works
3. ✅ UI interactions are responsive
4. ✅ No performance degradation
5. ✅ All systems are properly integrated
6. ✅ Signal system is working correctly

## Next Steps

After successful testing:

1. Complete Phase 9: Testing & Validation
2. Move to Phase 10: Documentation & Cleanup
3. Remove EventBus compatibility layer
4. Update all remaining EventBus references to SignalBus
5. Finalize documentation and cleanup 