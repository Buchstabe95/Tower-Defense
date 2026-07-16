class_name TowerData
extends RefCounted

var spot_index: int
var position: Vector2
var damage: float
var attack_range: float
var base_cooldown: float
var cooldown: float

func _init(index: int, tower_position: Vector2) -> void:
	spot_index = index
	position = tower_position
	damage = 22.0
	attack_range = 170.0
	base_cooldown = 0.80
	cooldown = 0.10
