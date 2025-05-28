extends Resource
class_name UnitResource

@export var id: String
@export var display_name: String
@export var max_health: int
@export var attack: int
@export var defense: int
@export var speed: int
@export var abilities: Array[String] = []
@export var texture: Texture2D
@export var team: String = "player"  # "player" or "enemy"

func _init(p_id = "", p_name = "", p_health = 10, p_attack = 2, p_defense = 1, p_speed = 1, p_texture = null):
    id = p_id
    display_name = p_name
    max_health = p_health
    attack = p_attack
    defense = p_defense
    speed = p_speed
    texture = p_texture
