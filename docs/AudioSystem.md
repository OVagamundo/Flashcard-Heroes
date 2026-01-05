# Audio System Documentation

## Overview
The audio system in *Flashcard Heroes* provides immersive audio feedback for all game interactions. It's built around a central `AudioManager` singleton with a static `Audio` wrapper for convenient access.

## Technical Architecture

### 1. Audio Access Pattern
```gdscript
# SFX - Fire and forget with pitch variance
Audio.play_sfx("combat_hit")

# BGM - Automatic crossfade with looping
Audio.play_music(SoundRegistry.BGM_BATTLE)
```

### 2. Core Components

| Component | File | Role |
|-----------|------|------|
| **Audio** | `Audio.gd` | Static wrapper class for global access |
| **AudioManager** | `AudioManager.gd` | Singleton handling playback with pooling |
| **SoundRegistry** | `SoundRegistry.gd` | Centralized sound ID → AudioStream mapping |

### 3. AudioManager Features
- **SFX Pool**: 16 pre-instantiated `AudioStreamPlayer` nodes prevent stutter
- **Pitch Variance**: Random 0.95-1.05 pitch for natural sound variety
- **BGM Crossfade**: 0.1s fade between music tracks
- **BGM Prewarming**: All BGM streams are touched on startup for instant playback
- **Looping**: OGG Vorbis streams are automatically set to loop

---

## Sound Registry (SoundRegistry.gd)

### Sound Categories

#### UI Sounds
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `ui_click` | Button press | `ui/click1.ogg` |
| `ui_hover` | Button hover/focus | `ui/switch1.ogg` |
| `ui_error` | Invalid action | `ui/error1.ogg` |
| `ui_window_open` | Window opens | `ui/drop.ogg` |
| `ui_window_close` | Window closes | `ui/click1.ogg` |

#### Action Sounds (New)
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `unit_hop` | Unit landing bounce | `action/hop.ogg` |
| `unit_toss` | Fast movement/lunge/toss | `action/whoosh.ogg` |
| `unit_land` | Unit lands on slot | `action/land.ogg` |
| `unit_buff` | Buff applied | `action/buff.ogg` |
| `combat_hit` | Damage dealt | `action/hit.ogg` |

#### Combat Sounds
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `combat_heal` | Healing effect | `action/buff.ogg` |
| `combat_buff` | Combat buff | `action/buff.ogg` |
| `combat_death` | Unit dies | `combat/step.ogg` |
| `combat_summon` | Unit summoned | `action/land.ogg` |

#### Inventory Sounds
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `ui_swap` | Items swapped | `action/whoosh.ogg` |
| `ui_merge` | Items merged/upgraded | `action/buff.ogg` |
| `ui_drag_start` | Drag begins | `action/whoosh.ogg` |
| `ui_drag_drop` | Drag ends | `action/land.ogg` |

#### Shop/Token Sounds
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `coin_land` | Coin animation | `shop/coin.ogg` |
| `token_spend` | Token spent | `shop/coin.ogg` |
| `token_land` | Token lands | `action/land.ogg` |

#### Minigame Sounds
| Sound ID | Description | Audio File |
|----------|-------------|------------|
| `minigame_correct` | Correct answer | `action/buff.ogg` |
| `minigame_incorrect` | Wrong answer | `ui/error1.ogg` |

### Background Music Tracks
| Constant | Scene | File |
|----------|-------|------|
| `BGM_TITLE` | Title screen | `bgm/title.ogg` |
| `BGM_LOADOUT` | Loadout selection | `bgm/loadout.ogg` |
| `BGM_PATHCHOICE` | Path choice | `bgm/pathchoice.ogg` |
| `BGM_BATTLE` | Combat | `bgm/battle.ogg` |
| `BGM_SHOP` | Shop scene | `bgm/shop.ogg` |
| `BGM_REST` | Rest site | `bgm/rest.ogg` |
| `BGM_REWARD` | Reward selection | `bgm/reward.ogg` |
| `BGM_MINIGAME` | Flashcard minigame | `bgm/minigame.ogg` |

---

## Integration Points

### Global Button Hover Sounds
`SceneManager.gd` automatically hooks all `Button` nodes via `get_tree().node_added` signal:
```gdscript
func _on_node_added(node: Node) -> void:
    if node is Button:
        node.mouse_entered.connect(_on_button_hovered)
        node.focus_entered.connect(_on_button_hovered)
```

### Combat Animation Sounds
`DamageAnimation.gd` handles melee attack sounds:
1. **Lunge start** → `Audio.play_sfx("unit_toss")` (whoosh)
2. **Impact** → `Audio.play_sfx("combat_hit")` (hit per target)

### Inventory Operations
`InventoryManager.gd` plays sounds for:
- `_swap()` → `Audio.play_sfx("ui_swap")`
- `_merge()` → `Audio.play_sfx("ui_merge")`
- `_move()` → `Audio.play_sfx("unit_land")`

### Unit Animations
`GachaBallView.gd` plays `unit_hop` in `_play_landing_bounce()` for all unit landing animations.

### Scene BGM
Each scene calls `Audio.play_music()` in its `_ready()`:
- `Title.gd` → `BGM_TITLE`
- `PathChoice.gd` → `BGM_PATHCHOICE`
- `BattleManager.gd` → `BGM_BATTLE`
- `Shop.gd` → `BGM_SHOP`
- `RestSite.gd` → `BGM_REST`
- `Reward.gd` → `BGM_REWARD`
- `FlashcardMinigame.gd` → `BGM_MINIGAME`

---

## Directory Structure
```
res://assets/audio/
├── bgm/
│   ├── title.ogg
│   ├── loadout.ogg
│   ├── pathchoice.ogg
│   ├── battle.ogg
│   ├── shop.ogg
│   ├── rest.ogg
│   ├── reward.ogg
│   └── minigame.ogg
└── sfx/
    ├── ui/
    │   ├── click1.ogg
    │   ├── switch1.ogg
    │   ├── error1.ogg
    │   └── drop.ogg
    ├── action/
    │   ├── hop.ogg
    │   ├── buff.ogg
    │   ├── land.ogg
    │   ├── hit.ogg
    │   └── whoosh.ogg
    ├── combat/
    │   ├── hit.ogg (legacy)
    │   └── step.ogg
    └── shop/
        └── coin.ogg
```

---

## Adding New Sounds

1. **Add the audio file** to the appropriate folder in `res://assets/audio/sfx/`
2. **Add a constant** in `SoundRegistry.gd`:
   ```gdscript
   const MY_NEW_SOUND = preload("res://assets/audio/sfx/folder/my_sound.ogg")
   ```
3. **Add to SOUNDS dictionary**:
   ```gdscript
   "my_sound_id": MY_NEW_SOUND,
   ```
4. **Call from code**:
   ```gdscript
   Audio.play_sfx("my_sound_id")
   ```
5. **Restart Godot** to import new audio files

---

## Asset Sources
All audio assets are **CC0 (Creative Commons Zero)** licensed:
- **Kenney.nl** - UI Audio, Casino Audio, RPG Audio packs
- **OpenGameArt.org** - Action sounds (hop, buff, land, hit, whoosh)
