<!-- Original: scripts/NodeView.gd -->

```gdscript
extends Button

signal node_selected(node_def)

var _node_def

func populate(node_def):
	_node_def = node_def
	text = node_def.display_name_key
	# Allow both BATTLE and SHOP nodes to be enabled.
	disabled = not (node_def.node_type == "BATTLE" or node_def.node_type == "SHOP")

func _on_pressed():
	emit_signal("node_selected", _node_def)

func _ready():
	self.pressed.connect(_on_pressed) 
```