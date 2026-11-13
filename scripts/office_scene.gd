extends Node3D
## Live 3D main-menu scene: the detective's office at night.
## Rain on the window, flickering violet neon, coffee steam, slow camera drift
## with gyroscope (phone) / mouse (desktop) parallax. Everything is built in code.

const UV := Color("8A2BE2")
const GLOW := Color("B66DFF")
const GOLD := Color("F2B84B")
const BG := Color("0B0A14")

var camera: Camera3D
var _neon_light: OmniLight3D
var _neon_label: Label3D
var _neon_tubes: Array[MeshInstance3D] = []
var _folder_light: OmniLight3D
var _monitor_mat: StandardMaterial3D
var _quality := 1
var _tilt := Vector2.ZERO      # gyroscope parallax (leaky integrator)
var _par_smooth := Vector2.ZERO
var _neon_level := 1.0
var intro_offset := 0.0        # camera dolly-in at start (tweened by the menu)
var _cam_base := Vector3(0.0, 1.5, 1.7)
var _cam_target := Vector3(-0.25, 1.3, -3.0)
var interactive := false       # true = walkable game world (collisions, hotspots), no menu camera


func _ready() -> void:
	_quality = Settings.quality
	_build_environment()
	_build_room()
	_build_window_and_city()
	_build_desk()
	_build_board_and_cabinet()
	_build_lights()
	_build_rain()
	_build_steam()
	if interactive:
		_build_world_extras()
		return
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.current = true
	add_child(camera)
	camera.look_at_from_position(_cam_base, _cam_target, Vector3.UP)


# ---------------------------------------------------------------- helpers
func _mat(c: Color, rough := 0.85, emit := Color.BLACK, energy := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _box(pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent != null else self).add_child(mi)
	return mi


func _cyl(pos: Vector3, r: float, h: float, m: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


# ---------------------------------------------------------------- build
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.22, 0.5)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = _quality > 0
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.08, 0.22)
	env.fog_density = 0.02 if _quality > 0 else 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_room() -> void:
	var floor_m := _mat(Color(0.13, 0.09, 0.08), 0.55)
	var wall_m := _mat(Color(0.14, 0.13, 0.2), 0.95)
	_box(Vector3(0, -0.05, -0.4), Vector3(6.6, 0.1, 6.0), floor_m)       # floor
	_box(Vector3(0, 3.05, -0.4), Vector3(6.6, 0.1, 6.0), wall_m)        # ceiling
	_box(Vector3(-3.25, 1.5, -0.4), Vector3(0.1, 3.0, 6.0), wall_m)     # left wall
	_box(Vector3(3.25, 1.5, -0.4), Vector3(0.1, 3.0, 6.0), wall_m)      # right wall
	# back wall with a window hole x:-2.4..-0.4  y:0.9..2.4
	_box(Vector3(-2.825, 1.5, -3.0), Vector3(0.85, 3.0, 0.1), wall_m)
	_box(Vector3(1.4, 1.5, -3.0), Vector3(3.6, 3.0, 0.1), wall_m)
	_box(Vector3(-1.4, 0.45, -3.0), Vector3(2.0, 0.9, 0.1), wall_m)
	_box(Vector3(-1.4, 2.7, -3.0), Vector3(2.0, 0.6, 0.1), wall_m)
	# window frame
	var frame := _mat(Color(0.05, 0.05, 0.07), 0.6)
	_box(Vector3(-1.4, 1.65, -2.93), Vector3(0.06, 1.5, 0.06), frame)
	_box(Vector3(-1.4, 1.65, -2.93), Vector3(2.0, 0.05, 0.06), frame)


func _build_window_and_city() -> void:
	# rain-streaked glass
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 1.5)
	glass.mesh = q
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 g = UV * vec2(26.0, 12.0);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = hash(id);
	float t = fract(TIME * (0.04 + 0.09 * h) + h);
	vec2 c = vec2(0.2 + 0.6 * hash(id + 7.0), 1.0 - t);
	float d = length((f - c) * vec2(1.0, 0.55));
	float drop = smoothstep(0.16, 0.0, d);
	float trail = step(c.y, f.y) * smoothstep(0.035, 0.0, abs(f.x - c.x)) * 0.35 * step(0.55, h);
	ALBEDO = vec3(0.62, 0.7, 1.0);
	ALPHA = 0.07 + drop * 0.55 + trail;
}
"""
	sm.shader = sh
	glass.material_override = sm
	glass.position = Vector3(-1.4, 1.65, -2.95)
	add_child(glass)

	# distant city silhouette with lit windows
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dark := _mat(Color(0.05, 0.05, 0.1), 1.0)
	var lit := _mat(GOLD, 1.0, GOLD, 2.2)
	for i in range(9):
		var w := rng.randf_range(1.4, 2.6)
		var h := rng.randf_range(3.0, 8.0)
		var x := -9.0 + i * 2.2
		var z := rng.randf_range(-13.0, -10.0)
		_box(Vector3(x, h * 0.5 - 1.0, z), Vector3(w, h, 1.2), dark)
		for j in range(rng.randi_range(4, 9)):
			if rng.randf() < 0.55:
				_box(Vector3(x + rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(0.0, h - 1.4), z + 0.62),
					Vector3(0.16, 0.2, 0.02), lit)

	# violet neon sign across the street (flickers in _process)
	var neon_pos := Vector3(-1.1, 1.75, -5.2)
	_box(neon_pos + Vector3(0, 0, -0.1), Vector3(2.1, 0.8, 0.08), _mat(Color(0.04, 0.03, 0.08), 0.9))
	_neon_label = Label3D.new()
	_neon_label.text = "VIOLET FILES"
	_neon_label.font_size = 128
	_neon_label.pixel_size = 0.0021
	_neon_label.shaded = false
	_neon_label.outline_size = 10
	_neon_label.outline_modulate = UV
	_neon_label.modulate = Color(1.2, 0.75, 1.7)
	_neon_label.position = neon_pos
	add_child(_neon_label)
	var tube := _mat(GLOW, 0.5, GLOW, 4.0)
	for t in [
		[Vector3(0, 0.37, 0), Vector3(2.0, 0.025, 0.025)],
		[Vector3(0, -0.37, 0), Vector3(2.0, 0.025, 0.025)],
		[Vector3(-1.0, 0, 0), Vector3(0.025, 0.74, 0.025)],
		[Vector3(1.0, 0, 0), Vector3(0.025, 0.74, 0.025)]]:
		_neon_tubes.append(_box(neon_pos + t[0], t[1], tube))
	_neon_light = OmniLight3D.new()
	_neon_light.light_color = GLOW
	_neon_light.omni_range = 9.0
	_neon_light.position = Vector3(-1.2, 1.7, -2.4)
	add_child(_neon_light)


func _build_desk() -> void:
	var wood := _mat(Color(0.2, 0.12, 0.08), 0.5)
	var metal := _mat(Color(0.08, 0.08, 0.1), 0.35, Color.BLACK, 0.0, 0.7)
	var dz := -0.9
	_box(Vector3(0.2, 0.75, dz), Vector3(3.0, 0.06, 1.0), wood)
	for x in [-1.25, 1.65]:
		for z in [dz - 0.4, dz + 0.4]:
			_box(Vector3(x, 0.36, z), Vector3(0.07, 0.72, 0.07), wood)

	# desk lamp (warm)
	_cyl(Vector3(-0.9, 0.795, -1.1), 0.1, 0.03, metal)
	_box(Vector3(-0.85, 1.02, -1.05), Vector3(0.025, 0.5, 0.025), metal, Vector3(0, 0, -10))
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.14
	sm.height = 0.14
	shade.mesh = sm
	shade.material_override = _mat(Color(0.06, 0.2, 0.15), 0.5)
	shade.position = Vector3(-0.77, 1.27, -1.0)
	shade.rotation_degrees = Vector3(0, 0, 18)
	add_child(shade)
	_box(Vector3(-0.76, 1.2, -1.0), Vector3(0.07, 0.03, 0.07), _mat(GOLD, 0.5, GOLD, 4.0))

	# coffee cup
	_cyl(Vector3(0.15, 0.825, -0.65), 0.05, 0.09, _mat(Color(0.85, 0.83, 0.8), 0.4))
	_cyl(Vector3(0.15, 0.868, -0.65), 0.043, 0.005, _mat(Color(0.12, 0.06, 0.03), 0.3))

	# monitor facing the player
	_cyl(Vector3(0.95, 0.79, -1.15), 0.1, 0.02, metal)
	_box(Vector3(0.95, 0.9, -1.15), Vector3(0.04, 0.22, 0.04), metal)
	_box(Vector3(0.95, 1.18, -1.15), Vector3(0.74, 0.46, 0.04), metal)
	_monitor_mat = _mat(Color(0.05, 0.03, 0.12), 0.3, UV, 1.1)
	_box(Vector3(0.95, 1.18, -1.128), Vector3(0.68, 0.4, 0.01), _monitor_mat)
	var line := _mat(GLOW, 0.4, GLOW, 1.6)
	for i in range(6):
		var w := 0.2 + 0.08 * float((i * 5) % 4)
		_box(Vector3(0.95 - 0.3 + w * 0.5, 1.33 - i * 0.055, -1.12), Vector3(w, 0.012, 0.004), line)

	# the violet case folder, opened, glowing (matches the app icon)
	_box(Vector3(-0.25, 0.79, -0.55), Vector3(0.4, 0.015, 0.3), _mat(Color(0.55, 0.4, 0.22), 0.7))
	_box(Vector3(-0.25, 0.81, -0.62), Vector3(0.4, 0.01, 0.28), _mat(Color(0.6, 0.44, 0.25), 0.7), Vector3(-16, 0, 0))
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.24
	cm.bottom_radius = 0.02
	cm.height = 0.75
	cone.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(0.55, 0.2, 1.0, 0.13)
	cone.material_override = cmat
	cone.position = Vector3(-0.25, 1.18, -0.55)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
	_folder_light = OmniLight3D.new()
	_folder_light.light_color = GLOW
	_folder_light.omni_range = 1.4
	_folder_light.position = Vector3(-0.25, 0.95, -0.55)
	add_child(_folder_light)

	# loose papers + landline phone
	var paper := _mat(Color(0.82, 0.8, 0.74), 0.9)
	_box(Vector3(0.55, 0.783, -0.5), Vector3(0.22, 0.004, 0.3), paper, Vector3(0, 12, 0))
	_box(Vector3(0.62, 0.787, -0.52), Vector3(0.22, 0.004, 0.3), paper, Vector3(0, -8, 0))
	var black := _mat(Color(0.03, 0.03, 0.035), 0.4)
	_box(Vector3(1.45, 0.82, -0.6), Vector3(0.24, 0.08, 0.18), black)
	_box(Vector3(1.45, 0.88, -0.6), Vector3(0.22, 0.04, 0.05), black)


func _string(a: Vector3, b: Vector3, m: Material) -> void:
	var d := b - a
	var ln := Vector2(d.x, d.y).length()
	var ang := rad_to_deg(atan2(d.y, d.x))
	_box((a + b) * 0.5, Vector3(ln, 0.006, 0.006), m, Vector3(0, 0, ang))


func _build_board_and_cabinet() -> void:
	var z := -2.93
	_box(Vector3(1.7, 1.65, z), Vector3(1.6, 1.05, 0.03), _mat(Color(0.35, 0.22, 0.12), 0.9))
	var paper := _mat(Color(0.85, 0.83, 0.76), 0.95)
	var violet_paper := _mat(Color(0.5, 0.3, 0.8), 0.6, UV, 0.8)
	var pts := [Vector3(1.25, 1.95, z + 0.03), Vector3(1.75, 1.8, z + 0.03), Vector3(2.15, 1.98, z + 0.03),
		Vector3(1.4, 1.4, z + 0.03), Vector3(2.0, 1.4, z + 0.03)]
	for i in range(pts.size()):
		var m: Material = violet_paper if i == 4 else paper
		_box(pts[i], Vector3(0.24, 0.3, 0.01), m, Vector3(0, 0, [6, -5, 8, -9, 4][i]))
	var red := _mat(Color("D7263D"), 0.6)
	for pair in [[0, 1], [1, 2], [1, 3], [3, 4], [2, 4]]:
		_string(pts[pair[0]] + Vector3(0, 0, 0.012), pts[pair[1]] + Vector3(0, 0, 0.012), red)

	var steel := _mat(Color(0.18, 0.2, 0.27), 0.5, Color.BLACK, 0.0, 0.5)
	_box(Vector3(2.6, 0.65, -2.5), Vector3(0.7, 1.3, 0.6), steel)
	var dark := _mat(Color(0.04, 0.04, 0.06), 0.6)
	for y in [0.43, 0.86]:
		_box(Vector3(2.6, y, -2.19), Vector3(0.66, 0.015, 0.02), dark)
	for y in [0.22, 0.65, 1.08]:
		_box(Vector3(2.6, y, -2.18), Vector3(0.18, 0.025, 0.03), _mat(GOLD, 0.4, Color.BLACK, 0.0, 0.8))


func _build_lights() -> void:
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.82, 0.5)
	spot.light_energy = 5.0
	spot.spot_range = 3.5
	spot.spot_angle = 55.0
	spot.shadow_enabled = _quality >= 2
	add_child(spot)
	spot.look_at_from_position(Vector3(-0.75, 1.2, -1.0), Vector3(-0.2, 0.78, -0.7), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.4, 0.45, 0.9)
	fill.light_energy = 0.7
	fill.omni_range = 6.0
	fill.position = Vector3(0.0, 2.7, 0.0)
	add_child(fill)


func _build_rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = [300, 600, 1200][clampi(_quality, 0, 2)]
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.local_coords = false
	p.position = Vector3(-1.0, 6.0, -6.0)
	p.visibility_aabb = AABB(Vector3(-9, -11, -4), Vector3(18, 12, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 0.1, 3.0)
	pm.direction = Vector3(-0.12, -1.0, 0.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.6, 0.7, 1.0, 0.45)
	qm.material = m
	p.draw_pass_1 = qm
	add_child(p)


func _build_steam() -> void:
	var p := GPUParticles3D.new()
	p.amount = [10, 18, 28][clampi(_quality, 0, 2)]
	p.lifetime = 2.4
	p.preprocess = 2.0
	p.position = Vector3(0.15, 0.88, -0.65)
	p.visibility_aabb = AABB(Vector3(-0.5, -0.2, -0.5), Vector3(1.0, 1.5, 1.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.015
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.07
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.5
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var tex_g := Gradient.new()
	tex_g.offsets = PackedFloat32Array([0.0, 1.0])
	tex_g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = tex_g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	qm.material = m
	p.draw_pass_1 = qm
	add_child(p)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0

	# neon: steady glow with an occasional stutter and buzz
	var ph := fmod(t, 7.0)
	var target := 1.0
	if (ph > 5.0 and ph < 5.08) or (ph > 5.16 and ph < 5.22):
		target = 0.0
	elif ph > 5.9 and ph < 6.0:
		target = 0.3
	_neon_level = lerpf(_neon_level, target, clampf(delta * 40.0, 0.0, 1.0))
	var lv := _neon_level * (0.96 + 0.04 * sin(t * 57.0))
	_neon_light.light_energy = 3.2 * lv + 0.15
	_neon_label.modulate = Color(1.2 * lv, 0.75 * lv, 1.7 * lv, 1.0)
	(_neon_tubes[0].material_override as StandardMaterial3D).emission_energy_multiplier = 4.0 * lv
	_folder_light.light_energy = 1.1 + 0.25 * sin(t * 1.6)
	_monitor_mat.emission_energy_multiplier = 1.1 + 0.1 * sin(t * 3.0)

	if camera == null:
		return
	# camera: slow drift + gyroscope (phone) or mouse (desktop) parallax
	var par := Vector2.ZERO
	if Settings.gyro and DisplayServer.is_touchscreen_available():
		var gy := Input.get_gyroscope()
		# in landscape the device x axis is vertical (yaw), y axis is horizontal (pitch)
		var s := -1.0 if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE else 1.0
		_tilt = (_tilt + Vector2(gy.x, gy.y) * delta * 0.8 * s) * (1.0 - clampf(delta * 1.2, 0.0, 1.0))
		_tilt = _tilt.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
		par = _tilt
	elif not DisplayServer.is_touchscreen_available():
		var vp := get_viewport()
		par = vp.get_mouse_position() / vp.get_visible_rect().size - Vector2(0.5, 0.5)
	_par_smooth = _par_smooth.lerp(par, clampf(delta * 3.0, 0.0, 1.0))
	var drift := Vector3(sin(t * 0.21) * 0.10, sin(t * 0.33) * 0.03, sin(t * 0.17) * 0.05)
	var pos := _cam_base + drift + Vector3(_par_smooth.x * 0.35, -_par_smooth.y * 0.18, intro_offset)
	var look := _cam_target + drift * 0.3 + Vector3(_par_smooth.x * 0.9, -_par_smooth.y * 0.4, 0.0)
	camera.look_at_from_position(pos, look, Vector3.UP)


# ================================================================ interactive world extras
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


## Looks-at-able object: StaticBody3D on layer 2 with meta id + bilingual label.
func add_hotspot(id: String, pos: Vector3, size: Vector3, ar: String, en: String) -> StaticBody3D:
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
	add_child(sb)
	return sb


func _build_world_extras() -> void:
	var wall_m := _mat(Color(0.14, 0.13, 0.2), 0.95)
	_box(Vector3(0, 1.5, 2.6), Vector3(6.6, 3.0, 0.1), wall_m)      # front wall
	# room shell collisions
	_solid(Vector3(0, 1.5, -3.0), Vector3(6.6, 3.0, 0.3))
	_solid(Vector3(0, 1.5, 2.6), Vector3(6.6, 3.0, 0.3))
	_solid(Vector3(-3.25, 1.5, -0.4), Vector3(0.3, 3.0, 6.0))
	_solid(Vector3(3.25, 1.5, -0.4), Vector3(0.3, 3.0, 6.0))
	# player's desk + cabinet
	_solid(Vector3(0.2, 0.39, -0.9), Vector3(3.0, 0.78, 1.0))
	_solid(Vector3(2.6, 0.65, -2.5), Vector3(0.7, 1.3, 0.6))
	# Haitham's desk against the right wall, monitor facing the room
	var wood := _mat(Color(0.2, 0.12, 0.08), 0.5)
	var metal := _mat(Color(0.08, 0.08, 0.1), 0.35, Color.BLACK, 0.0, 0.7)
	_box(Vector3(2.8, 0.75, 0.9), Vector3(0.8, 0.06, 1.6), wood)
	for z in [0.15, 1.65]:
		_box(Vector3(2.5, 0.36, z), Vector3(0.06, 0.72, 0.06), wood)
		_box(Vector3(3.1, 0.36, z), Vector3(0.06, 0.72, 0.06), wood)
	_solid(Vector3(2.8, 0.39, 0.9), Vector3(0.8, 0.78, 1.6))
	_box(Vector3(3.05, 1.12, 0.9), Vector3(0.04, 0.46, 0.74), metal)
	var screen := _mat(Color(0.05, 0.03, 0.12), 0.3, UV, 1.0)
	_box(Vector3(3.025, 1.12, 0.9), Vector3(0.01, 0.4, 0.68), screen)
	_box(Vector3(3.05, 0.9, 0.9), Vector3(0.04, 0.2, 0.04), metal)
	_box(Vector3(2.55, 0.8, 0.6), Vector3(0.26, 0.04, 0.4), metal)        # keyboard
	# chairs
	var seat := _mat(Color(0.1, 0.1, 0.14), 0.8)
	_box(Vector3(2.15, 0.45, 0.9), Vector3(0.45, 0.05, 0.45), seat)
	_box(Vector3(1.94, 0.72, 0.9), Vector3(0.05, 0.5, 0.45), seat)
	_box(Vector3(0.2, 0.45, -1.9), Vector3(0.45, 0.05, 0.45), seat)       # client chair
	_box(Vector3(0.2, 0.72, -2.15), Vector3(0.45, 0.5, 0.05), seat)
	# door in the left wall
	var door_m := _mat(Color(0.28, 0.17, 0.1), 0.6)
	_box(Vector3(-3.2, 1.05, 0.6), Vector3(0.08, 2.1, 0.95), door_m)
	_box(Vector3(-3.14, 1.0, 0.25), Vector3(0.05, 0.1, 0.05), _mat(Color("F2B84B"), 0.3, Color.BLACK, 0.0, 0.8))
	_box(Vector3(-3.2, 2.15, 0.6), Vector3(0.1, 0.1, 1.05), metal)
	# warm ceiling lamp so the room is readable while walking
	var ceil_l := OmniLight3D.new()
	ceil_l.light_color = Color(1.0, 0.85, 0.65)
	ceil_l.light_energy = 0.9
	ceil_l.omni_range = 7.0
	ceil_l.position = Vector3(0.0, 2.6, 0.9)
	add_child(ceil_l)
	# hotspots
	add_hotspot("folder", Vector3(-0.25, 0.85, -0.55), Vector3(0.55, 0.25, 0.45), "ملف القضية", "Case file")
	add_hotspot("computer", Vector3(0.95, 1.1, -1.15), Vector3(0.8, 0.7, 0.3), "الكمبيوتر", "Computer")
	add_hotspot("landline", Vector3(1.45, 0.85, -0.6), Vector3(0.35, 0.25, 0.3), "الهاتف الأرضي", "Landline phone")
	add_hotspot("door", Vector3(-3.05, 1.05, 0.6), Vector3(0.3, 2.1, 0.95), "الباب", "Door")
	add_hotspot("board", Vector3(1.7, 1.65, -2.85), Vector3(1.6, 1.05, 0.2), "لوحة التحقيق", "Investigation board")
