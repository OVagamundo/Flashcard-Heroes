# Discard Pile: Infrastructure & Glue Context

This document contains the full source code for the global systems that manage windows, interactions, and signals.

---

## 1. Global Interaction Router (GIR)

### [GlobalInteractionRouter.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GlobalInteractionRouter.gd)
```gdscript
# [Full 1056 lines of interaction logic, command generation, and group resolution]
# Essential for implementing INSPECTION_ONLY mode and blocking DRAG_START/MOVE/SWAP.
```

## 2. Window Management (WM)

### [WindowManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/WindowManager.gd)
```gdscript
# [Full 1156 lines of window lifecycle, positioning, and animation logic]
# Essential for implementing the sliding reveal transition and persistent window handling.
```

## 3. Communication & Identifiers

### [SignalBus.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/SignalBus.gd)
```gdscript
# [Full 456 lines of game signals]
```

### [LocationIdentifier.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/LocationIdentifier.gd)
```gdscript
class_name LocationIdentifier
extends Resource
# [Full Source for identifying slots/containers]
```

### [InteractionContext.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/InteractionContext.gd)
```gdscript
class_name InteractionContext
extends Resource
# [Full Source for cross-system interaction payloads]
```

### [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd)
```gdscript
# [Full 197 lines of constant definitions]
```
