extends Control

# Zugriff über Scene Unique Names (%)
@onready var char_list_container = %CharListContainer
@onready var enter_button = %EnterWorldButton
@onready var back_button = %BackButton
@onready var create_char_button = %CreateCharacterButton
@onready var delete_confirm_dialog = %DeleteConfirmDialog
@onready var error_dialog = %ErrorDialog
@onready var error_label = %ErrorLabel

var selected_char_id_to_delete = -1
var selected_char_data = null

func _ready():
	# 1. Sicherheits-Check
	if char_list_container == null or enter_button == null or back_button == null:
		push_error("KRITISCH: UI-Nodes nicht gefunden!")
		return
	
	# 2. Initialer UI-Status
	enter_button.disabled = true
	
	# 3. Signale verbinden
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not enter_button.pressed.is_connected(_on_enter_world_pressed):
		enter_button.pressed.connect(_on_enter_world_pressed)
	if not create_char_button.pressed.is_connected(_on_create_char_pressed):
		create_char_button.pressed.connect(_on_create_char_pressed)
	if not delete_confirm_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	
	# 4. NetworkManager Signale abonnieren
	if NetworkManager:
		if not NetworkManager.characters_loaded.is_connected(_on_characters_received):
			NetworkManager.characters_loaded.connect(_on_characters_received)
		if not NetworkManager.character_deleted.is_connected(_on_character_deleted):
			NetworkManager.character_deleted.connect(_on_character_deleted)
		if not NetworkManager.ws_connected.is_connected(_on_ws_connected):
			NetworkManager.ws_connected.connect(_on_ws_connected)
		if not NetworkManager.ws_authenticated.is_connected(_on_ws_authenticated):
			NetworkManager.ws_authenticated.connect(_on_ws_authenticated)
		if not NetworkManager.ws_connection_failed.is_connected(_on_ws_failed):
			NetworkManager.ws_connection_failed.connect(_on_ws_failed)
		
		print("CharacterScreen: Fordere Charakterliste an...")
		NetworkManager.fetch_characters()

# Verarbeitet den erweiterten MMORPG JSON Payload
func _on_characters_received(chars: Array):
	print("CharacterScreen: Daten empfangen, verarbeite ", chars.size(), " Charaktere.")
	
	if not char_list_container:
		return

	# Alte Einträge löschen
	for child in char_list_container.get_children():
		child.queue_free()
	
	# Einträge dynamisch erstellen
	for c in chars:
		var c_name = c.get("char_name", "Unbekannt")
		var char_id = c.get("id", -1)
		
		# Basis Container
		var item_container = PanelContainer.new()
		item_container.custom_minimum_size.y = 100
		
		# Der Haupt-Button für die Auswahl
		var main_btn = Button.new()
		main_btn.custom_minimum_size.y = 100
		main_btn.pressed.connect(_on_char_selected.bind(c))
		item_container.add_child(main_btn)
		
		# Ein HBoxContainer IM Button für Label und Delete-Button
		var hbox = HBoxContainer.new()
		# WICHTIG: Erlaubt Klicks durch das HBox zum Button
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS 
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 10)
		main_btn.add_child(hbox)
		
		# Label (Text)
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE # Klicks gehen direkt zum main_btn
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var c_level = c.get("level", 1)
		var class_info = c.get("class_info", {})
		var c_class_name = class_info.get("class_name", "No Class")
		var c_class_color = class_info.get("class_color", "#FFFFFF")
		var world_state = c.get("world_state", {})
		var m_name = world_state.get("map_name", "Unknown Map")
		
		var bbcode_text = "[font_size=20][color=yellow]%s[/color][/font_size]\n" % c_name
		bbcode_text += "[color=white]Level %d [/color][color=%s]%s[/color]\n" % [c_level, c_class_color, c_class_name]
		bbcode_text += "[color=white]%s[/color]" % m_name
		label.text = bbcode_text
		hbox.add_child(label)
		
		# Delete-Button (auf dem main_btn liegend)
		var delete_btn = Button.new()
		delete_btn.text = " X "
		delete_btn.add_theme_color_override("font_color", Color.RED)
		delete_btn.custom_minimum_size = Vector2(60, 60)
		delete_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Verhindert, dass der Klick auch den main_btn auslöst
		delete_btn.pressed.connect(func(): _on_delete_char_pressed(char_id))
		hbox.add_child(delete_btn)
		
		char_list_container.add_child(item_container)

	char_list_container.queue_sort()

var last_selected_char_id = -1
var last_click_time = 0

func _on_char_selected(data):
	var current_time = Time.get_ticks_msec()
	var char_id = data.get("id", -1)
	
	# Doppel-Klick Logik (innerhalb von 400ms auf den gleichen Charakter)
	if char_id == last_selected_char_id and (current_time - last_click_time) < 400:
		selected_char_data = data
		_on_enter_world_pressed()
		return

	last_selected_char_id = char_id
	last_click_time = current_time
	
	selected_char_data = data
	enter_button.disabled = false
	
	print("Charakter ausgewählt: ", data.get("char_name"))

### DIESER TEIL WURDE KORRIGIERT ###
func _on_enter_world_pressed():
	if selected_char_data:
		if enter_button:
			enter_button.disabled = true
			enter_button.text = "Verbinde..."
		
		if error_label:
			error_label.text = ""
		
		if NetworkManager:
			NetworkManager.current_player_data = selected_char_data
			NetworkManager.connect_to_ws()

func _on_ws_connected():
	print("CharacterScreen: WS verbunden, authentifiziere...")
	if NetworkManager:
		NetworkManager.authenticate_ws()

func _on_ws_authenticated():
	print("CharacterScreen: Authentifiziert! Wechsle zum GameScreen.")
	var error = get_tree().change_scene_to_file("res://Screens/GameScreen.tscn")
	if error != OK:
		print("FEHLER: GameScreen.tscn konnte nicht geladen werden!")

func _on_ws_failed(reason: String):
	print("CharacterScreen: Verbindung fehlgeschlagen: ", reason)
	if enter_button:
		enter_button.disabled = false
		enter_button.text = "World beitreten"
	
	if error_label:
		error_label.text = reason
	
	if error_dialog:
		error_dialog.dialog_text = "Verbindung zum Worldserver fehlgeschlagen:\n" + reason
		error_dialog.popup_centered()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Screens/LoginScreen.tscn")

func _on_create_char_pressed():
	get_tree().change_scene_to_file("res://Screens/CreateCharacterScreen.tscn")

func _on_delete_char_pressed(char_id: int):
	if char_id == -1: return
	selected_char_id_to_delete = char_id
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed():
	if selected_char_id_to_delete != -1:
		print("Bestätigt: Lösche Charakter ID: ", selected_char_id_to_delete)
		NetworkManager.delete_character(selected_char_id_to_delete)
		selected_char_id_to_delete = -1

func _on_character_deleted(success: bool, message: String):
	if success:
		print("Charakter gelöscht, lade Liste neu...")
		NetworkManager.fetch_characters()
	else:
		print("Fehler beim Löschen: ", message)
