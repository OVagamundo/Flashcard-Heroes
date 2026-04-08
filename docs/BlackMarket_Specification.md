# Technical Specification: Black Market Encounter

This document defines the hard requirements, UI layout, and mechanical behavior of the Black Market encounter for clean-room implementation.

## 1. Encounter Mechanics
- **Availability**: Appears in the path selection pool.
- **Node Type**: `BLACK_MARKET` / `ui.black_market_node`.
- **Cost**: A flat fee of **5 Gold** per interaction (Remove or Transform).
- There should be a button in the middle saying in big letters "REMOVE OR TRANSFORM" that open the run inventory exactly like clicking the base of the gachamachines do. Just a redundant button nothing else.
- under this button is the "leave " button to go back to the path choice exactly like the other scenes (rest, gambling, training or shop).
- **Transactional Staging**:(once the run inventory is open by any means)
  - Dropping a unit into the Black Market black slot places the unit there just like in any other slot. Pay attention since this is a new slot outside the container window area of the run inventory and has special unique characteristics, like not closing the Run inventory when clicked upon even though it is in the outside area of the main window, an exception rule should be added to the window manager to allow this and the mouse signal on this slot should not pass through to the Gachamachine base since that would also cause the inventory to close.
  - A choice modal opens above the slot and the unit remains in the slot until a decision is made.
  - The choice modal should have two buttons: "Remove" and "Transform" and at this point only 3 actions should be possible. Removing the gachaball in the slot for this game run completely, transforming the gachaball into another of the same tier at random but that can´t be the same one that was placed there or canceling the entire thing by clicking anywhere else outside the choice window itself and the gachaball should return to its original location.
  - **Cancel/Rollback**: If the modal is dismissed (Background click or Escape), the staged unit must move back to its original inventory location. No gold is deducted.

## 2. Interaction Features
- **Remove (Success)**: Consumes 5 Gold and destroys the unit for this game run.
- **Transform (Success)**: Consumes 5 Gold. Replaces the unit with a random unit of the **same tier** (standard unit pool). The resulting unit is automatically moved to the correct tier inventory (T1/T2/T3) with the gachaball capsule jump animation used in the gachamachines draw animation going from the black market black slot to the slot the original unit occupied.
- **Insufficient Gold**: If the player has < 5 Gold, the slot must visually shake and play an error sound like the rejection animation used in the shop.

## 3. UI Layout & Assets
- **Background**: `res://assets/ui/BGs/BlackMarket.png`.
- **Map Icon**: `res://assets/ui/textures/BlackMarketPath.png`.
- **Service black slot area**: 
  - **Size**: 128x128 pixels.
  - **Logical Container**: `&"BlackMarket"` (Single slot).
- **Layering (Z-Order)**: 
- The black market service area that appear once the player open the run inventory in the black market context only, should ocupy the area of the base of the gachamachine in the bottom area of the main scene hud, and should be in front of it in the z order so it does not get covered by the gachamachine base.
the large black area should be black and semitransparent with a white border and the black slot should be in the center of this area inside a opaque black box with a white border with the text "DROP A GACHABALL HERE TO REMOVE OR TRANSFORM IT FOR 5 GOLD" above the slot. 

## 4. UI Copy & Strings
- **Title**: `ui.black_market_title` ("Black Market")
- **Prompt**: `ui.black_market_prompt` ("What would you like to do with {name}?")
- **Instruction**: `ui.black_market_instructions` ("Drop a GachaBall here to Remove or Transform it for 5 Gold.")
- **Options**:
  - `ui.remove_cost`: "Remove (5 Gold)"
  - `ui.transform_cost`: "Transform (5 Gold)"

## 5. Verified Session Failures (Observable Behavior)
The following issues were observed and confirmed during testing:

- **Automatic Inventory Closure**: Clicking the Black Market service area or slot caused the open Run Inventory window to close immediately, preventing unit placement.
- **Input Passthrough**: Interactions with the Black Market slot triggered unwanted behavior from the underlying Gacha Machine (e.g., focus changes, machine interaction signals) as if the slot were transparent.
- **Interaction Loss During Transitions**: Drops attempted while the inventory window was opening or closing were ignored, causing the Gachaball to return to its origin.
- **Location Matching Failure**: Items dropped into the Black Market slot were often not recognized as valid targets, causing "Return to Sender" events.
- **Initial Drop Failure**: The first unit dropped into an empty Black Market slot failed to register; subsequent drops only functioned once a unit was already present in the visual slot.
- **Z-Order Occlusion**: The Black Market UI elements were visually covered by the Gacha Machine HUD or other background layers.
- **Visual De-sync**: Gachaball puppets remained in the Black Market slot visually even after being logically moved back to the inventory, or appeared in multiple locations simultaneously.


