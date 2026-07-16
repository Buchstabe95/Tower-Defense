extends Node2D

const SCREEN_SIZE := Vector2(1280, 720)
const PATH_Y := 360.0
const START_X := -40.0
const END_X := 1320.0

var gold := 250
var lives := 20
var score := 0
var level := 1
var xp := 0
var xp_needed := 80

var spawn_timer := 0.0
var spawn_interval := 1.25
var difficulty_time := 0.0
var paused_for_levelup := false
var game_over := false

var enemies: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []

var tower_damage_multiplier := 1.0
var tower_range_multiplier := 1.0
var tower_speed_multiplier := 1.0

var build_spots := [
	Vector2(180, 230), Vector2(340, 490), Vector2(500, 230),
	Vector2(660, 490), Vector2(820, 230), Vector2(980, 490),
	Vector2(1140, 230)
]

var hovered_spot := -1
var selected_choices: Array[Dictionary] = []

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if game_over:
		queue_redraw()
		return

	if paused_for_levelup:
		queue_redraw()
		return

	difficulty_time += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_enemy()
		var scaling := min(difficulty_time / 180.0, 0.55)
		spawn_interval = max(0.45, 1.25 - scaling)
		spawn_timer = spawn_interval

	update_enemies(delta)
	update_towers(delta)
	update_projectiles(delta)
	queue_redraw()

func spawn_enemy() -> void:
	var hp_scale := 1.0 + difficulty_time * 0.025
	var speed_scale := 1.0 + difficulty_time * 0.0018
	var elite := randf() < min(0.04 + difficulty_time / 900.0, 0.18)

	var hp := 42.0 * hp_scale
	var radius := 15.0
	var reward := 12

	if elite:
		hp *= 3.2
		radius = 22.0
		reward = 36

	enemies.append({
		"pos": Vector2(START_X, PATH_Y),
		"hp": hp,
		"max_hp": hp,
		"speed": 62.0 * speed_scale,
		"radius": radius,
		"reward": reward,
		"elite": elite
	})

func update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		enemies[i]["pos"].x += enemies[i]["speed"] * delta
		if enemies[i]["pos"].x >= END_X:
			enemies.remove_at(i)
			lives -= 1
			if lives <= 0:
				game_over = true

func update_towers(delta: float) -> void:
	for tower in towers:
		tower["cooldown"] -= delta
		if tower["cooldown"] > 0.0:
			continue

		var target_index := find_target(tower["pos"], tower["range"] * tower_range_multiplier)
		if target_index == -1:
			continue

		var target_pos: Vector2 = enemies[target_index]["pos"]
		projectiles.append({
			"pos": tower["pos"],
			"target_index": target_index,
			"damage": tower["damage"] * tower_damage_multiplier,
			"speed": 520.0
		})
		tower["cooldown"] = tower["base_cooldown"] / tower_speed_multiplier

func find_target(origin: Vector2, max_range: float) -> int:
	var best := -1
	var best_progress := -INF
	for i in enemies.size():
		var enemy_pos: Vector2 = enemies[i]["pos"]
		if origin.distance_to(enemy_pos) <= max_range and enemy_pos.x > best_progress:
			best = i
			best_progress = enemy_pos.x
	return best

func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var target_index: int = p["target_index"]

		if target_index < 0 or target_index >= enemies.size():
			projectiles.remove_at(i)
			continue

		var target_pos: Vector2 = enemies[target_index]["pos"]
		var direction := p["pos"].direction_to(target_pos)
		p["pos"] += direction * p["speed"] * delta
		projectiles[i] = p

		if p["pos"].distance_to(target_pos) < 12.0:
			enemies[target_index]["hp"] -= p["damage"]
			projectiles.remove_at(i)

			if enemies[target_index]["hp"] <= 0.0:
				var reward: int = enemies[target_index]["reward"]
				enemies.remove_at(target_index)
				gold += reward
				score += reward
				add_xp(reward)
				repair_projectile_indices(target_index)

func repair_projectile_indices(removed_enemy_index: int) -> void:
	for p in projectiles:
		if p["target_index"] > removed_enemy_index:
			p["target_index"] -= 1
		elif p["target_index"] == removed_enemy_index:
			p["target_index"] = -1

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(xp_needed * 1.28)
		open_level_up()

func open_level_up() -> void:
	paused_for_levelup = true
	selected_choices = get_random_choices(3)

func get_random_choices(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{"title": "Stärkere Geschosse", "text": "Alle Türme verursachen 20 % mehr Schaden.", "type": "damage", "value": 1.20},
		{"title": "Grössere Reichweite", "text": "Alle Türme erhalten 18 % mehr Reichweite.", "type": "range", "value": 1.18},
		{"title": "Schneller Angriff", "text": "Alle Türme greifen 16 % schneller an.", "type": "speed", "value": 1.16},
		{"title": "Kriegsbeute", "text": "Du erhältst sofort 140 Gold.", "type": "gold", "value": 140},
		{"title": "Verstärkte Befestigung", "text": "Du erhältst 3 zusätzliche Leben.", "type": "lives", "value": 3}
	]
	pool.shuffle()
	return pool.slice(0, count)

func apply_choice(choice: Dictionary) -> void:
	match choice["type"]:
		"damage":
			tower_damage_multiplier *= float(choice["value"])
		"range":
			tower_range_multiplier *= float(choice["value"])
		"speed":
			tower_speed_multiplier *= float(choice["value"])
		"gold":
			gold += int(choice["value"])
		"lives":
			lives += int(choice["value"])
	paused_for_levelup = false
	selected_choices.clear()

func try_build_tower(spot_index: int) -> void:
	if game_over or paused_for_levelup:
		return

	for tower in towers:
		if tower["spot"] == spot_index:
			return

	if gold < 100:
		return

	gold -= 100
	towers.append({
		"spot": spot_index,
		"pos": build_spots[spot_index],
		"damage": 22.0,
		"range": 170.0,
		"base_cooldown": 0.80,
		"cooldown": 0.1
	})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_spot = get_spot_at(event.position)
		queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if game_over:
			restart_game()
			return

		if paused_for_levelup:
			var choice_index := get_choice_at(event.position)
			if choice_index >= 0:
				apply_choice(selected_choices[choice_index])
			return

		var spot := get_spot_at(event.position)
		if spot >= 0:
			try_build_tower(spot)

func get_spot_at(mouse_pos: Vector2) -> int:
	for i in build_spots.size():
		if build_spots[i].distance_to(mouse_pos) <= 34.0:
			return i
	return -1

func get_choice_at(mouse_pos: Vector2) -> int:
	for i in selected_choices.size():
		var rect := Rect2(210 + i * 300, 260, 260, 190)
		if rect.has_point(mouse_pos):
			return i
	return -1

func restart_game() -> void:
	gold = 250
	lives = 20
	score = 0
	level = 1
	xp = 0
	xp_needed = 80
	spawn_timer = 0.0
	spawn_interval = 1.25
	difficulty_time = 0.0
	paused_for_levelup = false
	game_over = false
	enemies.clear()
	towers.clear()
	projectiles.clear()
	tower_damage_multiplier = 1.0
	tower_range_multiplier = 1.0
	tower_speed_multiplier = 1.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("#18231c"))

	# Weg
	draw_rect(Rect2(0, PATH_Y - 44, SCREEN_SIZE.x, 88), Color("#6b5a42"))
	draw_line(Vector2(0, PATH_Y - 44), Vector2(SCREEN_SIZE.x, PATH_Y - 44), Color("#9a8768"), 3)
	draw_line(Vector2(0, PATH_Y + 44), Vector2(SCREEN_SIZE.x, PATH_Y + 44), Color("#9a8768"), 3)

	# Bauplätze
	for i in build_spots.size():
		var occupied := false
		for tower in towers:
			if tower["spot"] == i:
				occupied = true
				break

		var c := Color("#4c6654")
		if i == hovered_spot and not occupied:
			c = Color("#7da66f")
		if occupied:
			c = Color("#34463a")
		draw_circle(build_spots[i], 30.0, c)
		draw_arc(build_spots[i], 30.0, 0, TAU, 36, Color("#a8c3ad"), 2.0)

	# Türme und Reichweite
	for tower in towers:
		if tower["spot"] == hovered_spot:
			draw_circle(tower["pos"], tower["range"] * tower_range_multiplier, Color(0.35, 0.7, 0.45, 0.10))
			draw_arc(tower["pos"], tower["range"] * tower_range_multiplier, 0, TAU, 64, Color(0.45, 0.85, 0.55, 0.40), 2)
		draw_rect(Rect2(tower["pos"] - Vector2(18, 18), Vector2(36, 36)), Color("#d7c48c"))
		draw_circle(tower["pos"], 9, Color("#384635"))

	# Gegner
	for enemy in enemies:
		var pos: Vector2 = enemy["pos"]
		var radius: float = enemy["radius"]
		var col := Color("#bd4a45") if not enemy["elite"] else Color("#7f3fa4")
		draw_circle(pos, radius, col)
		var hp_ratio: float = max(0.0, enemy["hp"] / enemy["max_hp"])
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 11), Vector2(radius * 2, 5)), Color("#2a211f"))
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 11), Vector2(radius * 2 * hp_ratio, 5)), Color("#70b85d"))

	# Projektile
	for projectile in projectiles:
		draw_circle(projectile["pos"], 5.0, Color("#f2de83"))

	# HUD
	draw_rect(Rect2(0, 0, SCREEN_SIZE.x, 74), Color(0.05, 0.07, 0.06, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(26, 45), "Gold: %d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(190, 45), "Leben: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(350, 45), "Level: %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(520, 45), "Punkte: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

	var xp_ratio := float(xp) / float(xp_needed)
	draw_rect(Rect2(760, 24, 470, 18), Color("#2d332f"))
	draw_rect(Rect2(760, 24, 470 * xp_ratio, 18), Color("#6d9e63"))
	draw_string(ThemeDB.fallback_font, Vector2(760, 64), "Erfahrung %d / %d" % [xp, xp_needed], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d5ddd6"))

	draw_string(ThemeDB.fallback_font, Vector2(24, 700), "Klicke auf einen Bauplatz. Turm kostet 100 Gold.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d6dfd8"))

	if paused_for_levelup:
		draw_level_up_overlay()

	if game_over:
		draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.02, 0.02, 0.02, 0.76))
		draw_string(ThemeDB.fallback_font, Vector2(0, 290), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 56, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(0, 350), "Punkte: %d   Level: %d" % [score, level], HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 28, Color("#d9ddd8"))
		draw_string(ThemeDB.fallback_font, Vector2(0, 420), "Klicken, um neu zu starten", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 22, Color("#a9c7ad"))

func draw_level_up_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.02, 0.02, 0.02, 0.78))
	draw_string(ThemeDB.fallback_font, Vector2(0, 150), "LEVEL AUFSTIEG", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 48, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(0, 195), "Wähle eine Verbesserung für alle Türme", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 22, Color("#cfd8d0"))

	for i in selected_choices.size():
		var rect := Rect2(210 + i * 300, 260, 260, 190)
		var hovered := rect.has_point(get_viewport().get_mouse_position())
		draw_rect(rect, Color("#34463a") if not hovered else Color("#496553"))
		draw_rect(rect, Color("#a7c7ad"), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 45), selected_choices[i]["title"], HORIZONTAL_ALIGNMENT_LEFT, 225, 23, Color.WHITE)
		draw_multiline_string(ThemeDB.fallback_font, rect.position + Vector2(18, 85), selected_choices[i]["text"], HORIZONTAL_ALIGNMENT_LEFT, 225, 18, 3, Color("#dce5dd"))
