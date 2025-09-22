# scriptor : Chua Yun Sheng
# studentID: 2202740
# function : controls the function of the gun.
#			 allowing firing, which lauch the player 
#			 and individual reloading, which refills the ammo one by one
extends Node2D

var player: CharacterBody2D
var ammo_ui
var launch_count := 0
const MAX_LAUNCHES := 3  # magazine size
var mouse_was_pressed := false
var can_launch := true
var is_reloading := false
var is_firing := false   # Prevents default from overriding fire

@onready var fire_sound: AudioStreamPlayer2D = $FireSound
@onready var reload_sound: AudioStreamPlayer2D = $ReloadSound
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Save original transform so we can reset later
var default_position: Vector2

@onready var reload_timer: Timer = Timer.new()

func _ready():
	# Store defaults
	default_position = sprite.position

	# Find Player node
	for node in get_tree().get_root().get_children():
		if node.has_node("Player"):
			player = node.get_node("Player") as CharacterBody2D

	# Find Ammo UI node
	for node in get_tree().get_root().get_children():
		if node.has_node("Ammo"): 
			ammo_ui = node.get_node("Ammo")

	# Setup reload timer
	reload_timer.wait_time = 0.5   # 🔹 0.5s per bullet
	reload_timer.one_shot = true
	reload_timer.name = "ReloadTimer"
	add_child(reload_timer)
	reload_timer.connect("timeout", Callable(self, "_on_reload_timer_timeout"))

	# Connect animation finished
	sprite.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle() + deg_to_rad(90)

	# Only idle if not firing
	if not is_firing:
		sprite.play("default")

	var mouse_now = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# Shooting logic
	if mouse_now and not mouse_was_pressed and launch_count < MAX_LAUNCHES and can_launch and not is_reloading:
		if player and player.has_method("apply_launch"):
			var direction = (mouse_pos - player.global_position).normalized()
			var force = -direction * 900.0
			player.apply_launch(force)
			launch_count += 1
			print("Fire", launch_count)

			if ammo_ui:
				ammo_ui.shoot()

		# Play fire once from start
		sprite.play("fire")
		sprite.frame = 0
		sprite.position = Vector2(1, -40)     # 🔹 Shift fire
		is_firing = true
		
		if fire_sound:
			fire_sound.play()

	mouse_was_pressed = mouse_now

	# Manual reload (only if not full)
	if Input.is_action_just_pressed("reload") and not is_reloading and launch_count > 0:
		is_reloading = true
		can_launch = false
		print("Reloading...")
		_reload_one_bullet()   # start reloading loop

func _reload_one_bullet():
	# Reload one  bullet
	if launch_count > 0:
		launch_count -= 1
		print("Reloaded 1 bullet, remaining spent:", launch_count)

		if ammo_ui:
			ammo_ui.reload()
		if reload_sound:
			reload_sound.play()

		# Keep going until fully reloaded
		reload_timer.start()
	else:
		# Reload complete
		is_reloading = false
		can_launch = true
		print("Reload complete!")

func _on_reload_timer_timeout():
	_reload_one_bullet()

func _on_animation_finished():
	# When fire ends, return to idle and reset transform
	if sprite.animation == "fire":
		is_firing = false
		sprite.play("default")
		sprite.position = default_position    # 🔹 Reset position
