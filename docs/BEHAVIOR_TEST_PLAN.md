# Flashcard Heroes V7.0 Behavior Test Plan

## Overview
This document systematically tests all player interaction behaviors across different contexts to ensure they match the TDD V7.0 specifications. We'll work through each context one at a time to prevent "whack-a-mole" issues.

## Test Contexts

### 1. RUN INVENTORY CONTEXT (Priority 1 - Current Issue)
**Location**: RunInventoryT1, RunInventoryT2, RunInventoryT3 containers
**Interaction Mode**: FULLY_INTERACTIVE
**Expected Behaviors**:

#### 1.1 Selection Behavior
- [ ] **Single Click Selection**: Click on GachaBall should select it (visual feedback: gold border)
- [ ] **Selection Persistence**: Selection should remain until another action occurs
- [ ] **Same Item Deselection**: Clicking same item should deselect it
- [ ] **Different Item Selection**: Clicking different item should change selection

#### 1.2 Move Actions
- [ ] **Move to Empty Slot**: Select item, click empty slot → item moves
- [ ] **Move Between Tiers**: Select item in T1, click empty slot in T2 → item moves to T2
- [ ] **Invalid Move**: Move to invalid location → action rejected, selection cleared

#### 1.3 Swap Actions
- [ ] **Swap Items**: Select item A, click item B → items swap positions
- [ ] **Cross-Tier Swap**: Swap between different inventory tiers

#### 1.4 Merge Actions
- [ ] **Valid Merge**: Select mergeable item A, click mergeable item B → merge dialog appears
- [ ] **Invalid Merge**: Select non-mergeable items → action rejected

#### 1.5 Inspection Behavior
- [ ] **Double-Click Inspection**: Double-click item → inspection window opens
- [ ] **Inspection Window Positioning**: Window should position correctly relative to item
- [ ] **Background Click Close**: Click outside inspection window → window closes

#### 1.6 Drag & Drop
- [ ] **Drag Start**: Drag item → visual feedback, selection cleared
- [ ] **Drag to Empty**: Drag to empty slot → item moves
- [ ] **Drag to Item**: Drag to occupied slot → swap occurs
- [ ] **Invalid Drop**: Drag to invalid location → action rejected

### 2. BATTLE BOARD CONTEXT
**Location**: PlayerLineup, PlayerBench, ItemInventory containers
**Interaction Mode**: FULLY_INTERACTIVE
**Expected Behaviors**:

#### 2.1 Selection Behavior
- [ ] **Unit Selection**: Click unit → selects unit
- [ ] **Item Selection**: Click item → selects item
- [ ] **Selection Persistence**: Selection remains until action occurs

#### 2.2 Move Actions
- [ ] **Unit Movement**: Move units between lineup and bench
- [ ] **Item Movement**: Move items between inventory and units
- [ ] **Invalid Moves**: Prevent invalid unit/item movements

#### 2.3 Equip Actions
- [ ] **Item to Unit**: Select item, click unit → item equips
- [ ] **Unequip**: Select equipped item, click inventory → item unequips

#### 2.4 Inspection Behavior
- [ ] **Unit Inspection**: Double-click unit → unit inspection window
- [ ] **Item Inspection**: Double-click item → item inspection window
- [ ] **Equipped Item Inspection**: Click equipped item in unit window → item inspection

### 3. SHOP CONTEXT
**Location**: Shop container
**Interaction Mode**: SELECTION_ONLY
**Expected Behaviors**:

#### 3.1 Selection Behavior
- [ ] **Item Selection**: Click item → selects item (visual feedback)
- [ ] **Selection Change**: Click different item → changes selection
- [ ] **No Actions**: Cannot move, swap, or merge items

#### 3.2 Purchase Actions
- [ ] **Purchase Selected**: Click purchase button → buys selected item
- [ ] **Purchase Validation**: Cannot purchase if insufficient gold

#### 3.3 Inspection Behavior
- [ ] **Double-Click Inspection**: Double-click item → inspection window
- [ ] **Background Click Close**: Click outside → inspection window closes

### 4. REWARD CONTEXT
**Location**: Rewards container
**Interaction Mode**: SELECTION_ONLY
**Expected Behaviors**:

#### 4.1 Selection Behavior
- [ ] **Reward Selection**: Click reward → selects reward
- [ ] **Selection Change**: Click different reward → changes selection
- [ ] **No Actions**: Cannot move or modify rewards

#### 4.2 Claim Actions
- [ ] **Claim Selected**: Click confirm → claims selected reward
- [ ] **Take Gold**: Click gold button → takes gold instead

#### 4.3 Inspection Behavior
- [ ] **Double-Click Inspection**: Double-click reward → inspection window

### 5. ENEMY CONTEXT
**Location**: EnemyLineup container
**Interaction Mode**: INSPECTION_ONLY
**Expected Behaviors**:

#### 5.1 No Selection
- [ ] **No Selection**: Cannot select enemy units
- [ ] **No Actions**: Cannot move or modify enemy units

#### 5.2 Inspection Behavior
- [ ] **Single-Click Inspection**: Single-click enemy → inspection window
- [ ] **Equipped Item Inspection**: Click equipped items in enemy window

### 6. INSPECTION WINDOW CONTEXT
**Location**: UnitInspectionWindow, ItemInspectionWindow
**Expected Behaviors**:

#### 6.1 Window Management
- [ ] **Proper Positioning**: Window positions correctly relative to anchor
- [ ] **Child Windows**: Can open child inspection windows
- [ ] **Background Click**: Click window background → closes child windows

#### 6.2 Interaction Behavior
- [ ] **Equipped Item Grid**: Can interact with equipped items (player units)
- [ ] **Read-Only Mode**: Enemy unit windows are read-only
- [ ] **Window Closure**: Proper cleanup when windows close

### 7. MODAL WINDOW CONTEXT
**Location**: InventoryWindow, ChoiceWindow, EndBattlePopup
**Expected Behaviors**:

#### 7.1 Modal Behavior
- [ ] **Exclusive Focus**: Modal blocks other interactions
- [ ] **Background Blocker**: Click outside modal → closes modal
- [ ] **Selection Clear**: Opening modal clears selections

#### 7.2 Inventory Window
- [ ] **Persistent Slots**: Slots persist across data changes
- [ ] **Content Updates**: Content updates without recreating slots
- [ ] **Interaction Context**: Proper interaction mode for slots

## Current Issue Analysis: Run Inventory Selection

### Problem Description
- GachaBalls in run inventory select and deselect immediately
- Selection doesn't persist
- No visual feedback for selection state

### Root Cause Investigation
1. **GlobalInteractionRouter**: Check if selection commands are being generated correctly
2. **InteractionManager**: Check if selection state is being managed properly
3. **GachaBallView**: Check if selection feedback is being applied
4. **Signal Flow**: Check if signals are being emitted and received correctly

### Debugging Steps
1. ✅ Add debug prints to track selection flow
2. ✅ Check GlobalInteractionRouter command generation
3. ✅ Verify InteractionManager state management
4. ✅ Test GachaBallView selection feedback
5. ✅ Monitor signal emissions and receptions

### Issues Found and Fixed
1. **Missing Interaction Context**: InventoryWindow was not setting interaction context for GachaBallView and SlotView instances
2. **State Synchronization**: GlobalInteractionRouter and InteractionManager had conflicting selection state management
3. **Aggressive Validation**: Periodic validation was clearing selections immediately

### Fixes Applied
1. ✅ Added `set_interaction_context()` calls in InventoryWindow for both GachaBallView and SlotView
2. ✅ Fixed state synchronization between GlobalInteractionRouter and InteractionManager
3. ✅ Temporarily disabled aggressive periodic validation for debugging
4. ✅ Added comprehensive debug logging to track selection flow

## Testing Methodology

### Phase 1: Run Inventory Context (Current Focus)
1. Test basic selection behavior
2. Fix selection persistence issues
3. Verify visual feedback
4. Test move/swap/merge actions
5. Test inspection behavior

### Phase 2: Battle Board Context
1. Test unit and item selection
2. Test movement between containers
3. Test equip/unequip actions
4. Test inspection windows

### Phase 3: Shop & Reward Contexts
1. Test selection-only behavior
2. Test purchase/claim actions
3. Test inspection behavior

### Phase 4: Enemy Context
1. Test inspection-only behavior
2. Test read-only interactions

### Phase 5: Window Management
1. Test inspection window positioning
2. Test modal window behavior
3. Test background click handling

## Success Criteria

### For Each Context:
- [ ] All expected behaviors work correctly
- [ ] No unexpected behaviors occur
- [ ] Visual feedback is consistent
- [ ] Error states are handled gracefully
- [ ] Performance is acceptable

### Overall System:
- [ ] No "whack-a-mole" issues (fixing one thing breaks another)
- [ ] Consistent interaction patterns across contexts
- [ ] Proper state management
- [ ] Clean signal flow
- [ ] Robust error handling

## Next Steps

1. **Start with Run Inventory Context**: Focus on fixing the immediate selection issue
2. **Systematic Testing**: Test each behavior one at a time
3. **Document Issues**: Record any problems found
4. **Fix and Verify**: Fix issues and verify they don't break other contexts
5. **Move to Next Context**: Only proceed when current context is fully working 