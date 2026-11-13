extends Node
## Autoload "Game": state of the current case (case 1 "Under Rent"), save/load, evidence, scoring.

signal changed

const MAX_SLOTS := 6            # 3 in-game days x 2 slots
const RAIN_WASHES_AT := 3       # roof marks are washed away once this many slots are used

## id -> [ar, en, kind]   kind: real / fake / lead
const EVIDENCE := {
	"roof_burn": ["آثار حريق مسرَّع على السطح (ليس من المطبخ)", "Accelerated burn marks on the roof (not the kitchen)", "real"],
	"renov_bill": ["فاتورة ترميم بتاريخ بعد البوليصة", "Renovation invoice dated after the policy", "real"],
	"street_cam": ["كاميرا الشارع: سيارة الشركة قبل الحريق بساعة", "Street camera: company car an hour before the fire", "real"],
	"bribe_rec": ["تسجيل سلمى وهي تعرض الرشوة", "Recording of Salma offering the bribe", "real"],
	"gas_can": ["علبة بنزين في القبو (للمولد)", "Petrol can in the basement (for the generator)", "fake"],
	"threat_letter": ["رسالة تهديد من جار غاضب", "Threat letter from an angry neighbour", "fake"],
	"cam_pole": ["عمود كاميرا مراقبة في الشارع المقابل", "Surveillance camera on the opposite street", "lead"],
}

var s: Dictionary = {}


func _init() -> void:
	new_state()


func new_state(difficulty := 1) -> void:
	s = {
		"case": 1, "stage": "new", "difficulty": difficulty,
		"fee": 0, "slot": 0, "money": 300,
		"evidence": {},            # id -> "good" | "poor"
		"calls_left": 3,
		"done_tasks": [],          # haitham tasks done
		"salma": "none",           # none / met / cracked / left
		"bribe": "none",           # none / took / recorded / refused
		"ejected": false,
		"result": {},
		"time": 0,
	}
	s["calls_left"] = [3, 2, 1][clampi(difficulty, 0, 2)]
	changed.emit()


func has_ev(id: String) -> bool:
	return s["evidence"].has(id)


func ev_quality(id: String) -> String:
	return str(s["evidence"].get(id, ""))


func add_ev(id: String, quality: String) -> void:
	var old := ev_quality(id)
	if old == "good":
		return
	s["evidence"][id] = quality
	save()
	changed.emit()


func kind(id: String) -> String:
	return str(EVIDENCE[id][2])


func ev_name(id: String) -> String:
	return Settings.t(EVIDENCE[id][0], EVIDENCE[id][1])


func day() -> int:
	return mini(int(s["slot"]) / 2 + 1, 3)


func use_slot(n := 1) -> void:
	s["slot"] = mini(int(s["slot"]) + n, MAX_SLOTS)
	changed.emit()


func slots_left() -> int:
	return MAX_SLOTS - int(s["slot"])


func raining_washed() -> bool:
	return int(s["slot"]) >= RAIN_WASHES_AT


# ---------------------------------------------------------------- score (document chapter 21)
## selected: evidence ids put in the file.  accused: "company" | "owner".
func compute_result(selected: Array, accused: String, delivery: String) -> Dictionary:
	var ev_score := 0
	var fakes := 0
	for id in selected:
		var k := kind(id)
		if k == "real" and ev_quality(id) == "good":
			ev_score += 10
		elif k == "fake":
			fakes += 1
	ev_score = clampi(ev_score, 0, 40) - 10 * fakes
	var verdict := 30 if accused == "company" else 0
	var style := 15
	if s["bribe"] == "took":
		style -= 10
	elif s["bribe"] == "recorded":
		style -= 3
	if s["ejected"]:
		style -= 3
	style = maxi(style, 0)
	var slot := int(s["slot"])
	var timeo := 15 if slot <= 4 else (10 if slot <= 5 else 5)
	var total := clampi(ev_score + verdict + style + timeo, 0, 100)
	var tier := "fail"
	var pct := 0.0
	if total >= 85:
		tier = "full"; pct = 1.0
	elif total >= 60:
		tier = "partial"; pct = 0.7
	elif total >= 40:
		tier = "rejected"; pct = 0.3
	var reward := int(round(float(s["fee"]) * pct))
	if s["bribe"] == "took":
		reward += 1500
	var r := {"ev": ev_score, "verdict": verdict, "style": style, "time": timeo, "total": total,
		"tier": tier, "reward": reward, "accused": accused, "delivery": delivery,
		"yasser": total >= 85 and accused == "company"}
	return r


func finish_case(r: Dictionary) -> void:
	s["result"] = r
	s["stage"] = "done"
	s["money"] = int(s["money"]) + int(r["reward"])
	save()
	changed.emit()


# ---------------------------------------------------------------- save / load
func save() -> void:
	var f := FileAccess.open(Settings.GAME_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))
		f.close()


func load_save() -> bool:
	if not FileAccess.file_exists(Settings.GAME_SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(Settings.GAME_SAVE_PATH))
	if not (d is Dictionary):
		return false
	new_state(int(d.get("difficulty", 1)))
	for k in d:
		s[k] = d[k]
	s["slot"] = int(s["slot"])
	changed.emit()
	return true
