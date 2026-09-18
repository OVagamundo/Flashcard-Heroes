Graphic Design Document: Flashcard Heroes
1. Core Philosophy: Design by Synthesis
The visual identity of Flashcard Heroes is built on a rigorous, constraint-based system. Every Gachamon is a visual synthesis of its core components: Tier, Color, Element, and Shape. This document is not a collection of suggestions, but a rulebook. The artist's role is to follow these rules to create assets that are clear, consistent, and intuitive to the player. The goal is a straightforward pipeline where the design is the logical outcome of a specific "recipe."
2. The Core Pillars: Color, Element & Shape
Six base colors form the foundation of the game's trait and elemental system. Each is inextricably linked to a primary shape that informs all design choices.
Color	Trait / Role	Element	Base Shape	Visual Keywords
Red	Physical Offense (Warrior)	Fire	▲ Triangle	Aggressive, Sharp, Spiked, Piercing, Dynamic
Blue	Defense (Defender)	Earth/Stone	■ Square	Sturdy, Blocky, Plated, Defensive, Solid
Green	Support / Utility	Nature/Life	● Circle	Organic, Flowing, Round, Natural, Regenerative
Yellow	Ranged Offense	Air/Wind	◆ Diamond, arrow	Aerodynamic, Sleek, Swift, Tapered, Precise
Magenta	Magical (Flex)	Arcane/Spirit	⬢ Hexagon	Geometric, Symmetrical, Mystical, Crystalline
Cyan	Healer / Protector	Water/Ice	Wave, Blob	Protective, Nurturing, Spreading
3. The Tier System: Visual Evolution
The tier system dictates a Gachamon's physical and thematic complexity. Each tier has a mandatory checklist of features.
Tier 1: Elemental Creatures
Form: Non-humanoid. Must resemble a simple lifeform (elemental, insect, crustacean, plant, mineral).
Anatomy: Iconic & Simple. May lack distinct limbs; anatomy is secondary to the core shape.
Features: Monochromatic. Design uses 2-3 shades of its single base color besides the base warm white and cold black that will be used throughout the design. No crafted items or accessories are permitted.
Shape Expression: The unit is its base shape in its purest form. A Blue unit should have a fundamentally squareish silhouette for instance.
Tier 2: Complex Animals
Form: Non-humanoid. Must be based on a complex animal (mammal, reptile, bird, etc.) but not be like the any single animal that already exists.
Anatomy: Defined. Must have clear animalistic anatomy (head, torso, limbs).
Features: Color Blended. Must visibly incorporate its two base colors. Features naturalistic details (fur, scales, chitin, bark) and "natural armor" (thicker hide, shells, bone plates). No crafted weapons/armor.
Shape Expression: The base shapes of its parent units must be integrated into its anatomy (e.g., a bear with square, blocky shoulders and a rounded, organic body).
Tier 3: Anthropomorphic Heroes
Form: A little more Humanoid. Must be bipedal with human-like posture and proportions.
Anatomy: Sentient & Skilled. The design must communicate a "class" or role (knight, mage, rogue).
Features: Rich Palette & Gear. Employs the most complex color blends based on the units used to create it in the merging process (tier one units merge to form tier two units, tier two units merge to form tier three units). Crafted gear is mandatory (armor, clothing) and it must wield a defined weapon or tool or the own body should have equipment like appearance as if the creature itself evolved to have armor or weapons in it's body.
Shape Expression: The base shapes are expressed through the design of its armor, weapon, and class emblems (e.g., a samurai with triangular armor plates and a square-hilted katana).
4. Synthesis Rules: Creating Merged Units
Rule of Shape Dominance
A merged unit's primary silhouette is always dictated by the shape of its dominant color (the one with the most "parts" in its recipe). Secondary elements modify this core silhouette but do not override it.
Example: A Tier 3 Gachamon from Red(▲) + Red(▲) + Blue(■) is majority Red. Its core body shape must be triangular. The Blue/Square element will manifest as blocky armor or a square shield attached to the triangular frame.
Rule of Color Hierarchy
The color palette is applied in a strict order of dominance:
Primary Color: Applied to the largest areas (torso, main body).
Secondary Color: Applied to smaller, distinct areas (limbs, accent armor, markings).
Blended/Tertiary Color (e.g., Orange, Purple): Reserved only for energy effects, glows, auras, weapon trails, or small gradients where two color zones meet.
5. Pixel Art & Palette Specification
Global Palette: All assets must adhere to a strict 32-color global palette. This ensures visual cohesion across the entire game.
Shading Style: Strictly Flat Colors. No gradients, anti-aliasing, or "anime-style" soft shading. Depth is achieved by using distinct color values.
Hue Shifting: Shading should follow a "colder shadows, warmer highlights" principle. Shadows should shift slightly towards blue/purple, while highlights shift slightly towards yellow/orange relative to the base color.
Outlines: All units must have a thin, simple, single dark color outline to ensure clarity and a consistent style.
Portrait Resolution: All unit portraits will be designed within a consistent square canvas (e.g., 96x96 pixels).
6. Card & UI Graphic Design
Card Anatomy & Rules
Card Size: All cards are the same size.
Card Outline: A very simple, thin, monochromatic border.
Portrait: Static, non-animated pixel art. The portrait can be a bust or partial body shot, but must clearly represent the unit.
Background: The background of the card is a flat field of color(s) derived from the unit.
Tier 1: Solid background of the unit's base color designs with warm white.
Tier 2: A simple split or two-tone background of the unit's two base colors designs with warm white.
Tier 3: A more complex blend or subtle pattern using the unit's constituent colors designs with warm white.
Stats Display:
No Labels. The card will display only two numerical values for HP and Power.
Visual Distinction: The values must be visually distinct. HP should be in a different color then Power. they should both have the same weight.
Font: Must use the **32px Black Composite** font for all critical numerical and descriptive values in combat and inspection windows.

### 6.1 Unit View Elements
Visual rules for dynamic elements overlaid on the unit view during gameplay.

**Physical Gachaballs (Inventory):**
- **Representation**: Units and items in the battle inventory are enclosed in a **Physical Gachaball Capsule**.
- **1x Scale Constraint**: Balls are strictly forced to **1x native scale** and show **no UI overlays** (stats/pwr).
- **Margin Alignment**: 
    - Capsule texture: 96x96 pixels (Radius 48px).
    - Physics collider: 50px radius.
    - **2px Safety Margin**: The intentional gap between visual edge and collision edge prevents visual clipping and improves tactile "clacking".
- **Aesthetic**: Translucent outer shell with the standard unit/item icon visible inside.
- **Animation**: Reacts to gravity, collisions, and drawer movement with tactile physics and clack sounds.

**Equipped Items:**
- **Position:** Vertically stacked on the **Left Edge** of the unit slot.
- **Size:** Small, fixed 45x45px icons.
- **Style:** Purely visual (non-interactive in battle). Must have a 1px white outline to separate from background.
- **Layout:** Strictly aligned to x=0. Must not overlap the unit sprite (which faces right).

**Trait Trinkets:**
- **Dynamic Outlines:** Trait Trinkets (Fire, Earth, Water, Air) use a dynamically thick outline shader (up to 30.0px) that cycles through metallic gradient colors when their synergy threshold is met.
- **Soul Counters:** Trait Trinkets display a small label in the bottom-right corner showing the current number of active souls of that element in the battle lineup.

**Status Effects:**
- **Burn:**
    - **Visual:** Instant opaque **Orange** flash on the entire unit sprite.
    - **Feedback:** Floating orange number indicating stack count.
- **Armor:**
    - **Visual:** Instant opaque **Grey** flash on the entire unit sprite.
    - **Feedback:** Floating grey number indicating stack count.
- **Power Steal (Soul Siphon):**
    - **Visual:** Uses "Damage" language. Red/Black number popping off the unit.
    - **Feedback:** Unit performs "Hurt" reaction (shake/flash) just like taking HP damage, even though it is PWR loss.

**Global VFX & Layering:**
- **Layer 150 (GlobalVFXLayer)**: All currency (Gold Coins) and screen-space transitions (Gachaball Draws) must render on this layer.
- **Occlusion**: This layer resides above the HUD, Contextual Windows, and Modal Layer, ensuring coins and effects are never hidden by UI containers.
- **Z-Index**: Individual VFX nodes should maintain a baseline `z_index` of 5 on this layer for internal layering.

7. Appendix A: The Gachamon Design Checklist
To design any unit, follow this exact process to ensure 100% compliance with the guidelines.
Define the Recipe: State the inputs (e.g., Tier 2, Green(●) + Blue(■)).
Consult Tier Checklist: Check the mandatory features for that Tier (Form, Anatomy, Features, Shape Expression).
Apply Shape Dominance Rule: Determine the primary silhouette. If 50/50, the shapes must be equally blended.
Develop Core Concept: Synthesize the Tier, Shapes, and Elements into a concept (e.g., "A Tier 2 bear-like creature made of living stone and vines").
Apply Color Hierarchy Rule: Assign the Primary, Secondary, and Blended colors to the concept's anatomy and features.
Execute Pixel Art: Draw the unit portrait adhering to all palette, shading, and outline specifications.
Assemble the Card: Place the final portrait onto a card background that matches its Tier and color recipe. Add the two numerical stat values according to the UI rules.

## 8. Universal Art Style Swapping
The game implements a game-wide, runtime **Universal Art Style Swapping** framework managed by the `ArtStyleManager` autoload service. This allows players to toggle seamlessly between themed asset sets (e.g., "Realistic" and "PixelArt") directly from the Options menu.

### 8.1 Path-Based Theme Resolution
All visual style assets are structured under corresponding folders in the global assets directory:
- `res://assets/Realistic/` (Default and fallback style)
- `res://assets/PixelArt/`

The `ArtStyleManager` dynamically translates file paths by swapping the style directory part (`parts[3]` of standard paths matching `res://assets/[StyleName]/...`). 

### 8.2 Fallback Strategy
If an asset is not yet implemented or missing in the currently selected style (e.g., `PixelArt`), the resolver automatically falls back to the corresponding asset under the `Realistic` directory. This ensures the game never crashes or displays missing textures during development or asset curation.

### 8.3 Tree-Wide Reflection Swapping
When the art style changes or new UI elements are added to the scene tree:
1. The manager recursively traverses the active `SceneTree` (and connects to `node_added` signals).
2. It queries each node's property list via reflection to identify properties holding a `Texture2D` or `StyleBoxTexture`.
3. It replaces the existing texture with its themed counterpart automatically, ensuring a seamless visual transition without manual script-level updates.

### 8.4 State Persistence
The player's selected art style is saved to `user://art_style_settings.save` and loaded at the earliest possible stage of application boot.

---

The great inspiration for the pixel art and general aesthetic is the game "Cross Blitz" including visual effects and shaders.