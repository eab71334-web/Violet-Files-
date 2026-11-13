class_name RoofScene
extends Node3D
## The burned building's roof in the rain (case 1 scene). Walkable; photo targets carry meta "ev".

var burn_mat: StandardMaterial3D
var start_pos := Vector3(0.0, 0.0, 3.6)
var start_yaw := 0.0
var _quality := 1


func _mat(c: Color, rough := 0.9, emit := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _box(pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _solid(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)


func add_hotspot(id: String, pos: Vector3, size: Vector3, ar: String, en: String, ev := "") -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.set_meta("id", id)
	sb.set_meta("label_ar", ar)
	sb.set_meta("label_en", en)
	if ev != "":
		sb.set_meta("ev", ev)
	add_child(sb)
	return sb


func _ready() -> void:
	_quality = Settings.quality
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.58)
	env.ambient_light_energy = 1.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = _quality > 0
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.11, 0.2)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.55, 0.6, 1.0)
	sun.light_energy = 0.45
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

	# slab + parapet
	var concrete := _mat(Color(0.34, 0.34, 0.38), 0.95)
	_box(Vector3(0, -0.1, 0), Vector3(10, 0.2, 10), concrete)
	var para := _mat(Color(0.4, 0.39, 0.43), 0.9)
	for d in [[Vector3(0, 0.5, -5.1), Vector3(10.4, 1.0, 0.25)], [Vector3(0, 0.5, 5.1), Vector3(10.4, 1.0, 0.25)],
			[Vector3(-5.1, 0.5, 0), Vector3(0.25, 1.0, 10.4)], [Vector3(5.1, 0.5, 0), Vector3(0.25, 1.0, 10.4)]]:
		_box(d[0], d[1], para)
		_solid(d[0] + Vector3(0, 0.5, 0), d[1] + Vector3(0, 1.0, 0))
	# stair house with the door back down to the office
	_box(Vector3(-3.5, 1.1, -3.5), Vector3(2.4, 2.2, 2.0), _mat(Color(0.3, 0.28, 0.3), 0.9))
	_solid(Vector3(-3.5, 1.1, -3.5), Vector3(2.4, 2.2, 2.0))
	_box(Vector3(-3.5, 0.95, -2.48), Vector3(0.9, 1.9, 0.06), _mat(Color(0.28, 0.17, 0.1), 0.6))
	add_hotspot("stairs", Vector3(-3.5, 0.95, -2.35), Vector3(1.0, 1.9, 0.3), "النزول للمكتب", "Go back to the office")
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 4.0
	lamp.spot_range = 8.0
	lamp.spot_angle = 60.0
	add_child(lamp)
	lamp.look_at_from_position(Vector3(-3.5, 2.4, -2.2), Vector3(-2.5, 0.0, 0.5), Vector3.UP)
	_box(Vector3(-3.5, 2.4, -2.3), Vector3(0.3, 0.1, 0.2), _mat(Color("F2B84B"), 0.5, Color("F2B84B"), 3.0))
	# threat letter pinned next to the door (misleading)
	_box(Vector3(-2.55, 1.4, -2.47), Vector3(0.34, 0.44, 0.015), _mat(Color(0.85, 0.82, 0.7), 0.9))
	add_hotspot("letter", Vector3(-2.55, 1.4, -2.4), Vector3(0.5, 0.6, 0.25), "رسالة مثبتة على الجدار", "Letter pinned on the wall", "threat_letter")

	# the burn marks (real evidence, washed by the rain later)
	burn_mat = StandardMaterial3D.new()
	burn_mat.albedo_color = Color(0.05, 0.03, 0.025, 0.95)
	burn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burn_mat.roughness = 1.0
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.2, 0.13, 0.1, 0.8)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.roughness = 1.0
	_box(Vector3(1.5, 0.008, 0.8), Vector3(3.0, 0.016, 2.3), soot)
	_box(Vector3(1.5, 0.012, 0.8), Vector3(2.2, 0.02, 1.6), burn_mat)
	var ember := _mat(Color(0.3, 0.08, 0.02), 0.8, Color(1.0, 0.35, 0.08), 0.6)
	for e in [Vector3(1.0, 0.03, 0.6), Vector3(1.8, 0.03, 1.1), Vector3(2.1, 0.03, 0.4), Vector3(1.4, 0.03, 1.3)]:
		_box(e, Vector3(0.12, 0.03, 0.09), ember, Vector3(0, 30, 0))
	var burn_light := SpotLight3D.new()
	burn_light.light_color = Color(1.0, 0.75, 0.5)
	burn_light.light_energy = 3.0
	burn_light.spot_range = 8.0
	burn_light.spot_angle = 55.0
	add_child(burn_light)
	burn_light.look_at_from_position(Vector3(1.5, 3.5, 2.4), Vector3(1.5, 0.0, 0.8), Vector3.UP)
	_box(Vector3(1.2, 0.012, 1.3), Vector3(1.4, 0.02, 0.8), burn_mat, Vector3(0, 25, 0))
	_box(Vector3(2.0, 0.012, 0.3), Vector3(1.2, 0.02, 0.9), burn_mat, Vector3(0, -20, 0))
	var vent := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 0.9
	vent.mesh = cm
	vent.material_override = _mat(Color(0.06, 0.05, 0.05), 0.9)
	vent.position = Vector3(2.4, 0.45, 0.5)
	add_child(vent)
	add_hotspot("burn", Vector3(1.6, 0.25, 0.8), Vector3(2.6, 0.6, 2.0), "آثار سوداء على السطح", "Black marks on the roof", "roof_burn")

	# generator shed with the petrol can (misleading)
	_box(Vector3(3.9, 1.0, 3.7), Vector3(1.8, 2.0, 1.6), _mat(Color(0.22, 0.24, 0.2), 0.9))
	_solid(Vector3(3.9, 1.0, 3.7), Vector3(1.8, 2.0, 1.6))
	_box(Vector3(2.5, 0.35, 3.3), Vector3(0.7, 0.7, 0.9), _mat(Color(0.35, 0.33, 0.1), 0.5))   # generator
	_solid(Vector3(2.5, 0.35, 3.3), Vector3(0.7, 0.7, 0.9))
	_box(Vector3(3.0, 0.22, 2.5), Vector3(0.3, 0.44, 0.2), _mat(Color("b03030"), 0.5))        # petrol can
	add_hotspot("gas", Vector3(3.0, 0.25, 2.5), Vector3(0.6, 0.6, 0.5), "علبة بنزين بجانب المولد", "Petrol can next to the generator", "gas_can")

	# water tower for the skyline feel
	var tank := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.9
	tm.bottom_radius = 0.9
	tm.height = 1.6
	tank.mesh = tm
	tank.material_override = _mat(Color(0.18, 0.16, 0.15), 0.8)
	tank.position = Vector3(3.5, 3.4, -3.2)
	add_child(tank)
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			_box(Vector3(3.5 + x, 1.3, -3.2 + z), Vector3(0.1, 2.6, 0.1), _mat(Color(0.12, 0.11, 0.1)))

	# the opposite building with the surveillance camera on a pole (a lead)
	_box(Vector3(0, 0, -13), Vector3(14, 5.0, 6), _mat(Color(0.1, 0.1, 0.16), 1.0))
	_box(Vector3(1.0, 3.1, -11.5), Vector3(0.12, 1.2, 0.12), _mat(Color(0.1, 0.1, 0.1)))
	_box(Vector3(1.0, 3.8, -11.4), Vector3(0.45, 0.25, 0.3), _mat(Color(0.12, 0.12, 0.14), 0.4, Color("D7263D"), 0.4))
	add_hotspot("campole", Vector3(1.0, 3.5, -11.5), Vector3(1.4, 2.0, 1.2), "كاميرا مراقبة على المبنى المقابل", "Surveillance camera on the building opposite", "cam_pole")

	# skyline + lit windows
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dark := _mat(Color(0.05, 0.05, 0.1), 1.0)
	var lit := _mat(Color("F2B84B"), 1.0, Color("F2B84B"), 2.0)
	for i in range(14):
		var ang := TAU * float(i) / 14.0
		var dist := rng.randf_range(24.0, 32.0)
		var h := rng.randf_range(8.0, 20.0)
		var pos := Vector3(cos(ang) * dist, h * 0.5 - 4.0, sin(ang) * dist)
		if pos.z < -8.0 and absf(pos.x) < 10.0:
			continue
		_box(pos, Vector3(rng.randf_range(3.0, 6.0), h, 4.0), dark)
		for j in range(6):
			if rng.randf() < 0.6:
				var wp := pos + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-h * 0.3, h * 0.4), 0)
				var toward := Vector3(-pos.x, 0, -pos.z).normalized() * 2.05
				_box(wp + toward, Vector3(0.3, 0.4, 0.3), lit)
	_build_rain()


func set_washed(on: bool) -> void:
	if burn_mat:
		burn_mat.albedo_color.a = 0.12 if on else 0.95


func _build_rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = [350, 700, 1200][clampi(_quality, 0, 2)]
	p.lifetime = 0.9
	p.preprocess = 0.9
	p.local_coords = false
	p.position = Vector3(0, 8.0, 0)
	p.visibility_aabb = AABB(Vector3(-12, -10, -12), Vector3(24, 12, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 0.1, 9.0)
	pm.direction = Vector3(-0.1, -1.0, 0.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.65, 0.72, 1.0, 0.4)
	qm.material = m
	p.draw_pass_1 = qm
	add_child(p)
