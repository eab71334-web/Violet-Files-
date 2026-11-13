class_name BlockyPerson
extends Node3D
## Low-poly blocky character built from boxes, with the "hidden tension" tells from the design
## document: blinking, sweat, looking away, fidgeting hands, pen tapping (Salma's tell).
## Front of the model is +Z.

var tension := 0.0           # 0..100, drives the tells
var blink_mult := 1.0        # nervous honest people blink a lot (Abu Firas)
var pen_tell := false        # Salma touches her pen when lying
var emotion := "neutral"     # neutral / angry / worried
var talking := false
var typing := false
var sitting := false
var walking := false
var look_target: Node3D

var _body: Node3D
var _torso: MeshInstance3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _lid_l: Node3D
var _lid_r: Node3D
var _brow_l: MeshInstance3D
var _brow_r: MeshInstance3D
var _mouth: MeshInstance3D
var _sweat: MeshInstance3D
var _pen: MeshInstance3D
var _t := 0.0
var _blink_cd := 2.0
var _blink_ph := 1.0
var _avoid_sign := 1.0
var _walk_phase := 0.0
var _talk_left := 0.0
var _sit_amt := 0.0


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func build(cfg: Dictionary) -> void:
	var skin: Color = cfg.get("skin", Color("c99a7a"))
	var shirt: Color = cfg.get("shirt", Color("445577"))
	var pants: Color = cfg.get("pants", Color("22232b"))
	var hair: Color = cfg.get("hair", Color("1a1410"))
	var belly: float = cfg.get("belly", 1.0)
	blink_mult = cfg.get("blink_mult", 1.0)
	pen_tell = cfg.get("pen", false)
	_avoid_sign = -1.0 if randf() < 0.5 else 1.0
	_body = _pivot(self, Vector3.ZERO)
	_torso = _box(_body, Vector3(0, 1.1, 0), Vector3(0.44, 0.62, 0.26 * belly), shirt)
	if cfg.has("tie"):
		_box(_body, Vector3(0, 1.12, 0.13 * belly + 0.005), Vector3(0.06, 0.4, 0.01), cfg["tie"])
	_box(_body, Vector3(0, 0.84, 0), Vector3(0.42, 0.14, 0.24), pants)
	# legs: thigh pivot at the hip, shin pivot at the knee
	for side in [-1, 1]:
		var th := _pivot(_body, Vector3(0.11 * side, 0.8, 0))
		_box(th, Vector3(0, -0.2, 0), Vector3(0.17, 0.4, 0.19), pants)
		var kn := _pivot(th, Vector3(0, -0.4, 0))
		_box(kn, Vector3(0, -0.2, 0), Vector3(0.15, 0.4, 0.17), pants)
		_box(kn, Vector3(0, -0.42, 0.04), Vector3(0.16, 0.07, 0.26), Color("111114"))
		if side < 0:
			_thigh_l = th
			_knee_l = kn
		else:
			_thigh_r = th
			_knee_r = kn
	# arms hang from the shoulders
	for side in [-1, 1]:
		var ar := _pivot(_body, Vector3(0.28 * side, 1.38, 0))
		_box(ar, Vector3(0, -0.28, 0), Vector3(0.12, 0.56, 0.12), shirt)
		_box(ar, Vector3(0, -0.6, 0), Vector3(0.1, 0.1, 0.1), skin)
		if side < 0:
			_arm_l = ar
		else:
			_arm_r = ar
			if pen_tell:
				_pen = _box(ar, Vector3(0, -0.62, 0.08), Vector3(0.02, 0.02, 0.15), Color("d7263d"))
	# head
	_head = _pivot(_body, Vector3(0, 1.43, 0))
	_box(_head, Vector3(0, 0.15, 0), Vector3(0.26, 0.28, 0.26), skin)
	_box(_head, Vector3(0, 0.07, 0.135), Vector3(0.04, 0.05, 0.03), skin.darkened(0.08))   # nose
	var style: String = cfg.get("hair_style", "short")
	if style == "short":
		_box(_head, Vector3(0, 0.3, -0.01), Vector3(0.28, 0.06, 0.28), hair)
		_box(_head, Vector3(0, 0.2, -0.14), Vector3(0.28, 0.2, 0.04), hair)
	elif style == "long":
		_box(_head, Vector3(0, 0.3, -0.01), Vector3(0.29, 0.07, 0.29), hair)
		_box(_head, Vector3(0, 0.1, -0.14), Vector3(0.29, 0.5, 0.05), hair)
		_box(_head, Vector3(0.14, 0.12, -0.02), Vector3(0.03, 0.4, 0.2), hair)
		_box(_head, Vector3(-0.14, 0.12, -0.02), Vector3(0.03, 0.4, 0.2), hair)
	elif style == "cap":
		_box(_head, Vector3(0, 0.3, 0), Vector3(0.28, 0.07, 0.28), hair)
		_box(_head, Vector3(0, 0.27, 0.16), Vector3(0.28, 0.02, 0.1), hair)
	for side in [-1, 1]:
		var ex: float = 0.06 * side
		_box(_head, Vector3(ex, 0.17, 0.132), Vector3(0.045, 0.04, 0.01), Color("101015"))
		var lid := _pivot(_head, Vector3(ex, 0.2, 0.136))
		_box(lid, Vector3(0, -0.03, 0), Vector3(0.055, 0.06, 0.008), skin)
		lid.scale.y = 0.0
		var br := _box(_head, Vector3(ex, 0.235, 0.135), Vector3(0.07, 0.013, 0.01), hair.darkened(0.2))
		if side < 0:
			_lid_l = lid
			_brow_l = br
		else:
			_lid_r = lid
			_brow_r = br
	_mouth = _box(_head, Vector3(0, 0.065, 0.133), Vector3(0.08, 0.012, 0.01), Color("5a2a2a"))
	if cfg.get("mustache", false):
		_box(_head, Vector3(0, 0.1, 0.136), Vector3(0.13, 0.025, 0.012), hair)
	if cfg.get("glasses", false):
		for side in [-1, 1]:
			_box(_head, Vector3(0.06 * side, 0.17, 0.14), Vector3(0.085, 0.06, 0.006), Color(0.03, 0.03, 0.04, 1))
			_box(_head, Vector3(0.06 * side, 0.17, 0.145), Vector3(0.06, 0.04, 0.004), Color("6e4bd6"))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.6, 0.8, 1.0)
	sm.emission_enabled = true
	sm.emission = Color(0.5, 0.7, 1.0)
	_sweat = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.05, 0.012)
	_sweat.mesh = bm
	_sweat.material_override = sm
	_sweat.position = Vector3(0.1, 0.22, 0.135)
	_sweat.visible = false
	_head.add_child(_sweat)


# ---------------------------------------------------------------- actions
func speak(seconds: float) -> void:
	_talk_left = maxf(_talk_left, seconds)


func face_pos(p: Vector3, dur := 0.35) -> void:
	var d := p - global_position
	var yaw := atan2(d.x, d.z)
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", lerp_angle(rotation.y, yaw, 1.0), dur)


func sit_down(on: bool) -> void:
	sitting = on


func sit_instant(on: bool) -> void:
	sitting = on
	_sit_amt = 1.0 if on else 0.0


## Walk along points (world positions), then optionally sit facing `face_to`.
func walk_path(points: Array, speed := 1.3) -> void:
	walking = true
	for p in points:
		var d: Vector3 = p - global_position
		d.y = 0
		var yaw := atan2(d.x, d.z)
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", yaw, 0.25)
		await tw.finished
		var dur := maxf(d.length() / speed, 0.05)
		var tw2 := create_tween()
		tw2.tween_property(self, "global_position", Vector3(p.x, global_position.y, p.z), dur)
		await tw2.finished
	walking = false


# ---------------------------------------------------------------- animation
func _process(delta: float) -> void:
	if _head == null:
		return
	_t += delta
	var sit_target := 1.0 if sitting else 0.0
	_sit_amt = move_toward(_sit_amt, sit_target, delta * 3.0)
	_body.position.y = -0.3 * _sit_amt
	var thigh_x := -PI * 0.5 * _sit_amt
	var knee_x := PI * 0.5 * _sit_amt
	var swing := 0.0
	if walking:
		_walk_phase += delta * 8.0
		swing = sin(_walk_phase) * 0.55
	_thigh_l.rotation.x = thigh_x + swing
	_thigh_r.rotation.x = thigh_x - swing
	_knee_l.rotation.x = knee_x + maxf(-swing, 0.0) * 0.6
	_knee_r.rotation.x = knee_x + maxf(swing, 0.0) * 0.6
	_torso.scale.y = 1.0 + sin(_t * 1.6) * 0.012

	# head: look at the target, look away when the tension is high
	var yaw := 0.0
	var pitch := 0.0
	if look_target != null:
		var local := to_local(look_target.global_position)
		yaw = clampf(atan2(local.x, local.z), -0.9, 0.9)
	var avoid := clampf((tension - 55.0) / 35.0, 0.0, 1.0)
	yaw += avoid * 0.7 * _avoid_sign
	pitch = avoid * 0.2
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, clampf(delta * 5.0, 0.0, 1.0))
	_head.rotation.x = lerpf(_head.rotation.x, pitch, clampf(delta * 4.0, 0.0, 1.0))

	# blinking: more with tension, more for naturally nervous people
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink_ph = 0.0
		_blink_cd = randf_range(2.5, 5.0) / (blink_mult * (1.0 + tension / 40.0))
	if _blink_ph < 1.0:
		_blink_ph += delta / 0.16
	var lid := sin(clampf(_blink_ph, 0.0, 1.0) * PI)
	_lid_l.scale.y = lid
	_lid_r.scale.y = lid

	# brows / mouth
	var brow_a := 0.0
	if emotion == "angry":
		brow_a = 0.4
	elif emotion == "worried":
		brow_a = -0.3
	_brow_l.rotation.z = -brow_a
	_brow_r.rotation.z = brow_a
	if _talk_left > 0.0:
		_talk_left -= delta
		talking = true
		_mouth.scale.y = 0.5 + absf(sin(_t * 14.0)) * 2.5
	else:
		talking = false
		_mouth.scale.y = 1.0
	_sweat.visible = tension > 62.0
	if _sweat.visible:
		_sweat.position.y = 0.22 - fmod(_t * 0.04, 0.12)

	# arms
	var rest := -0.5 * _sit_amt
	var ax_l := rest
	var ax_r := rest
	if typing:
		ax_l = -1.15 + sin(_t * 26.0) * 0.07
		ax_r = -1.15 + sin(_t * 26.0 + 1.7) * 0.07
	else:
		if talking:
			ax_r = rest - 0.4 + sin(_t * 3.0) * 0.25
		if tension > 35.0 and not talking:
			ax_l = rest - 0.15 + sin(_t * 5.0) * 0.12 * (tension / 60.0)
		if pen_tell and tension > 30.0 and fmod(_t, 2.2) < 0.45:
			ax_r = rest - 0.9 + sin(_t * 22.0) * 0.12
		if walking:
			ax_l = -swing * 0.8
			ax_r = swing * 0.8
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, ax_l, clampf(delta * 10.0, 0.0, 1.0))
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, ax_r, clampf(delta * 10.0, 0.0, 1.0))
