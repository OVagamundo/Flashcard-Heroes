<!-- Original: resources/reward_pool.tres -->

```ini
[gd_resource type="Resource" script_class="RewardPool" load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/RewardPool.gd" id="1_script"]
[ext_resource type="Resource" path="res://resources/units/UnitTier1A.tres" id="2"]
[ext_resource type="Resource" path="res://resources/units/UnitTier1B.tres" id="3"]
[ext_resource type="Resource" path="res://resources/units/UnitTier2C.tres" id="4"]
[ext_resource type="Resource" path="res://resources/units/UnitTier3D.tres" id="5"]
[ext_resource type="Resource" path="res://resources/items/ItemTier1A.tres" id="6"]
[ext_resource type="Resource" path="res://resources/items/ItemTier1B.tres" id="7"]
[ext_resource type="Resource" path="res://resources/items/ItemTier2C.tres" id="8"]
[ext_resource type="Resource" path="res://resources/items/ItemTier3D.tres" id="9"]

[resource]
script = ExtResource("1_script")
definitions = [ExtResource("2"), ExtResource("3"), ExtResource("4"), ExtResource("5"), ExtResource("6"), ExtResource("7"), ExtResource("8"), ExtResource("9")]
```