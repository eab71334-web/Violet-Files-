extends Node
## Case 1 "Under Rent" (insurance fraud) - the vertical slice from the design document:
## office + negotiating client + one witness with the hidden-tension system + 3 phone-found evidence + hand-in.

var world
var ui: GameUI
var haitham: BlockyPerson
var client: BlockyPerson
var salma: BlockyPerson

const C_FIRAS := Color("F2B84B")
const C_HAITHAM := Color("6ed4ff")
const C_SALMA := Color("ff7a8a")
const C_YOU := Color("B66DFF")


func t(ar: String, en: String) -> String:
	return Settings.t(ar, en)


# ---------------------------------------------------------------- people
func _cfg_haitham() -> Dictionary:
	return {"skin": Color(0.78, 0.6, 0.46), "shirt": Color(0.35, 0.22, 0.55), "pants": Color(0.15, 0.18, 0.28),
		"hair": Color(0.05, 0.05, 0.06), "glasses": true, "hair_style": "short"}


func _cfg_firas() -> Dictionary:
	return {"skin": Color(0.72, 0.52, 0.38), "shirt": Color(0.62, 0.55, 0.42), "pants": Color(0.18, 0.17, 0.16),
		"hair": Color(0.55, 0.55, 0.55), "mustache": true, "belly": 1.35, "blink_mult": 2.6, "hair_style": "short"}


func _cfg_salma() -> Dictionary:
	return {"skin": Color(0.85, 0.68, 0.58), "shirt": Color(0.12, 0.14, 0.22), "pants": Color(0.1, 0.1, 0.14),
		"hair": Color(0.04, 0.03, 0.03), "hair_style": "long", "pen": true, "blink_mult": 0.6, "tie": Color("8A2BE2")}


func _spawn(cfg: Dictionary, pos: Vector3, yaw: float, sitting: bool) -> BlockyPerson:
	var p := BlockyPerson.new()
	world.loc.add_child(p)
	p.build(cfg)
	p.global_position = pos
	p.rotation.y = yaw
	p.sit_instant(sitting)
	return p


func _attach_hotspot(p: BlockyPerson, id: String, ar: String, en: String) -> void:
	var hs: StaticBody3D = world.loc.add_hotspot(id, Vector3.ZERO, Vector3(0.8, 1.9, 0.8), ar, en)
	hs.reparent(p, false)
	hs.position = Vector3(0, 0.9, 0)


func _go(p: BlockyPerson, pts: Array) -> void:
	if ui.fast:
		var last: Vector3 = pts[pts.size() - 1]
		p.global_position = Vector3(last.x, 0, last.z)
		return
	await p.walk_path(pts)


func on_location(n: String) -> void:
	haitham = null
	client = null
	salma = null
	if n != "office":
		return
	haitham = _spawn(_cfg_haitham(), Vector3(2.15, 0, 0.9), PI * 0.5, true)
	haitham.typing = true
	_attach_hotspot(haitham, "haitham", "هيثم (المساعد)", "Haitham (assistant)")


func _wait(sec: float) -> void:
	if not ui.fast:
		await get_tree().create_timer(sec).timeout


# ---------------------------------------------------------------- start
func start() -> void:
	var st := str(Game.s["stage"])
	if st == "new":
		await ui.card(t("ميرفا", "Merva"), t("اليوم الأول - ٩:٠٠ صباحًا\nالقضية ١: تحت الإيجار", "Day 1 - 9:00 AM\nCase 1: Under Rent"), 2.6)
		world.go_location("office")
		await ui.fade_to(0.0, 1.2)
		world.busy = true
		await _intro_and_negotiate()
		world.busy = false
	else:
		world.go_location("office")
		await ui.fade_to(0.0, 1.0)
		if st == "done":
			ui.toast(t("القضية ١ مكتملة. القضايا التالية في التحديث القادم.", "Case 1 is complete. More cases in the next update."))
		else:
			ui.toast(t("تابع القضية - الهاتف > الملاحظات", "Continue the case - Phone > Notes"))


func _intro_and_negotiate() -> void:
	await ui.say(t("هيثم", "Haitham"), t("صباح الخير يا سيدي. فيه زبون عند الباب: أبو فراس، صاحب مبنى في حي الصدأ. أدخله؟", "Good morning, boss. A client at the door: Abu Firas, owner of a building in Rust district. Send him in?"), C_HAITHAM, haitham)
	await ui.choose([t("أدخله", "Send him in")])
	ui.close_dialog()
	client = _spawn(_cfg_firas(), Vector3(-3.0, 0, 0.6), PI * 0.5, false)
	client.look_target = world.player.cam
	client.emotion = "worried"
	client.tension = 20.0
	await _go(client, [Vector3(-2.0, 0, 0.6), Vector3(-1.75, 0, -1.9), Vector3(0.2, 0, -1.9)])
	client.face_pos(Vector3(0.2, 0, 2.0), 0.1)
	await _wait(0.3)
	client.sitting = true
	await _wait(0.5)
	await _negotiate()


func _negotiate() -> void:
	var nm := t("أبو فراس", "Abu Firas")
	var offers := [600, 750, 900]
	var r := 0
	var asked := false
	await ui.say(nm, t("أنا أبو فراس، صاحب مبنى في حي الصدأ. شركة التأمين تقول إني حرقته بنفسي لأقبض التأمين! أنا ما حرقت شيئًا. أدفع لك %d لتثبت براءتي.", "I'm Abu Firas, I own a building in Rust district. The insurance company says I burned it myself for the payout! I burned nothing. I'll pay you %d to prove my innocence.") % offers[0], C_FIRAS, client)
	while true:
		var labels := [t("أقبل %d", "Accept %d") % offers[r], t("هذا قليل - أريد أكثر", "That's too little - I want more")]
		var acts := ["accept", "more"]
		if not asked:
			labels.append(t("اسأله عن الحريق", "Ask him about the fire"))
			acts.append("ask")
		labels.append(t("اطرده (افتح له الباب)", "Throw him out (open the door)"))
		acts.append("eject")
		var i := await ui.choose(labels, t("ماذا ترد؟", "What do you answer?"))
		var act: String = acts[i]
		if act == "ask":
			asked = true
			await ui.say(nm, t("كل ما أملك صرفته على ترميمه بعد ما أمّنت عليه! لماذا أحرقه؟ والمطر جاي بكرا، لا تتأخر على السطح، الآثار تروح.", "I spent everything I had renovating it after I took the policy! Why would I burn it? And rain is coming tomorrow, don't be late to the roof, the marks will wash away."), C_FIRAS, client)
			ui.toast(t("لاحظ: يرمش كثيرًا وهو صادق. هذا طبعه (خط الأساس).", "Notice: he blinks a lot while honest. That's just him (his baseline)."))
		elif act == "more":
			r += 1
			client.emotion = "angry"
			client.tension += 28.0
			if r >= 3:
				client.tension = 90.0
				await ui.say(nm, t("كفى مساومة! ما عندي أكثر من هذا!", "Enough haggling! I have nothing more to give!"), C_FIRAS, client)
				await _client_leaves()
				await _fail("walkout")
				return
			await ui.say(nm, t("طيب... %d. هذا آخر ما أستطيع، رجاءً!", "Fine... %d. That's the most I can do, please!") % offers[r], C_FIRAS, client)
		elif act == "eject":
			Game.s["ejected"] = true
			await ui.say(t("أنت", "You"), t("تفضّل، الباب هناك.", "Please, the door is over there."), C_YOU)
			client.emotion = "angry"
			await ui.say(nm, t("ستندم على هذا!", "You'll regret this!"), C_FIRAS, client)
			await _client_leaves()
			await _fail("ejected")
			return
		else:
			Game.s["fee"] = offers[r]
			Game.s["stage"] = "active"
			Game.save()
			client.emotion = "neutral"
			client.tension = 10.0
			await ui.say(nm, t("الله يعطيك العافية يا أستاذ. ابدأ من السطح بسرعة.", "God bless you, sir. Start with the roof, quickly."), C_FIRAS, client)
			await ui.say(t("هيثم", "Haitham"), t("تمام يا سيدي. افتح الهاتف > الملاحظات لتشوف خطوات القضية، وأنا هنا لو احتجت أي بحث.", "Got it, boss. Open Phone > Notes for the steps, and I'm here if you need any search."), C_HAITHAM, haitham)
			ui.close_dialog()
			await _client_leaves()
			ui.toast(t("بدأت القضية: أتعابك %d", "Case started: your fee is %d") % int(Game.s["fee"]))
			return


func _client_leaves() -> void:
	ui.close_dialog()
	if client == null:
		return
	client.sitting = false
	await _wait(0.5)
	await _go(client, [Vector3(-1.75, 0, -1.9), Vector3(-2.0, 0, 0.6), Vector3(-3.0, 0, 0.6)])
	client.queue_free()
	client = null


# ---------------------------------------------------------------- failing / finishing
func _fail(kind: String) -> void:
	ui.close_dialog()
	var r := {"ev": 0, "verdict": 0, "style": 0, "time": 0, "total": 0, "tier": "fail", "reward": 0,
		"accused": "none", "delivery": "none", "yasser": false, "reason": kind}
	Game.finish_case(r)
	await ui.show_result(r, _result_lines(r))


func _result_lines(r: Dictionary) -> Array:
	var out: Array = []
	var reason := str(r.get("reason", ""))
	if reason == "walkout":
		out.append(t("أبو فراس غادر غاضبًا بعد أن ساومته كثيرًا. لا قضية ولا أتعاب.", "Abu Firas walked out angry after too much haggling. No case, no fee."))
	elif reason == "ejected":
		out.append(t("طردت الزبون. سمعتك في الحي تنزل ولا قضية اليوم.", "You threw the client out. Your name drops in the neighbourhood and there's no case today."))
	elif reason == "deadline":
		out.append(t("انتهت المهلة قبل تسليم الملف. سحب أبو فراس القضية.", "The deadline passed before you handed the file in. Abu Firas pulled the case."))
	else:
		out.append(t("الأدلة %d/40  -  الحكم %d/30  -  الأسلوب %d/15  -  الوقت %d/15  =  %d/100", "Evidence %d/40  -  Verdict %d/30  -  Style %d/15  -  Time %d/15  =  %d/100") % [r["ev"], r["verdict"], r["style"], r["time"], r["total"]])
		var acc := str(r["accused"])
		var tier := str(r["tier"])
		if acc == "owner":
			out.append(t("اتهمتَ أبو فراس: يُسجن ظلمًا، تحصل على ٣٠٪ ويعود عدوًا في الموسم الثاني. وشركة التأمين تعرض عليك عملًا دائمًا (فخ).", "You accused Abu Firas: he's jailed unjustly, you get 30% and he returns as an enemy in season two. The insurance company offers you a permanent job (a trap)."))
		elif tier == "full" or tier == "partial":
			if str(r["delivery"]) == "police":
				out.append(t("الشرطة تقبض على سلمى والمدير (ببطء وبغطاء قانوني). أبو فراس يدفع ويصير صديقًا في الحي.", "The police arrest Salma and the manager (slowly, with legal cover). Abu Firas pays and becomes a friend in the neighbourhood."))
			else:
				out.append(t("ليلى تنشر القصة وتضغط على الشركة، لكن القضية احترقت إعلاميًا والمدير يهرب قبل القبض عليه.", "Layla publishes and pressures the company, but the case is burned in the media and the manager flees before an arrest."))
			if tier == "partial":
				out.append(t("نجاح جزئي: ٧٠٪ من الأتعاب، وجزء من التهمة يفلت منه المتهمون.", "Partial success: 70% of the fee, and part of the charge slips away from the culprits."))
		elif tier == "rejected":
			out.append(t("الملف مرفوض: أدلة ناقصة أو مضلِّلة. تحصل على ٣٠٪.", "File rejected: weak or misleading evidence. You get 30%."))
		else:
			out.append(t("الملف لم يقنع أحدًا. بلا أتعاب، وخصم جديد ينتظرك في موسم لاحق.", "The file convinced nobody. No fee, and a new enemy waits for you in a later season."))
		if Game.s["bribe"] == "took":
			out.append(t("قبلتَ رشوة سلمى (+١٥٠٠) لكن الشرطة فقدت ثقتها بك.", "You took Salma's bribe (+1500) but the police no longer trust you."))
		elif Game.s["bribe"] == "recorded":
			out.append(t("سجّلتَ الرشوة بمسجل مخفي: دليل قوي لكنه رمادي.", "You recorded the bribe with a hidden recorder: strong but grey evidence."))
		if bool(r.get("yasser", false)):
			out.append(t("قطعة ياسر: اسم ياسر مكتوب في دفتر زوار الشركة قبل اختفائه.", "Yasser's piece: Yasser's name is in the company's visitor book before he vanished."))
	out.append(t("الأتعاب المستلمة: %d", "Fee received: %d") % int(r["reward"]))
	return out


# ---------------------------------------------------------------- interactions
func _active() -> bool:
	return str(Game.s["stage"]) == "active"


func _you(text: String) -> void:
	await ui.say(t("أنت", "You"), text, C_YOU)
	ui.close_dialog()


func interact(id: String, _h) -> void:
	match id:
		"door":
			await _door()
		"stairs":
			await _go_back()
		"computer", "haitham":
			await haitham_menu(false)
		"landline":
			await _landline()
		"board":
			await ui.say(t("لوحة التحقيق", "Investigation board"), notes_text(), C_YOU)
			ui.close_dialog()
		"folder":
			await _folder()
		"burn":
			await _you(t("آثار سوداء على السطح نفسه، لا في المطبخ. يجب تصويرها بالهاتف من مكان قريب.", "Black marks on the roof itself, not the kitchen. I should photograph them with the phone from up close."))
		"gas":
			await _you(t("علبة بنزين بجانب مولد الكهرباء. قد تكون لها علاقة... أو لا.", "A petrol can next to the electric generator. It might matter... or not."))
		"letter":
			await _you(t("رسالة مثبتة على الجدار بخط اليد: «سأحرق مبناك». من جار غاضب على ما يبدو.", "A handwritten letter on the wall: \"I'll burn your building\". Seems to be from an angry neighbour."))
		"campole":
			await _you(t("كاميرا مراقبة على المبنى المقابل تطل على الزقاق. لقطاتها قد تكون مهمة. يمكنني تصويرها وإرسالها لهيثم.", "A surveillance camera on the building opposite, facing the alley. Its footage could matter. I can photograph it and send it to Haitham."))
			if not Game.has_ev("cam_pole"):
				ui.toast(t("صوّر الكاميرا بالهاتف لتكون خيطًا لهيثم.", "Photograph it with the phone to give Haitham a lead."))


func _door() -> void:
	if not _active():
		await _you(t("لا حاجة للخروج الآن.", "No need to go out right now."))
		return
	var i := await ui.choose([t("الصعود إلى سطح المبنى المحترق (فترة واحدة)", "Go to the burned building's roof (1 slot)"), t("البقاء", "Stay")], t("إلى أين؟", "Where to?"))
	ui.close_dialog()
	if i != 0:
		return
	Game.use_slot(1)
	Game.save()
	await ui.fade_to(1.0, 0.7)
	world.go_location("roof")
	await ui.fade_to(0.0, 0.9)
	if Game.raining_washed():
		ui.toast(t("المطر بدأ يمسح الآثار على السطح!", "The rain has started washing the marks off the roof!"))
	else:
		ui.toast(t("افتح الهاتف > الكاميرا وصوّر ما يهمك من قرب.", "Open Phone > Camera and photograph what matters, up close."))
	if Game.slots_left() <= 0:
		await _deadline()


func _go_back() -> void:
	await ui.fade_to(1.0, 0.6)
	world.go_location("office")
	await ui.fade_to(0.0, 0.8)


func _deadline() -> void:
	if not _active():
		return
	await ui.say(t("أنت", "You"), t("انتهت المهلة...", "The deadline has passed..."), C_YOU)
	await _fail("deadline")


func _board_hint() -> String:
	return ""


# ---------------------------------------------------------------- Haitham
func phone_haitham() -> void:
	if not _active():
		ui.toast(t("لا قضية جارية.", "No active case."))
		return
	if int(Game.s["calls_left"]) <= 0:
		ui.toast(t("انتهت مكالماتك لهذه القضية.", "No calls left for this case."))
		return
	Game.s["calls_left"] = int(Game.s["calls_left"]) - 1
	Game.changed.emit()
	await haitham_menu(true)


func haitham_menu(via_phone: bool) -> void:
	var nm := t("هيثم", "Haitham")
	if not _active():
		await ui.say(nm, t("لا قضية جارية الآن يا سيدي. أرتب الأرشيف.", "No active case right now, boss. I'm tidying the archive."), C_HAITHAM, haitham)
		ui.close_dialog()
		return
	if via_phone:
		await ui.say(nm, t("ألو يا سيدي؟ قل لي شنو تحتاج، وأرد عليك بعد تأخير.", "Hello boss? Tell me what you need, I'll get back after a delay."), C_HAITHAM)
	while true:
		var labels := [
			t("ابحث عن فواتير المبنى والبوليصة (فترة + ٣٠)", "Search the building's invoices & policy (1 slot, 30)"),
			t("استرجع لقطات كاميرا الشارع (فترة + ٣٠)", "Pull the street-camera footage (1 slot, 30)"),
			t("ذكّرني بالخيوط المفتوحة", "Remind me of the open leads"),
			t("اسأله عن نفسه", "Ask about him"),
			t("لا شيء الآن", "Nothing for now")]
		var i := await ui.choose(labels, t("هيثم: ماذا تريد؟", "Haitham: what do you need?"), 1)
		if i == 0:
			await _task("bills", "renov_bill",
				t("لقيت فاتورة ترميم بثلاثة آلاف وخمسمئة بتاريخ ٣ مارس. وبوليصة التأمين مؤرخة ١٠ فبراير، يعني الترميم بعد التأمين. ما أعرف شنو معناها، التفسير عليك.", "I found a renovation invoice for 3,500 dated March 3rd. The insurance policy is dated February 10th, so the renovation came after the policy. I can't tell you what it means, the interpretation is yours."))
		elif i == 1:
			if not Game.has_ev("cam_pole"):
				await ui.say(nm, t("أي كاميرا؟ ما عندي خيط. لو شفت كاميرا مراقبة قرب المبنى صوّرها وأرسلها لي.", "Which camera? I have no lead. If you see a surveillance camera near the building, photograph it and send it to me."), C_HAITHAM, haitham)
			else:
				await _task("footage", "street_cam",
					t("الساعة ٨:١٠ مساءً مرّت سيارة بيضاء بشعار على بابها في الزقاق، والحريق بدأ ٩:١٥. اللوحة غير واضحة وما أقدر أقول لك لمن هي.", "At 8:10 pm a white car with a logo on its door passed through the alley; the fire started at 9:15. The plate is unclear and I can't tell you whose it is."))
		elif i == 2:
			await ui.say(nm, notes_text(), C_HAITHAM, haitham)
		elif i == 3:
			await ui.say(nm, t("أنا هيثم، متدرب جامعي أدرس الحاسوب. أرد على الهاتف وأرتب الأرشيف وأشغّل الكمبيوتر. صفاتي: السرعة والدقة والولاء، وكلها تزيد مع التدريب والراتب الأعلى. أنا لا أقرأ الشهود ولا أحكم، وأخطئ أحيانًا.", "I'm Haitham, a university trainee studying computing. I answer the phone, tidy the archive and run the computer. My traits are speed, accuracy and loyalty, and they grow with training and higher pay. I don't read witnesses or judge, and I sometimes get it wrong."), C_HAITHAM, haitham)
		else:
			break
		if Game.slots_left() <= 0:
			break
	ui.close_dialog()
	if Game.slots_left() <= 0:
		await _deadline()


func _task(key: String, ev: String, answer: String) -> void:
	var nm := t("هيثم", "Haitham")
	if Game.s["done_tasks"].has(key):
		await ui.say(nm, t("أعطيتك هذا سابقًا يا سيدي.", "I already gave you this, boss."), C_HAITHAM, haitham)
		return
	Game.s["done_tasks"].append(key)
	Game.s["money"] = int(Game.s["money"]) - 30
	Game.use_slot(1)
	Game.add_ev(ev, "good")
	Game.save()
	await ui.say(nm, answer, C_HAITHAM, haitham)
	ui.toast(t("دليل جديد: %s", "New evidence: %s") % Game.ev_name(ev))


# ---------------------------------------------------------------- Salma (hidden tension system)
func _landline() -> void:
	if not _active():
		await _you(t("لا أحد أتصل به الآن.", "Nobody to call right now."))
		return
	var st := str(Game.s["salma"])
	if st == "cracked" or st == "left":
		await _you(t("لن تعود سلمى. ما عندي سبب لمكالمتها ثانية.", "Salma won't come back. No reason to call her again."))
		return
	var i := await ui.choose([t("اتصل بسلمى (شركة التأمين) واطلب لقاءً (فترة)", "Call Salma (the insurance company) and ask for a meeting (1 slot)"), t("لا", "No")], t("الهاتف الأرضي", "Landline"))
	ui.close_dialog()
	if i != 0:
		return
	Game.use_slot(1)
	Game.save()
	await ui.fade_to(1.0, 0.6)
	await _interrogate()


func _questions() -> Array:
	return [
		{"id": "n1", "w": 3, "lie": false, "q": t("منذ متى تعملين في الشركة؟", "How long have you worked at the company?"), "a": t("ست سنوات. هل هذا مهم؟", "Six years. Does it matter?")},
		{"id": "n2", "w": 3, "lie": false, "q": t("كيف تصفين ملف أبو فراس؟", "How would you describe Abu Firas's file?"), "a": t("ملف روتيني. مالك أمّن مبناه ثم احترق. قصة مألوفة.", "A routine file. An owner insured his building, then it burned. A familiar story.")},
		{"id": "s1", "w": 10, "lie": true, "q": t("من زار المبنى قبل الحريق؟", "Who visited the building before the fire?"), "a": t("المفتّش الدوري فقط. لا أحد غيره.", "Only the routine inspector. Nobody else.")},
		{"id": "s2", "w": 10, "lie": true, "q": t("لماذا رفضتم التعويض قبل إكمال التحقيق؟", "Why did you refuse the payout before the investigation was over?"), "a": t("إجراء داخلي. لا أستطيع الخوض فيه.", "Internal procedure. I can't go into it.")},
		{"id": "t1", "w": 25, "lie": true, "q": t("هل أرسلت الشركة أحدًا إلى المبنى ليلة الحريق؟", "Did the company send anyone to the building on the night of the fire?"), "a": t("طبعًا لا! ما هذا السؤال؟", "Of course not! What kind of question is that?")},
		{"id": "t2", "w": 25, "lie": true, "q": t("هل تملك الشركة سيارة بيضاء بشعارها؟", "Does the company own a white car with its logo?"), "a": t("لدينا أسطول... لكن ما علاقة هذا بالحريق؟", "We have a fleet... but what does that have to do with the fire?")},
	]


func _interrogate() -> void:
	var nm := t("سلمى", "Salma")
	salma = _spawn(_cfg_salma(), Vector3(-3.0, 0, 0.6), PI * 0.5, false)
	salma.look_target = world.player.cam
	salma.tension = 5.0
	await ui.fade_to(0.0, 0.6)
	await _go(salma, [Vector3(-2.0, 0, 0.6), Vector3(-1.75, 0, -1.9), Vector3(0.2, 0, -1.9)])
	salma.face_pos(Vector3(0.2, 0, 2.0), 0.1)
	await _wait(0.3)
	salma.sitting = true
	await _wait(0.4)
	await world.focus_on(salma)
	var tension := 10.0
	var trust := 40.0
	var fatigue := 0.0
	var shown := 0
	var asked := {}
	var Q := _questions()
	await ui.say(nm, t("أنا سلمى من «ميرفا للتأمين». جئت لأسمع منك فقط، وقتي ضيق.", "I'm Salma from Merva Insurance. I only came to listen to you, my time is short."), C_SALMA, salma)
	ui.toast(t("راقبها: وجهها ويداها. ابدأ بأسئلة سهلة لتتعلم سلوكها الطبيعي ثم قارن.", "Watch her face and hands. Start with easy questions to learn her baseline, then compare."))
	var outcome := "met"
	while true:
		var labels: Array = []
		var acts: Array = []
		for q in Q:
			if not asked.has(q["id"]):
				labels.append(q["q"])
				acts.append("q:" + str(q["id"]))
		labels.append(t("قرّب الكرسي", "Move your chair closer"))
		acts.append("chair")
		labels.append(t("صمت طويل", "Stay silent for a long moment"))
		acts.append("silence")
		labels.append(t("قدّم لها كوب ماء", "Offer her a glass of water"))
		acts.append("water")
		labels.append(t("كن لطيفًا معها", "Be kind to her"))
		acts.append("kind")
		if Game.has_ev("renov_bill") and not asked.has("show_bill"):
			labels.append(t("اعرض فاتورة الترميم", "Show the renovation invoice"))
			acts.append("show_bill")
		if Game.ev_quality("roof_burn") == "good" and not asked.has("show_roof"):
			labels.append(t("اعرض صور آثار السطح", "Show the roof photos"))
			acts.append("show_roof")
		if Game.has_ev("street_cam") and not asked.has("show_cam"):
			labels.append(t("اعرض لقطة كاميرا الشارع", "Show the street-camera footage"))
			acts.append("show_cam")
		labels.append(t("أنهِ الجلسة", "End the session"))
		acts.append("end")
		var i := await ui.choose(labels, t("ماذا تفعل؟", "What do you do?"), 2)
		var act: String = acts[i]
		var line := ""
		var show_pressure := false
		if act.begins_with("q:"):
			var qid := act.substr(2)
			for q in Q:
				if q["id"] == qid:
					asked[qid] = true
					tension += float(q["w"])
					fatigue += 6.0
					if int(q["w"]) >= 25:
						trust -= 6.0
					line = str(q["a"])
		elif act == "chair":
			tension += 8.0
			trust -= 10.0
			line = t("ابتعد قليلًا، رجاءً.", "Please, back off a little.")
		elif act == "silence":
			tension += 6.0
			fatigue += 10.0
		elif act == "water":
			trust += 10.0
			tension -= 10.0
			line = t("شكرًا.", "Thank you.")
		elif act == "kind":
			trust += 12.0
			tension -= 6.0
			line = t("...شكرًا. هذا أسلوب ألطف.", "...Thanks. That's a nicer tone.")
		elif act == "show_bill":
			asked["show_bill"] = true
			shown += 1
			tension += 20.0
			trust -= 5.0
			line = t("فاتورة؟ هذه شؤون المالك وليست شأننا.", "An invoice? That's the owner's business, not ours.")
		elif act == "show_roof":
			asked["show_roof"] = true
			shown += 1
			tension += 20.0
			trust -= 5.0
			line = t("آثار على سطح... الحرائق تبدأ من أي مكان.", "Marks on a roof... fires start anywhere.")
		elif act == "show_cam":
			asked["show_cam"] = true
			shown += 1
			tension += 35.0
			trust -= 5.0
			line = t("...لقطة غير واضحة. لا أفهم ماذا تريد أن تثبت.", "...A blurry clip. I don't see what you're trying to prove.")
		else:
			await ui.say(t("أنت", "You"), t("يكفي هذا الآن.", "That's enough for now."), C_YOU)
			outcome = "met"
			break
		tension = clampf(tension, 0.0, 100.0)
		trust = clampf(trust, -20.0, 100.0)
		var eff := clampf(tension + fatigue * 0.2, 0.0, 100.0)
		salma.tension = eff
		salma.emotion = "worried" if eff > 60.0 else "neutral"
		if line != "":
			await ui.say(nm, line, C_SALMA, salma)
		else:
			ui.close_dialog()
			await _wait(1.6)
		if (shown >= 1 and eff >= 85.0) or (shown >= 2 and eff >= 70.0):
			await _salma_crack(trust)
			outcome = "cracked"
			break
		if eff >= 100.0 or trust <= 0.0:
			await ui.say(nm, t("انتهى هذا اللقاء. محاميّ سيتواصل معك.", "This meeting is over. My lawyer will contact you."), C_SALMA, salma)
			outcome = "left"
			break
	Game.s["salma"] = outcome
	ui.close_dialog()
	world.release_focus()
	await _salma_leaves()
	Game.save()
	ui.toast(t("انتهى اللقاء مع سلمى.", "The meeting with Salma is over."))
	if Game.slots_left() <= 0:
		await _deadline()


func _salma_crack(trust: float) -> void:
	var nm := t("سلمى", "Salma")
	salma.emotion = "worried"
	salma.tension = 95.0
	await ui.say(nm, t("حسنًا... كفى. (تتنهد) المدير هو الذي أمرني. الحريق ما كان صدفة، والسيارة كانت سيارتنا. لكنني لن أشهد ضد الشركة أبدًا.", "Fine... enough. (sighs) The manager ordered it. The fire was no accident, and the car was ours. But I will never testify against the company."), C_SALMA, salma)
	await ui.say(nm, t("ولهذا أعرض عليك ١٥٠٠ لتغلق الملف وتنسى الأمر.", "So I'm offering you 1,500 to close the file and forget this."), C_SALMA, salma)
	var i := await ui.choose([
		t("أرفض: هذه رشوة (قانوني)", "Refuse: that's a bribe (legal)"),
		t("أقبل المبلغ (رشوة)", "Take the money (bribe)"),
		t("أتظاهر بالقبول وأسجّلها بالمسجل المخفي (رمادي)", "Pretend to accept and record her with the hidden recorder (grey)")],
		t("ماذا تفعل بالرشوة؟", "What do you do about the bribe?"), 1)
	if i == 0:
		Game.s["bribe"] = "refused"
		await ui.say(t("أنت", "You"), t("هذا الملف لن يُغلق يا سلمى. تفضّلي بالخروج.", "This file won't close, Salma. Please leave."), C_YOU)
	elif i == 1:
		Game.s["bribe"] = "took"
		await ui.say(t("أنت", "You"), t("حسنًا. اعتبري الأمر منتهيًا.", "Fine. Consider it done."), C_YOU)
		ui.toast(t("قبلتَ الرشوة: الشرطة لن تثق بك بعد الآن.", "You took the bribe: the police will no longer trust you."))
	else:
		if trust >= 25.0:
			Game.s["bribe"] = "recorded"
			Game.add_ev("bribe_rec", "good")
			await ui.say(t("أنت", "You"), t("موافق. لنتفق على التفاصيل...", "Agreed. Let's settle the details..."), C_YOU)
			await ui.say(nm, t("هذا بيننا فقط. ١٥٠٠ مقابل الصمت.", "This stays between us. 1,500 for your silence."), C_SALMA, salma)
			ui.toast(t("سُجّلت الرشوة: دليل قوي لكنه رمادي.", "The bribe was recorded: strong but grey evidence."))
		else:
			Game.s["bribe"] = "refused"
			await ui.say(nm, t("ما هذا الجهاز في جيبك؟! انتهى اللقاء.", "What is that device in your pocket?! This meeting is over."), C_SALMA, salma)


func _salma_leaves() -> void:
	if salma == null:
		return
	salma.sitting = false
	await _wait(0.5)
	await _go(salma, [Vector3(-1.75, 0, -1.9), Vector3(-2.0, 0, 0.6), Vector3(-3.0, 0, 0.6)])
	salma.queue_free()
	salma = null


# ---------------------------------------------------------------- hand-in
func _folder() -> void:
	if str(Game.s["stage"]) == "done":
		await _you(t("الملف سُلّم. القضايا التالية في التحديث القادم.", "The file is handed in. More cases in the next update."))
		return
	if not _active():
		await _you(t("لا قضية بعد.", "No case yet."))
		return
	var r: Dictionary = await ui.open_case_file(Game.s["bribe"] != "took")
	if r.is_empty():
		return
	var res := Game.compute_result(r["selected"], str(r["accused"]), str(r["delivery"]))
	Game.finish_case(res)
	await ui.show_result(res, _result_lines(res))


# ---------------------------------------------------------------- notes
func notes_text() -> String:
	var L: Array = []
	L.append(t("القضية ١: «تحت الإيجار» - احتيال تأميني", "Case 1: \"Under Rent\" - insurance fraud"))
	if int(Game.s["fee"]) > 0:
		L.append(t("الأتعاب المتفق عليها: %d", "Agreed fee: %d") % int(Game.s["fee"]))
	L.append(t("المهلة: ٣ أيام (٦ فترات). اذهب إلى السطح خلال أول فعلين، بعدها يمسح المطر الآثار.", "Deadline: 3 days (6 slots). Reach the roof within your first two actions: after that the rain washes the marks away."))
	var ck := func(b: bool) -> String: return "[x] " if b else "[ ] "
	L.append(ck.call(Game.ev_quality("roof_burn") == "good") + t("صوّر آثار الحريق على السطح بجودة جيدة (من قرب).", "Photograph the burn marks on the roof in good quality (up close)."))
	L.append(ck.call(Game.has_ev("renov_bill")) + t("اطلب من هيثم البحث عن فواتير المبنى والبوليصة.", "Ask Haitham to search the building's invoices and policy."))
	L.append(ck.call(Game.has_ev("street_cam")) + t("صوّر كاميرا الشارع من السطح ثم اطلب من هيثم لقطاتها.", "Photograph the street camera from the roof, then ask Haitham for its footage."))
	L.append(ck.call(Game.s["salma"] != "none") + t("اتصل بسلمى من الهاتف الأرضي واستجوبها (راقب القلم في يدها).", "Call Salma from the landline and question her (watch the pen in her hand)."))
	L.append(ck.call(str(Game.s["stage"]) == "done") + t("سلّم الملف من المجلد البنفسجي على مكتبك.", "Hand the file in from the violet folder on your desk."))
	L.append(t("انتبه: بعض الأشياء تبدو أدلة لكنها مضلِّلة، وهي تخصم نقاطًا من الملف.", "Careful: some things look like evidence but are misleading, and they cost points in the file."))
	return "\n".join(L)
