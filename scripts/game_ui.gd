class_name GameUI
extends CanvasLayer
## All in-game UI: HUD, interaction button, dialog + choices, phone, camera viewfinder,
## case file (hand-in), result screen, toasts, fades.

signal interact_pressed
signal phone_action(name: String)
signal shutter
signal back_to_menu
signal phone_closed
signal _advance
signal _chosen(i: int)

var auto: Array = []        # scripted choices (used by automated tests)
var fast := false           # skip dialog waiting (tests)
var auto_file = null        # scripted case-file answer (tests)
var notes_provider: Callable
var player                  # Player (for joystick drawing)
var modal_open := false

var _root: Control
var _hud_label: Label
var _money_label: Label
var _phone_btn: Button
var _interact: Button
var _tap: Control
var _dlg: PanelContainer
var _who: Label
var _txt: Label
var _hint: Label
var _choices: GridContainer
var _typing := false
var _type_tw: Tween
var _phone: Control
var _modal: Control
var _fade: ColorRect
var _toast_node: Control
var _cam_overlay: Control
var camera_mode := false
var _stick: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_hud()
	_build_dialog()
	_build_camera_overlay()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	Game.changed.connect(_refresh_hud)
	Settings.changed.connect(_refresh_hud)
	_root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Settings.is_ar() else Control.LAYOUT_DIRECTION_LTR
	_refresh_hud()


func _process(_d: float) -> void:
	if _stick != null:
		_stick.queue_redraw()


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	_stick = Control.new()
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(_draw_stick)
	_root.add_child(_stick)

	var top := UIKit.panel(0.75)
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(24, 20)
	_root.add_child(top)
	var vb := VBoxContainer.new()
	top.add_child(vb)
	_hud_label = UIKit.label("", 26, UIKit.TEXT, false)
	_money_label = UIKit.label("", 26, UIKit.GOLD, false)
	vb.add_child(_hud_label)
	vb.add_child(_money_label)

	_phone_btn = UIKit.button(Settings.t("الهاتف", "Phone"), 30, Vector2(210, 84))
	_phone_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_phone_btn.position = Vector2(-240, 24)
	_phone_btn.pressed.connect(open_phone)
	_root.add_child(_phone_btn)

	_interact = UIKit.button("", 34, Vector2(380, 110))
	_interact.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_interact.position = Vector2(-410, -160)
	_interact.visible = false
	_interact.pressed.connect(func(): interact_pressed.emit())
	_root.add_child(_interact)


func block_rects() -> Array:
	var out: Array = []
	for c in [_phone_btn, _interact]:
		if c != null and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	return out


func _draw_stick() -> void:
	if player == null or player.stick_touch == -1:
		return
	_stick.draw_circle(player.stick_origin, 90.0, Color(1, 1, 1, 0.07))
	_stick.draw_arc(player.stick_origin, 90.0, 0.0, TAU, 40, Color(UIKit.GLOW, 0.5), 3.0)
	_stick.draw_circle(player.stick_origin + player.stick_vec * 90.0, 34.0, Color(UIKit.GLOW, 0.55))


func _refresh_hud() -> void:
	if _hud_label == null:
		return
	_root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Settings.is_ar() else Control.LAYOUT_DIRECTION_LTR
	var sl := int(Game.s["slot"])
	_hud_label.text = Settings.t("اليوم %d / 3  -  الفترة %d / %d", "Day %d / 3  -  Slot %d / %d") % [Game.day(), mini(sl + 1, Game.MAX_SLOTS), Game.MAX_SLOTS]
	_money_label.text = Settings.t("المال: %d", "Money: %d") % int(Game.s["money"])
	_phone_btn.text = Settings.t("الهاتف", "Phone")


func set_hotspot(label: String) -> void:
	_interact.visible = label != "" and not modal_open and not _dlg.visible
	_interact.text = label


func set_hud_visible(v: bool) -> void:
	for c in _root.get_children():
		if c != _fade and c != _dlg and c != _tap and c != _stick:
			c.visible = v and (c != _interact)


# ------------------------------------------------------------------ dialog
func _build_dialog() -> void:
	_tap = Control.new()
	_tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap.visible = false
	_tap.gui_input.connect(_on_tap)
	_root.add_child(_tap)
	_dlg = UIKit.panel(0.95)
	_dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dlg.offset_left = 120
	_dlg.offset_right = -120
	_dlg.offset_top = -420
	_dlg.offset_bottom = -30
	_dlg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dlg.visible = false
	_dlg.gui_input.connect(_on_tap)
	_root.add_child(_dlg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_dlg.add_child(vb)
	_who = UIKit.label("", 34, UIKit.GLOW, false)
	vb.add_child(_who)
	_txt = UIKit.label("", 32)
	_txt.custom_minimum_size = Vector2(0, 96)
	vb.add_child(_txt)
	_choices = GridContainer.new()
	_choices.columns = 2
	_choices.add_theme_constant_override("h_separation", 14)
	_choices.add_theme_constant_override("v_separation", 10)
	vb.add_child(_choices)
	_hint = UIKit.label(Settings.t("اضغط للمتابعة", "Tap to continue"), 22, Color(UIKit.TEXT, 0.5), false)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_hint)


func _on_tap(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if _choices.get_child_count() > 0:
		return
	if _typing:
		if _type_tw:
			_type_tw.kill()
		_txt.visible_characters = -1
		_typing = false
		return
	_advance.emit()


func say(who: String, text: String, color := UIKit.GLOW, npc = null) -> void:
	if fast:
		return
	_clear_choices()
	_dlg.visible = true
	_tap.visible = true
	_interact.visible = false
	_who.text = who
	_who.add_theme_color_override("font_color", color)
	_txt.text = text
	_txt.visible_characters = 0
	_hint.text = Settings.t("اضغط للمتابعة", "Tap to continue")
	_hint.visible = true
	if npc != null and is_instance_valid(npc):
		npc.speak(text.length() * 0.045)
	_typing = true
	_type_tw = create_tween()
	_type_tw.tween_property(_txt, "visible_characters", text.length(), maxf(text.length() * 0.016, 0.2))
	_type_tw.tween_callback(func(): _typing = false)
	await _advance


func choose(opts: Array, prompt := "", columns := 2) -> int:
	if auto.size() > 0:
		return int(auto.pop_front())
	if fast:
		return 0
	_clear_choices()
	_dlg.visible = true
	_tap.visible = true
	_interact.visible = false
	if prompt != "":
		_txt.text = prompt
		_txt.visible_characters = -1
	_hint.visible = false
	_choices.columns = columns
	for i in range(opts.size()):
		var b := UIKit.button(str(opts[i]), 28, Vector2(0, 66))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _chosen.emit(i))
		_choices.add_child(b)
	var idx: int = await _chosen
	_clear_choices()
	return idx


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func close_dialog() -> void:
	_clear_choices()
	_dlg.visible = false
	_tap.visible = false


func dialog_open() -> bool:
	return _dlg.visible


# ------------------------------------------------------------------ small effects
func toast(msg: String) -> void:
	if is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var row := CenterContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_top = 110
	row.offset_bottom = 230
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := UIKit.panel(0.96, UIKit.GLOW)
	var tl := UIKit.label(msg, 28)
	tl.custom_minimum_size = Vector2(minf(220.0 + msg.length() * 15.0, 1000.0), 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(tl)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pc)
	_root.add_child(row)
	_toast_node = row
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.5)
	tw.tween_callback(row.queue_free)


func fade_to(a: float, dur := 0.8) -> void:
	if fast:
		_fade.color.a = a
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, dur)
	await tw.finished


func flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.8)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.25)
	tw.tween_callback(f.queue_free)


func card(title: String, sub: String, dur := 2.6) -> void:
	_fade.color.a = 1.0
	var t := UIKit.label(title, 70, UIKit.GLOW, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := UIKit.label(sub, 32, UIKit.TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.custom_minimum_size = Vector2(1100, 0)
	vb.add_child(t)
	vb.add_child(s)
	vb.modulate.a = 0.0
	_root.add_child(vb)
	if fast:
		vb.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(vb, "modulate:a", 1.0, 0.7)
	tw.tween_interval(dur)
	tw.tween_property(vb, "modulate:a", 0.0, 0.6)
	await tw.finished
	vb.queue_free()


# ------------------------------------------------------------------ modal helper
func _open_modal(width := 1100) -> VBoxContainer:
	_close_modal()
	modal_open = true
	_interact.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_root.move_child(dim, _root.get_child_count() - 2)   # keep the fade on top
	_modal = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var pc := UIKit.panel(0.97)
	pc.custom_minimum_size = Vector2(width, 0)
	center.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)
	return vb


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	modal_open = false


# ------------------------------------------------------------------ phone
func open_phone() -> void:
	if _dlg.visible or modal_open:
		return
	var vb := _open_modal(760)
	vb.add_child(UIKit.label(Settings.t("الهاتف", "Phone"), 46, UIKit.GLOW, false))
	vb.add_child(HSeparator.new())
	var apps := [
		[Settings.t("الكاميرا", "Camera"), "camera"],
		[Settings.t("المعرض والأدلة", "Gallery & evidence"), "gallery"],
		[Settings.t("الملاحظات", "Notes"), "notes"],
		[Settings.t("اتصال بهيثم (%d متبقية)", "Call Haitham (%d left)") % int(Game.s["calls_left"]), "haitham"],
	]
	for a in apps:
		var b := UIKit.button(a[0], 32, Vector2(0, 78))
		var name: String = a[1]
		b.pressed.connect(_phone_pick.bind(name))
		vb.add_child(b)
	var back := UIKit.button(Settings.t("إغلاق", "Close"), 30, Vector2(0, 70))
	back.pressed.connect(close_phone)
	vb.add_child(back)


func close_phone() -> void:
	_close_modal()
	phone_closed.emit()


func _phone_pick(name: String) -> void:
	match name:
		"camera":
			_close_modal()
			set_camera_mode(true)
		"gallery":
			_show_gallery()
		"notes":
			_show_notes()
		"haitham":
			_close_modal()
			phone_action.emit("haitham")


func _show_gallery() -> void:
	var vb := _open_modal(900)
	vb.add_child(UIKit.label(Settings.t("المعرض والأدلة", "Gallery & evidence"), 44, UIKit.GLOW, false))
	vb.add_child(HSeparator.new())
	var any := false
	for id in Game.s["evidence"]:
		any = true
		var q := Game.ev_quality(id)
		var tag := Settings.t("جودة جيدة", "good quality") if q == "good" else Settings.t("جودة ضعيفة", "poor quality")
		if Game.kind(id) == "lead":
			tag = Settings.t("خيط", "lead")
		vb.add_child(UIKit.label("- %s  [%s]" % [Game.ev_name(id), tag], 28))
	if not any:
		vb.add_child(UIKit.label(Settings.t("لا توجد صور أو أدلة بعد.", "No photos or evidence yet."), 28))
	var back := UIKit.button(Settings.t("رجوع", "Back"), 30, Vector2(0, 70))
	back.pressed.connect(open_phone_again)
	vb.add_child(back)


func _show_notes() -> void:
	var vb := _open_modal(900)
	vb.add_child(UIKit.label(Settings.t("الملاحظات", "Notes"), 44, UIKit.GLOW, false))
	vb.add_child(HSeparator.new())
	var text := ""
	if notes_provider.is_valid():
		text = str(notes_provider.call())
	vb.add_child(UIKit.label(text, 28))
	var back := UIKit.button(Settings.t("رجوع", "Back"), 30, Vector2(0, 70))
	back.pressed.connect(open_phone_again)
	vb.add_child(back)


func open_phone_again() -> void:
	_close_modal()
	open_phone()


# ------------------------------------------------------------------ camera viewfinder
func _build_camera_overlay() -> void:
	_cam_overlay = Control.new()
	_cam_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam_overlay.visible = false
	_root.add_child(_cam_overlay)
	_cam_overlay.draw.connect(func():
		var sz := _cam_overlay.size
		var c := sz * 0.5
		var col := Color(1, 1, 1, 0.8)
		_cam_overlay.draw_rect(Rect2(sz.x * 0.2, sz.y * 0.15, sz.x * 0.6, sz.y * 0.7), col, false, 3.0)
		_cam_overlay.draw_line(c + Vector2(-26, 0), c + Vector2(26, 0), col, 2.0)
		_cam_overlay.draw_line(c + Vector2(0, -26), c + Vector2(0, 26), col, 2.0))
	var shut := UIKit.button(Settings.t("التقاط", "Capture"), 34, Vector2(260, 100))
	shut.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	shut.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shut.offset_top = -150
	shut.offset_bottom = -50
	shut.pressed.connect(func(): shutter.emit())
	_cam_overlay.add_child(shut)
	var ex := UIKit.button(Settings.t("خروج", "Exit"), 30, Vector2(200, 80))
	ex.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ex.position = Vector2(-230, 24)
	ex.pressed.connect(func(): set_camera_mode(false))
	_cam_overlay.add_child(ex)
	_cam_overlay.set_meta("buttons", [shut, ex])


func set_camera_mode(on: bool) -> void:
	camera_mode = on
	_cam_overlay.visible = on
	_cam_overlay.queue_redraw()
	_phone_btn.visible = not on
	if on:
		_interact.visible = false


func camera_block_rects() -> Array:
	var out: Array = []
	if camera_mode:
		for b in _cam_overlay.get_meta("buttons"):
			out.append(b.get_global_rect())
	return out


# ------------------------------------------------------------------ case file (hand-in)
## Returns {} if cancelled, else {selected, accused, delivery}.
func open_case_file(can_police: bool) -> Dictionary:
	if auto_file != null:
		return auto_file
	var vb := _open_modal(1200)
	vb.add_child(UIKit.label(Settings.t("ملف القضية - تسليم", "Case file - hand in"), 44, UIKit.GLOW, false))
	vb.add_child(HSeparator.new())
	vb.add_child(UIKit.label(Settings.t("اختر ما تضعه في الملف (الدليل المضلل يخصم نقاطًا):", "Choose what goes in the file (misleading evidence costs points):"), 26))
	var checks := {}
	var any := false
	for id in Game.s["evidence"]:
		if Game.kind(id) == "lead":
			continue
		any = true
		var cb := CheckButton.new()
		cb.text = "%s  [%s]" % [Game.ev_name(id), Settings.t("جيدة", "good") if Game.ev_quality(id) == "good" else Settings.t("ضعيفة", "poor")]
		cb.add_theme_font_size_override("font_size", 26)
		cb.focus_mode = Control.FOCUS_NONE
		vb.add_child(cb)
		checks[id] = cb
	if not any:
		vb.add_child(UIKit.label(Settings.t("لا أدلة في الحقيبة.", "No evidence collected."), 26))
	vb.add_child(UIKit.label(Settings.t("من المتهم؟", "Who is the culprit?"), 28, UIKit.GOLD))
	var acc := {"v": "company"}
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	var b_company := UIKit.button(Settings.t("شركة التأمين (سلمى والمدير)", "The insurance company"), 26, Vector2(0, 66))
	var b_owner := UIKit.button(Settings.t("أبو فراس (صاحب المبنى)", "Abu Firas (the owner)"), 26, Vector2(0, 66))
	b_company.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_button(b_company, true)
	b_company.pressed.connect(func():
		acc["v"] = "company"
		UIKit.style_button(b_company, true)
		UIKit.style_button(b_owner, false))
	b_owner.pressed.connect(func():
		acc["v"] = "owner"
		UIKit.style_button(b_company, false)
		UIKit.style_button(b_owner, true))
	row1.add_child(b_company)
	row1.add_child(b_owner)
	vb.add_child(row1)
	vb.add_child(UIKit.label(Settings.t("سلّم الملف إلى:", "Hand the file to:"), 28, UIKit.GOLD))
	var dl := {"v": "police" if can_police else "press"}
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	var b_pol := UIKit.button(Settings.t("الشرطة (بطيئة وبغطاء قانوني)", "Police (slow, legal cover)"), 26, Vector2(0, 66))
	var b_press := UIKit.button(Settings.t("الصحفية ليلى (تضغط لكن تحرق القضية)", "Journalist Layla (pressure, burns the case)"), 26, Vector2(0, 66))
	b_pol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_press.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_pol.disabled = not can_police
	UIKit.style_button(b_pol if can_police else b_press, true)
	b_pol.pressed.connect(func():
		dl["v"] = "police"
		UIKit.style_button(b_pol, true)
		UIKit.style_button(b_press, false))
	b_press.pressed.connect(func():
		dl["v"] = "press"
		UIKit.style_button(b_pol, false)
		UIKit.style_button(b_press, true))
	row2.add_child(b_pol)
	row2.add_child(b_press)
	vb.add_child(row2)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 12)
	var submit := UIKit.button(Settings.t("تسليم الملف", "Submit the file"), 32, Vector2(0, 78))
	var cancel := UIKit.button(Settings.t("رجوع", "Back"), 30, Vector2(0, 78))
	submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(submit)
	row3.add_child(cancel)
	vb.add_child(row3)
	var done := {"r": null}
	submit.pressed.connect(func():
		var sel: Array = []
		for id in checks:
			if checks[id].button_pressed:
				sel.append(id)
		done["r"] = {"selected": sel, "accused": acc["v"], "delivery": dl["v"]}
		_chosen.emit(1))
	cancel.pressed.connect(func():
		done["r"] = {}
		_chosen.emit(0))
	await _chosen
	_close_modal()
	return done["r"]


func show_result(r: Dictionary, lines: Array) -> void:
	var vb := _open_modal(1100)
	vb.add_child(UIKit.label(Settings.t("نتيجة القضية", "Case result"), 50, UIKit.GLOW, false))
	vb.add_child(HSeparator.new())
	for l in lines:
		vb.add_child(UIKit.label(str(l), 28))
	var b := UIKit.button(Settings.t("القائمة الرئيسية", "Main menu"), 32, Vector2(0, 80))
	b.pressed.connect(func(): back_to_menu.emit())
	var c := UIKit.button(Settings.t("متابعة في المكتب", "Stay in the office"), 30, Vector2(0, 70))
	c.pressed.connect(_close_modal)
	vb.add_child(c)
	vb.add_child(b)
