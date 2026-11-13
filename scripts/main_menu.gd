extends Control
## Violet Files - main menu (landscape). Live 3D office behind a menu column:
## Continue / Solo Play / LAN / Settings. Panels, LAN host/join, intro animation.

const OFFICE := preload("res://scripts/office_scene.gd")
const RAIN_AUDIO := preload("res://scripts/rain_audio.gd")
const UV := Color("8A2BE2")
const GLOW := Color("B66DFF")
const GOLD := Color("F2B84B")
const TEXT := Color("EDEAF5")
const LAN_PORT := 7777

var _office
var _audio
var _shade: TextureRect
var _fade: ColorRect
var _column: VBoxContainer
var _title: Label
var _tagline: Label
var _version: Label
var _btns: Dictionary = {}
var _panel: Control
var _toast_node: Control
var _diff := 1
var _lan_label: Label
var _lan_msg := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_office = OFFICE.new()
	add_child(_office)
	_audio = RAIN_AUDIO.new()
	add_child(_audio)
	_build_ui()
	Settings.changed.connect(_refresh)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	_refresh()
	_play_intro()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_title.add_theme_color_override("font_outline_color", Color(UV, 0.55 + 0.3 * sin(t * 2.0)))


# ------------------------------------------------------------------ UI build
func _build_ui() -> void:
	# dark gradient so the text stays readable over the scene
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	_shade = TextureRect.new()
	_shade.texture = gt
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(640, 0)
	_column.add_theme_constant_override("separation", 18)
	row.add_child(_column)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", GLOW)
	_title.add_theme_constant_override("outline_size", 14)
	_column.add_child(_title)
	_tagline = Label.new()
	_tagline.add_theme_font_size_override("font_size", 30)
	_tagline.add_theme_color_override("font_color", Color(TEXT, 0.75))
	_column.add_child(_tagline)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(grow)

	var ids := ["continue", "solo", "lan", "settings"]
	if OS.get_name() != "iOS" and OS.get_name() != "Android":
		ids.append("quit")
	for id in ids:
		var b := _make_button()
		b.pressed.connect(_on_menu_pressed.bind(id))
		_column.add_child(b)
		_btns[id] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_column.add_child(gap)
	_version = Label.new()
	_version.add_theme_font_size_override("font_size", 22)
	_version.add_theme_color_override("font_color", Color(TEXT, 0.4))
	_version.text = "v0.1 - SABAK STUDIOS"
	_column.add_child(_version)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _make_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(600, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func(): _scale_to(b, 1.04))
	b.mouse_exited.connect(func(): _scale_to(b, 1.0))
	return b


func _scale_to(c: Control, s: float) -> void:
	if c is Button and (c as Button).disabled:
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(s, s), 0.12)


func _sb(bg: Color, border: Color, glow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if Settings.is_ar():
		s.border_width_right = 6
	else:
		s.border_width_left = 6
	s.set_corner_radius_all(8)
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	if glow:
		s.shadow_color = Color(GLOW, 0.45)
		s.shadow_size = 14
	return s


func _style_button(b: Button, selected := false) -> void:
	var normal := _sb(Color(0.05, 0.04, 0.1, 0.72), UV)
	if selected:
		normal = _sb(Color(0.3, 0.12, 0.55, 0.95), GLOW, true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _sb(Color(0.16, 0.07, 0.3, 0.88), GLOW, true))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.3, 0.12, 0.55, 0.95), GLOW, true))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.05, 0.04, 0.1, 0.35), Color(0.3, 0.28, 0.4, 0.5)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.62))
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if Settings.is_ar() else HORIZONTAL_ALIGNMENT_LEFT


func _refresh() -> void:
	var ar := Settings.is_ar()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	_shade.flip_h = ar
	_title.text = "الملفات\nالبنفسجية" if ar else "VIOLET\nFILES"
	_tagline.text = Settings.t("الحقيقة تتوهج بنفسجي", "The truth glows violet")
	_btns["continue"].text = Settings.t("متابعة", "Continue")
	_btns["solo"].text = Settings.t("لعب فردي", "Solo Play")
	_btns["lan"].text = Settings.t("لعب محلي (LAN)", "Local Play (LAN)")
	_btns["settings"].text = Settings.t("الإعدادات", "Settings")
	if _btns.has("quit"):
		_btns["quit"].text = Settings.t("خروج", "Quit")
	_btns["continue"].disabled = not Settings.has_save()
	for id in _btns:
		_style_button(_btns[id])


func _play_intro() -> void:
	_office.intro_offset = 0.8
	_title.modulate.a = 0.0
	_tagline.modulate.a = 0.0
	_version.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fade, "color:a", 0.0, 1.8)
	tw.tween_property(_office, "intro_offset", 0.0, 3.2)
	tw.tween_property(_title, "modulate:a", 1.0, 1.2).set_delay(0.8)
	tw.tween_property(_tagline, "modulate:a", 1.0, 1.0).set_delay(1.4)
	tw.tween_property(_version, "modulate:a", 1.0, 1.0).set_delay(2.4)
	var i := 0
	for id in _btns:
		var b: Button = _btns[id]
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.5).set_delay(1.6 + i * 0.12)
		i += 1


# ------------------------------------------------------------------ actions
func _on_menu_pressed(id: String) -> void:
	_audio.click()
	match id:
		"continue": _do_continue()
		"solo": _open_solo()
		"lan": _open_lan()
		"settings": _open_settings()
		"quit": get_tree().quit()


func _do_continue() -> void:
	var d := _read_save()
	var names := [Settings.t("سهل", "Easy"), Settings.t("عادي", "Normal"), Settings.t("صعب", "Hard")]
	var diff := clampi(int(d.get("difficulty", 1)), 0, 2)
	_toast(Settings.t("متابعة - الصعوبة: %s - القضايا تُضاف في التحديث القادم",
		"Continue - difficulty: %s - cases arrive in the next update") % names[diff])


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(Settings.GAME_SAVE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(Settings.GAME_SAVE_PATH))
	return d if d is Dictionary else {}


func _write_save() -> void:
	var f := FileAccess.open(Settings.GAME_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"difficulty": _diff, "case": 0, "time": Time.get_unix_time_from_system()}))
	f.close()


# ------------------------------------------------------------------ panels
func _close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_lan_label = null


func _lbl(text: String, size := 32, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choice_btn(text: String, selected: bool, cb: Callable, w := 190) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 72)
	b.add_theme_font_size_override("font_size", 30)
	_style_button(b, selected)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func():
		_audio.click()
		cb.call())
	return b


func _open_panel(title: String, body: Control) -> void:
	_close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(1000, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.04, 0.11, 0.96)
	st.border_color = UV
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.set_content_margin_all(44)
	st.shadow_color = Color(GLOW, 0.3)
	st.shadow_size = 24
	pc.add_theme_stylebox_override("panel", st)
	center.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 26)
	pc.add_child(vb)
	vb.add_child(_lbl(title, 54, GLOW))
	vb.add_child(HSeparator.new())
	vb.add_child(body)
	var back := Button.new()
	back.text = Settings.t("رجوع", "Back")
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 80)
	back.add_theme_font_size_override("font_size", 34)
	_style_button(back)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(func():
		_audio.click()
		_close_panel())
	vb.add_child(back)
	dim.modulate.a = 0.0
	pc.scale = Vector2(0.94, 0.94)
	pc.pivot_offset = Vector2(500, 300)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "modulate:a", 1.0, 0.22)
	tw.tween_property(pc, "scale", Vector2.ONE, 0.22)


func _toast(msg: String) -> void:
	if is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.04, 0.15, 0.95)
	st.border_color = GLOW
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", st)
	pc.add_child(_lbl(msg, 30))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pc)
	pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_top = -70
	pc.offset_bottom = -70
	_toast_node = pc
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


# ------------------------------------------------------------------ solo
func _set_diff(i: int) -> void:
	_diff = i
	_open_solo()


func _start_story() -> void:
	_write_save()
	_close_panel()
	_refresh()
	_toast(Settings.t("تم إنشاء حفظ جديد - القضايا تُضاف في التحديث القادم",
		"New save created - cases arrive in the next update"))


func _open_solo() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.add_child(_lbl(Settings.t("اختر الصعوبة وابدأ قصة جديدة", "Pick a difficulty and start a new story")))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	var names := [Settings.t("سهل", "Easy"), Settings.t("عادي", "Normal"), Settings.t("صعب", "Hard")]
	for i in range(3):
		hb.add_child(_choice_btn(names[i], _diff == i, _set_diff.bind(i), 260))
	vb.add_child(hb)
	vb.add_child(_choice_btn(Settings.t("ابدأ القصة", "Start Story"), false, _start_story, 420))
	vb.add_child(_lbl(Settings.t("هذه نسخة القائمة الرئيسية فقط. القضايا قادمة لاحقًا.",
		"This build is the main menu only. Cases come later."), 24, Color(TEXT, 0.6)))
	_open_panel(Settings.t("لعب فردي", "Solo Play"), vb)


# ------------------------------------------------------------------ settings
func _open_settings() -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 24)

	g.add_child(_lbl(Settings.t("اللغة", "Language")))
	var hl := HBoxContainer.new()
	hl.add_theme_constant_override("separation", 14)
	hl.add_child(_choice_btn("العربية", Settings.lang == "ar", _set_lang.bind("ar")))
	hl.add_child(_choice_btn("English", Settings.lang == "en", _set_lang.bind("en")))
	g.add_child(hl)

	g.add_child(_lbl(Settings.t("الصوت", "Volume")))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = Settings.volume
	sl.custom_minimum_size = Vector2(420, 48)
	sl.value_changed.connect(func(v: float):
		Settings.volume = v
		Settings.save_settings()
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	g.add_child(sl)

	g.add_child(_lbl(Settings.t("الرسوميات", "Graphics")))
	var hq := HBoxContainer.new()
	hq.add_theme_constant_override("separation", 14)
	var qn := [Settings.t("خفيفة", "Low"), Settings.t("متوسطة", "Medium"), Settings.t("عالية", "High")]
	for i in range(3):
		hq.add_child(_choice_btn(qn[i], Settings.quality == i, _set_quality.bind(i), 170))
	g.add_child(hq)

	g.add_child(_lbl(Settings.t("حركة الجوال (جايرو)", "Tilt parallax (gyro)")))
	var cb := CheckButton.new()
	cb.button_pressed = Settings.gyro
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on: bool):
		Settings.gyro = on
		Settings.save_settings())
	g.add_child(cb)
	_open_panel(Settings.t("الإعدادات", "Settings"), g)


func _set_lang(l: String) -> void:
	Settings.lang = l
	Settings.save_settings()
	Settings.apply()
	_open_settings()


func _set_quality(q: int) -> void:
	Settings.quality = q
	Settings.save_settings()
	var old = _office
	_office = OFFICE.new()
	add_child(_office)
	move_child(_office, 0)
	old.queue_free()
	_open_settings()


# ------------------------------------------------------------------ LAN
func _local_ips() -> String:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return "  ".join(out)


func _open_lan() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.add_child(_lbl(Settings.t("اللاعبان على نفس شبكة الواي فاي. واحد يفتح غرفة والثاني ينضم.",
		"Both players on the same Wi-Fi. One hosts a room, the other joins.")))
	_lan_label = _lbl(_lan_msg, 30, GOLD)
	vb.add_child(_lan_label)
	vb.add_child(_choice_btn(Settings.t("إنشاء غرفة", "Host a room"), false, _lan_host, 420))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var ip := LineEdit.new()
	ip.placeholder_text = Settings.t("عنوان IP مثل 192.168.1.5", "Host IP e.g. 192.168.1.5")
	ip.custom_minimum_size = Vector2(520, 72)
	ip.add_theme_font_size_override("font_size", 30)
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ip)
	var join_cb := func(): _lan_join(ip.text)
	hb.add_child(_choice_btn(Settings.t("انضمام", "Join"), false, join_cb, 220))
	vb.add_child(hb)
	vb.add_child(_choice_btn(Settings.t("قطع الاتصال", "Disconnect"), false, _lan_leave, 420))
	_open_panel(Settings.t("لعب محلي (LAN)", "Local Play (LAN)"), vb)


func _set_lan_msg(m: String) -> void:
	_lan_msg = m
	if is_instance_valid(_lan_label):
		_lan_label.text = m


func _lan_host() -> void:
	_lan_leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(LAN_PORT, 3)
	if err != OK:
		_set_lan_msg(Settings.t("تعذر فتح الغرفة (خطأ %d)" % err, "Could not open the room (error %d)" % err))
		return
	multiplayer.multiplayer_peer = peer
	_set_lan_msg(Settings.t("الغرفة مفتوحة - عنوانك: ", "Room open - your IP: ") + _local_ips())


func _lan_join(addr: String) -> void:
	addr = addr.strip_edges()
	if addr.is_empty():
		_set_lan_msg(Settings.t("اكتب عنوان IP أولاً", "Enter the host IP first"))
		return
	_lan_leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, LAN_PORT)
	if err != OK:
		_set_lan_msg(Settings.t("تعذر الاتصال (خطأ %d)" % err, "Could not connect (error %d)" % err))
		return
	multiplayer.multiplayer_peer = peer
	_set_lan_msg(Settings.t("جارٍ الاتصال...", "Connecting..."))


func _lan_leave(report := true) -> void:
	var p := multiplayer.multiplayer_peer
	if p != null and not (p is OfflineMultiplayerPeer):
		p.close()
	multiplayer.multiplayer_peer = null
	if report:
		_set_lan_msg(Settings.t("تم قطع الاتصال", "Disconnected"))


func _on_peer_connected(_id: int) -> void:
	var n := multiplayer.get_peers().size() + 1
	_set_lan_msg(Settings.t("انضم لاعب - العدد: %d", "A player joined - players: %d") % n)
	_toast(_lan_msg)


func _on_peer_disconnected(_id: int) -> void:
	var n := multiplayer.get_peers().size() + 1
	_set_lan_msg(Settings.t("غادر لاعب - العدد: %d", "A player left - players: %d") % n)


func _on_connected() -> void:
	_set_lan_msg(Settings.t("تم الاتصال بالغرفة", "Connected to the room"))
	_toast(_lan_msg)


func _on_conn_failed() -> void:
	_set_lan_msg(Settings.t("فشل الاتصال - تأكد من العنوان والشبكة", "Connection failed - check the IP and network"))


func _on_server_lost() -> void:
	_set_lan_msg(Settings.t("انقطع الاتصال بالمضيف", "Lost connection to the host"))
