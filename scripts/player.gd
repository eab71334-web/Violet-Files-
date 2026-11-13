class_name Player
extends CharacterBody3D
## First-person detective. Touch: left side = move stick, right side = look. Desktop: WASD + right-mouse drag.
## A ray from the camera finds hotspots (StaticBody3D on layer 2 with meta "id" / "label").

signal hotspot_changed(h)

const SPEED := 2.4

var enabled := true
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var stick_touch := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var look_touch := -1
var block_rects_provider: Callable      # returns Array[Rect2] of UI buttons to ignore
var hotspot: Node = null

var _head: Node3D
var _ray: RayCast3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.55, 0)
	add_child(_head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.current = true
	_head.add_child(cam)
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -2.8)
	_ray.collision_mask = 2
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	cam.add_child(_ray)


func _blocked(p: Vector2) -> bool:
	if block_rects_provider.is_valid():
		for r in block_rects_provider.call():
			if (r as Rect2).has_point(p):
				return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if _blocked(p):
				return
			var w := get_viewport().get_visible_rect().size.x
			if p.x < w * 0.45 and stick_touch == -1:
				stick_touch = event.index
				stick_origin = p
				stick_vec = Vector2.ZERO
			elif p.x >= w * 0.45 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == stick_touch:
				stick_touch = -1
				stick_vec = Vector2.ZERO
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_touch:
			stick_vec = ((event.position - stick_origin) / 110.0).limit_length(1.0)
		elif event.index == look_touch:
			_look(event.relative * 0.0042)
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_look(event.relative * 0.003)


func _look(rel: Vector2) -> void:
	yaw -= rel.x
	pitch = clampf(pitch - rel.y, -1.2, 1.2)


func release_touches() -> void:
	stick_touch = -1
	look_touch = -1
	stick_vec = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	rotation.y = yaw
	_head.rotation.x = pitch
	var dir := Vector2.ZERO
	if enabled:
		dir = stick_vec
		if Input.is_key_pressed(KEY_W): dir.y -= 1.0
		if Input.is_key_pressed(KEY_S): dir.y += 1.0
		if Input.is_key_pressed(KEY_A): dir.x -= 1.0
		if Input.is_key_pressed(KEY_D): dir.x += 1.0
		dir = dir.limit_length(1.0)
	var mv := transform.basis * Vector3(dir.x, 0.0, dir.y) * SPEED
	velocity = Vector3(mv.x, 0.0, mv.z)
	move_and_slide()
	global_position.y = 0.0
	var h: Node = null
	if enabled and _ray.is_colliding():
		var c = _ray.get_collider()
		if c != null and c.has_meta("id"):
			h = c
	if h != hotspot:
		hotspot = h
		hotspot_changed.emit(h)
