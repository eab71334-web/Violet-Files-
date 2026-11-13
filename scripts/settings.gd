extends Node
## Autoload "Settings": language, audio, quality, gyro + save-game check.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const GAME_SAVE_PATH := "user://savegame.json"

var lang: String = "ar"        # "ar" or "en"
var volume: float = 0.8        # 0..1
var quality: int = 1           # 0 low, 1 medium, 2 high
var gyro: bool = true


func _ready() -> void:
	load_settings()
	apply()


func is_ar() -> bool:
	return lang == "ar"


## Returns the Arabic or English text depending on the chosen language.
func t(ar: String, en: String) -> String:
	return ar if lang == "ar" else en


func has_save() -> bool:
	return FileAccess.file_exists(GAME_SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	lang = str(cfg.get_value("main", "lang", lang))
	volume = float(cfg.get_value("main", "volume", volume))
	quality = int(cfg.get_value("main", "quality", quality))
	gyro = bool(cfg.get_value("main", "gyro", gyro))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("main", "lang", lang)
	cfg.set_value("main", "volume", volume)
	cfg.set_value("main", "quality", quality)
	cfg.set_value("main", "gyro", gyro)
	cfg.save(SETTINGS_PATH)


func apply() -> void:
	TranslationServer.set_locale(lang)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	_apply_font()
	changed.emit()


## If a Cairo/Tajawal font is dropped into res://fonts/ it is used everywhere.
func _apply_font() -> void:
	for f in ["Cairo.ttf", "Tajawal-Bold.ttf", "Cairo-VariableFont.ttf"]:
		var p := "res://fonts/" + f
		if ResourceLoader.exists(p):
			var font = load(p)
			if font is Font:
				ThemeDB.fallback_font = font
				return
