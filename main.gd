extends Control

# Wir nutzen Scene Unique Names (%), damit die Struktur der Container egal ist.
# WICHTIG: Rechtsklick auf die Nodes im Editor -> "% Als eindeutigen Namen für Szene ziehen"
@onready var nutzer_input = %Username
@onready var passwort_input = %Password
@onready var login_button = %LoginButton

func _ready():
	# Sicherheits-Check gegen 'null instance'
	if nutzer_input == null:
		push_error("Knoten 'Username' nicht gefunden! Hast du '%' im Editor aktiviert?")
		return

	# Fokus setzen (Jetzt sicher, da nutzer_input initialisiert ist)
	nutzer_input.grab_focus()
	
	# Signale via Code verbinden
	login_button.pressed.connect(_on_login_button_pressed)
	passwort_input.text_submitted.connect(_on_line_edit_2_text_submitted)
	
	# Signal vom NetworkManager (Autoload) abonnieren
	if NetworkManager:
		NetworkManager.login_finished.connect(_on_network_login_finished)
	
	# Daten laden (Best Practice: Nur einmal eingeben)
	_load_local_data()

func _on_login_button_pressed():
	var username = nutzer_input.text
	var password = passwort_input.text
	
	if username.is_empty() or password.is_empty():
		return
	
	login_button.disabled = true
	NetworkManager.login_request(username, password)

func _on_network_login_finished(success: bool, message: String):
	login_button.disabled = false
	if success:
		_save_local_username(nutzer_input.text)
		get_tree().change_scene_to_file("res://Screens/CharacterScreen.tscn")
	else:
		print("Login Fehler: ", message)

func _on_line_edit_2_text_submitted(_new_text):
	_on_login_button_pressed()

# --- Datenhaltung ---

func _save_local_username(username: String):
	var config = ConfigFile.new()
	config.set_value("User", "username", username)
	config.save("user://local_settings.cfg")

func _load_local_data():
	var config = ConfigFile.new()
	if config.load("user://local_settings.cfg") == OK:
		var saved_name = config.get_value("User", "username", "")
		nutzer_input.text = saved_name
		if not saved_name.is_empty():
			passwort_input.grab_focus()
