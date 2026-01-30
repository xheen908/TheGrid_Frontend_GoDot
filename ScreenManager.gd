# SceneManager.gd
extends Node

# Hier werden deine Login-Daten gespeichert
var user_data = {}
const SAVE_PATH = "user://user_data.save"

func _ready():
	load_data()

# Funktion zum Wechseln der Screens (Login -> Charakter -> Welt)
func switch_scene(path: String):
	if FileAccess.file_exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Fehler: Szene nicht gefunden unter: ", path)

# Speichert die Daten dauerhaft auf der Festplatte
func save_data(data: Dictionary):
	user_data = data
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(user_data)
		print("Daten erfolgreich gespeichert.")

# Lädt die Daten beim Start der App
func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			user_data = file.get_var()
			print("Daten geladen: ", user_data)
