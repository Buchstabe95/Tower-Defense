class_name EnemyData
extends RefCounted

var position: Vector2
var hp: float
var max_hp: float
var speed: float
var radius: float
var reward: int
var elite: bool

func _init(
	start_position: Vector2,
	start_hp: float,
	start_speed: float,
	start_radius: float,
	start_reward: int,
	is_elite: bool
) -> void:
	position = start_position
	hp = start_hp
	max_hp = start_hp
	speed = start_speed
	radius = start_radius
	reward = start_reward
	elite = is_elite
