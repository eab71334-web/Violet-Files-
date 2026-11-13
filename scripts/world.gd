extends Node
## Game world manager: locations (office / roof), player, UI, photo capture, camera focus.

const OFFICE := preload("res://scripts/office_scene.gd")
const ROOF := preload("res://scripts/roof_scene.gd")
const CASE := preload("res://scripts/case1.gd")
const RAIN := preload("res://scripts/rain_audio.gd")

var ui: GameUI
var player: Player
var loc: Node3D
var loc_name := ""
var case
var focus_cam: Camera3D
var busy := false


func _ready() -> void:
	ui = GameUI.new()
	add_child(ui)
	player = Player.new()
	add_child(player)
	ui.player = player
	if Engine.has_meta("vf_test"):
		ui.fast = true
		ui.auto = Array(Engine.get_meta("vf_auto", [])).duplicate()
	player.block_rects_provider = _block_rects
	player.hotspot_changed.connect(_on_hotspot)
	ui.interact_pressed.connect(_on_interact)
	ui.shutter.connect(_take_photo)
	ui.back_to_menu.connect(_to_menu)
	ui.phone_action.connect(_on_phone_action)
	add_child(RAIN.new())
	case = CASE.new()
	case.world = self
	case.ui = ui
	add_child(case)
	ui.notes_provider = case.notes_text
	case.start()


func _block_rects() -> Array:
	return ui.block_rects() + ui.camera_block_rects()


func _process(_d: float) -> void:
	var on := not (busy or ui.dialog_open() or ui.modal_open)
	if player.enabled and not on:
		player.release_touches()
	player.enabled = on


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_hotspot(h) -> void:
	if h == null or ui.camera_mode:
		ui.set_hotspot("")
		return
	ui.set_hotspot(str(h.get_meta("label_ar" if Settings.is_ar() else "label_en")))


func _on_interact() -> void:
	var h = player.hotspot
	if h == null or busy:
		return
	busy = true
	await case.interact(str(h.get_meta("id")), h)
	busy = false
	_on_hotspot(player.hotspot)


func _on_phone_action(name: String) -> void:
	if name == "haitham" and not busy:
		busy = true
		await case.phone_haitham()
		busy = false


# ------------------------------------------------------------------ locations
func go_location(n: String) -> void:
	if is_instance_valid(loc):
		loc.queue_free()
	loc_name = n
	if n == "office":
		var o := OFFICE.new()
		o.interactive = true
		loc = o
		add_child(o)
		player.global_position = Vector3(0, 0, 1.3)
	else:
		var r := ROOF.new()
		loc = r
		add_child(r)
		r.set_washed(Game.raining_washed())
		player.global_position = r.start_pos
	player.yaw = 0.0
	player.pitch = 0.0
	case.on_location(n)


# ------------------------------------------------------------------ photo
func _take_photo() -> void:
	var from := player.cam.global_position
	var to := from + (-player.cam.global_transform.basis.z) * 18.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	ui.flash()
	if hit.is_empty() or not hit["collider"].has_meta("ev"):
		ui.toast(Settings.t("لا شيء مهم في الإطار", "Nothing important in the frame"))
		return
	var ev: String = hit["collider"].get_meta("ev")
	var d := from.distance_to(hit["position"])
	var quality := "good"
	var note := ""
	if ev == "roof_burn":
		if Game.raining_washed():
			quality = "poor"
			note = Settings.t(" - المطر مسح الأثر", " - the rain washed the marks")
		elif d > 2.8:
			quality = "poor"
			note = Settings.t(" - قرّب أكثر", " - get closer")
	Game.add_ev(ev, quality)
	var tag := Settings.t("جيدة", "good") if quality == "good" else Settings.t("ضعيفة", "poor")
	ui.toast(Settings.t("صورة محفوظة: %s (جودة %s)%s", "Photo saved: %s (%s quality)%s") % [Game.ev_name(ev), tag, note])


# ------------------------------------------------------------------ camera focus on a person
func focus_on(p: BlockyPerson) -> void:
	if is_instance_valid(focus_cam):
		focus_cam.queue_free()
	focus_cam = Camera3D.new()
	focus_cam.fov = 38.0
	add_child(focus_cam)
	var head := p.global_position + Vector3(0, 1.58 - (0.3 if p.sitting else 0.0), 0)
	var cpos := head + p.global_transform.basis.z * 2.0 + Vector3(0.3, 0.1, 0)
	var look_at_pt := head - Vector3(0, 0.22, 0)
	var to_t := Transform3D(Basis.looking_at(look_at_pt - cpos, Vector3.UP), cpos)
	var from_t := player.cam.global_transform
	focus_cam.global_transform = from_t
	focus_cam.current = true
	if ui.fast:
		focus_cam.global_transform = to_t
		return
	var tw := create_tween()
	tw.tween_method(func(w: float): focus_cam.global_transform = from_t.interpolate_with(to_t, w), 0.0, 1.0, 0.9)
	await tw.finished


func release_focus() -> void:
	player.cam.current = true
	if is_instance_valid(focus_cam):
		focus_cam.queue_free()
	focus_cam = null
