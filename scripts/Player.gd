# scriptor : Chua Yun Sheng
# studentID : 2202740
# function : controls the functions of the player,
#            like movement speed, glide speed and gravity,
#            launch deceleration, death effects,
# 
# scriptor : Chua Kek Yang
# studentID : 2103936
# function : set Invulnerability state after respawned, and adds dash.        

extends CharacterBody2D

@export var speed: float = 600
@export var normal_gravity: float = 900
@export var glide_gravity: float = 400  # Lower gravity for gliding
@export var launch_strength: float = 300
@export var stop_threshold: float = 10.0
@export var deceleration: float = 0.985

# --- spawn effects & invulnerability ---
@export var respawn_invuln_seconds: float = 2.0
@export var blink_min_alpha: float = 0.35     # transparency during blink
@export var blink_step: float = 0.1           # seconds per blink half-cycle
@export var spawn_shake_amp: float = 6.0
@export var spawn_shake_dur: float = 0.35

# --- DASH (press W) ---
@export var dash_speed: float = 1000.0        # strength of dash
@export var dash_cooldown: float = 2.0        # seconds before next dash
@export var dash_air_ok: bool = true          # allow dash in air
@export var dash_vertical: bool = false       # set true to dash UP with W instead of forward

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var in_launch: bool = false
var is_dead: bool = false
var drop_timer: float = 0.0

# invulnerability state
var invulnerable: bool = false
var _blink_tween: Tween

# dash state
var _dash_cd := 0.0
var _last_dir := 1.0

func _ready() -> void:
	# Ensure 'dash' action exists and is bound to W
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)

	# Spawn effects
	_camera_shake_on_spawn()
	_start_invulnerability(respawn_invuln_seconds)

func apply_launch(force: Vector2) -> void:
	velocity = force
	in_launch = true

func _physics_process(delta: float) -> void:
	var direction: float = 0.0

	if Input.is_action_pressed("a"):
		direction -= 1.0
	if Input.is_action_pressed("d"):
		direction += 1.0
	if Input.is_action_pressed("restart"):
		call_deferred("die") 

	# Track last facing for forward dash
	var face_dir := direction
	if face_dir == 0.0 and is_instance_valid(sprite):
		face_dir = -1.0 if sprite.flip_h else 1.0
	_last_dir = face_dir if face_dir != 0.0 else _last_dir

	# --- DASH: trigger on W (action "dash") ---
	_dash_cd = max(_dash_cd - delta, 0.0)
	if Input.is_action_just_pressed("dash") and _dash_cd == 0.0 and (is_on_floor() or dash_air_ok):
		var launch_vec := Vector2(_last_dir * dash_speed, 0.0)
		if dash_vertical:
			launch_vec = Vector2(0.0, -dash_speed)
		apply_launch(launch_vec)
		_dash_cd = dash_cooldown
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("shake"):
			cam.call("shake", 5.0, 0.2)

	# --- Dash cooldown visual feedback (bright blue) ---
	if _dash_cd > 0.0:
		sprite.modulate = Color(0.3, 0.6, 1.0, 1.0)  # bright blue
	else:
		sprite.modulate = Color(1, 1, 1, 1)          # normal

	# Animation state
	if direction != 0:
		sprite.play("walk")
		sprite.flip_h = direction < 0
	else:
		sprite.play("idle")

	# Choose gravity based on spacebar press in air
	var current_gravity = normal_gravity
	if Input.is_action_pressed("spacebar") and not is_on_floor():
		current_gravity = glide_gravity 

	# Apply gravity when not grounded
	if not is_on_floor():
		velocity.y += current_gravity * delta

	if in_launch:
		# Add control influence on top of launch movement
		var input_force: float = direction * 400 * delta
		velocity.x += input_force

		# Apply launch damping toward stopping
		velocity = velocity.move_toward(Vector2(velocity.x, 0), launch_strength * delta)

		# Stop launch if mostly still and grounded
		if is_on_floor() and velocity.length() <= stop_threshold:
			velocity = Vector2.ZERO

		if is_on_floor() and velocity.length() < 10000.0:
			velocity = velocity * deceleration

		if is_on_floor() and velocity.length() <= 0.0:
			in_launch = false
	else:
		# Normal grounded movement
		velocity.x = direction * speed

	move_and_slide()

func die():
	if is_dead or invulnerable:
		return  # Ignore extra calls
	is_dead = true

	print("Player died! Respawning...")
	sprite.modulate = Color(1, 0, 0)  # Flash red

	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)  # Reset color

	call_deferred("_reload_scene")

func _reload_scene():
	get_tree().reload_current_scene()

# =========================
# Invulnerability + Blink
# =========================
func _start_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return
	invulnerable = true
	_start_blink()
	await get_tree().create_timer(duration).timeout
	_end_invulnerability()

func _end_invulnerability() -> void:
	invulnerable = false
	_stop_blink()

func _start_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.set_loops()
	_blink_tween.tween_property(sprite, "modulate:a", blink_min_alpha, blink_step)
	_blink_tween.tween_property(sprite, "modulate:a", 1.0, blink_step)

func _stop_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	sprite.modulate = Color(1, 1, 1, 1)

# =========================
# Camera shake on spawn
# =========================
func _camera_shake_on_spawn() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.call("shake", spawn_shake_amp, spawn_shake_dur)
