class_name ProjectileData
extends RefCounted

var position: Vector2
var target: EnemyData
var damage: float
var speed: float

func _init(
	start_position: Vector2,
	target_enemy: EnemyData,
	projectile_damage: float
) -> void:
	position = start_position
	target = target_enemy
	damage = projectile_damage
	speed = 520.0
