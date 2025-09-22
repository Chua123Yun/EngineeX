# scriptor : Chua Kek Yang
# studentID: 2103936
# function : Implements a proximity-triggered acid pool hazard. The pool is hidden until the player enters the TriggerArea,
#           then fades in, enables its Killbox, and executes a multi-step splash pattern (Up→Left→DownSmall→Up→Right→DownFull,
#           repeated for a set number of cycles) by tweening an Offset wrapper so hitboxes move correctly. Any player
#           touching the Killbox is killed (or damaged), and the trap despawns after the sequence.

extends Node2D

# --- motion pattern ---
@export var cycles: int = 3
@export var up_height: float = 36.0
@export var horiz: float = 40.0
@export var down_small: float = 12.0
@export var down_full: float = 28.0
@export var step_time: float = 0.12

# --- reveal behavior ---
@export var hidden_until_trigger: bool = true
@export var reveal_fade_time: float = 0.12  # fade-in time for sprite

# --- damage behavior ---
@export var kill_on_trigger: bool = false   # also hurt on approach (TriggerArea)
@export var instant_kill: bool = true
@export var damage: int = 9999

# --- nodes ---
@onready var offset: Node2D        = $Offset
@onready var sprite: Sprite2D      = $Offset/Sprite2D
@onready var trigger_area: Area2D  = $Offset/TriggerArea
@onready var killbox: Area2D       = $Offset/Killbox

# --- state ---
var _center: Vector2
var _started := false
var _revealed := false

func _ready() -> void:
	_center = offset.position

	# auto-connect like your rock/spike
	if not trigger_area.body_entered.is_connected(_on_trigger_area_body_entered):
		trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	if not killbox.body_entered.is_connected(_on_killbox_body_entered):
		killbox.body_entered.connect(_on_killbox_body_entered)

	# start hidden + safe
	if hidden_until_trigger:
		sprite.visible = false
		# keep trigger active so it can detect
		killbox.monitoring = false   # no killing while invisible
	else:
		_reveal_now()                 # visible immediately

func _on_trigger_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	_reveal_now()
	_start_sequence_once()
	if kill_on_trigger:
		_hurt(body)

func _on_killbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# If, for any reason, reveal didn't happen yet, do it now before hurting.
	if not _revealed:
		_reveal_now()
	_start_sequence_once()
	_hurt(body)

func _reveal_now() -> void:
	if _revealed:
		return
	_revealed = true

	# turn on killbox only after reveal
	killbox.monitoring = true

	# show sprite (fade in nicely)
	if hidden_until_trigger:
		sprite.visible = true
		var mod := sprite.modulate
		mod.a = 0.0
		sprite.modulate = mod
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, reveal_fade_time)

func _start_sequence_once() -> void:
	if _started:
		return
	_started = true
	offset.position = _center
	_play_pattern_then_free()

func _play_pattern_then_free() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)

	var cur := _center
	for i in range(cycles):
		# Up
		t.set_ease(Tween.EASE_OUT)
		cur = Vector2(_center.x, _center.y - up_height)
		t.tween_property(offset, "position", cur, step_time)

		# Left
		t.set_ease(Tween.EASE_IN_OUT)
		cur = Vector2(_center.x - horiz, cur.y)
		t.tween_property(offset, "position", cur, step_time)

		# Down small
		t.set_ease(Tween.EASE_IN)
		cur = Vector2(cur.x, _center.y + down_small)
		t.tween_property(offset, "position", cur, step_time)

		# Back Up
		t.set_ease(Tween.EASE_OUT)
		cur = Vector2(cur.x, _center.y - up_height)
		t.tween_property(offset, "position", cur, step_time)

		# Right
		t.set_ease(Tween.EASE_IN_OUT)
		cur = Vector2(_center.x + horiz, cur.y)
		t.tween_property(offset, "position", cur, step_time)

		# Down full
		t.set_ease(Tween.EASE_IN)
		cur = Vector2(cur.x, _center.y + down_full)
		t.tween_property(offset, "position", cur, step_time)

	# finish → despawn
	t.finished.connect(func(): queue_free())

func _hurt(body: Node2D) -> void:
	if instant_kill and body.has_method("die"):
		body.die(); return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("die"):
		body.die()
	else:
		body.queue_free()
