class_name SoundRegistry
extends RefCounted

## Central registry for sound assets.
## Maps string IDs to AudioStream resources.

# UI SFX
const UI_CLICK = preload("res://assets/audio/sfx/ui/click1.ogg")
const UI_HOVER = preload("res://assets/audio/sfx/ui/switch1.ogg")
const UI_ERROR = preload("res://assets/audio/sfx/ui/error1.ogg")
const UI_DROP = preload("res://assets/audio/sfx/ui/drop.ogg")
const COIN_LAND = preload("res://assets/audio/sfx/shop/coin.ogg")

# Combat SFX (legacy)
const COMBAT_HIT_LEGACY = preload("res://assets/audio/sfx/combat/hit.ogg")
const COMBAT_STEP = preload("res://assets/audio/sfx/combat/step.ogg")

# Action SFX - New distinct sounds for various animations
const ACTION_HOP = preload("res://assets/audio/sfx/action/hop.ogg")
const ACTION_BUFF = preload("res://assets/audio/sfx/action/buff.ogg")
const ACTION_LAND = preload("res://assets/audio/sfx/action/land.ogg")
const ACTION_HIT = preload("res://assets/audio/sfx/action/hit.ogg")
const ACTION_WHOOSH = preload("res://assets/audio/sfx/action/whoosh.ogg")

# BGM - Each scene has its own track
const BGM_TITLE = preload("res://assets/audio/bgm/title.ogg")
const BGM_LOADOUT = preload("res://assets/audio/bgm/loadout.ogg")
const BGM_PATHCHOICE = preload("res://assets/audio/bgm/pathchoice.ogg")
const BGM_REST = preload("res://assets/audio/bgm/rest.ogg")
const BGM_REWARD = preload("res://assets/audio/bgm/reward.ogg")
const BGM_MINIGAME = preload("res://assets/audio/bgm/minigame.ogg")
const BGM_MENU = preload("res://assets/audio/bgm/menu.ogg") # Legacy/fallback
const BGM_BATTLE = preload("res://assets/audio/bgm/battle.ogg")
const BGM_SHOP = preload("res://assets/audio/bgm/shop.ogg")

## Sound Database - Comprehensive mapping
const SOUNDS: Dictionary = {
	# UI - Buttons & Interactions
	"ui_click": UI_CLICK,
	"ui_hover": UI_HOVER,
	"ui_error": UI_ERROR,
	"ui_select": UI_CLICK,
	"ui_deselect": UI_DROP,
	"ui_window_open": UI_DROP,
	"ui_window_close": UI_CLICK,
	"ui_rejection": UI_ERROR,
	"ui_heal": ACTION_BUFF,
	
	# Drag & Drop
	"ui_drag_start": ACTION_WHOOSH,
	"ui_drag_drop": ACTION_LAND,
	
	# Swap/Merge
	"ui_swap": ACTION_WHOOSH,
	"ui_merge": ACTION_BUFF,
	
	# Unit Animation SFX - Used globally via GachaBallView
	"unit_hop": ACTION_HOP, # When any unit hops (selection, landing, buff receive)
	"unit_land": ACTION_LAND, # When unit lands on a slot
	"unit_toss": ACTION_WHOOSH, # When unit/projectile is tossed
	"unit_buff": ACTION_BUFF, # When buff is applied
	
	# Combat
	"combat_hit": ACTION_HIT, # Damage dealt
	"combat_heal": ACTION_BUFF, # Healing
	"combat_buff": ACTION_BUFF, # Buff applied
	"combat_death": COMBAT_STEP,
	"combat_summon": ACTION_LAND,
	
	# Shop
	"shop_reroll": UI_CLICK,
	"shop_buy": COIN_LAND,
	"coin_spawn": COIN_LAND,
	"coin_land": COIN_LAND,
	
	# Token
	"token_spend": COIN_LAND,
	"token_land": ACTION_LAND,
	"plastic_clack": UI_CLICK,
	
	# Minigame
	"minigame_correct": ACTION_BUFF,
	"minigame_incorrect": UI_ERROR,
	
	# BGM (keys for convenience)
	"bgm_menu": BGM_MENU,
	"bgm_battle": BGM_BATTLE,
	"bgm_shop": BGM_SHOP
}

static func get_stream(sound_id: String) -> AudioStream:
	return SOUNDS.get(sound_id)
