extends Control

# Zugriff über Scene Unique Names (%)
@onready var char_list_container = %CharListContainer
@onready var enter_button = %EnterWorldButton
@onready var back_button = %BackButton

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
	
	# 4. NetworkManager Signale abonnieren
	if NetworkManager:
		if not NetworkManager.characters_loaded.is_connected(_on_characters_received):
			NetworkManager.characters_loaded.connect(_on_characters_received)
		
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
		var item_container = PanelContainer.new()
		item_container.custom_minimum_size.y = 100
		
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.selection_enabled = false
		
		var c_name = c.get("char_name", "Unbekannt")
		var c_level = c.get("level", 1)
		
		var class_info = c.get("class_info", {})
		var c_class_name = class_info.get("class_name", "No Class")
		var c_class_color = class_info.get("class_color", "#FFFFFF")
		
		var world_state = c.get("world_state", {})
		var m_name = world_state.get("map_name", "Unknown Map")
		var z_id = world_state.get("zone_id", "Unknown Zone")
		
		var bbcode_text = "[font_size=20][color=yellow]%s[/color][/font_size]\n" % c_name
		bbcode_text += "[color=white]Level %d [/color][color=%s]%s[/color]\n" % [c_level, c_class_color, c_class_name]
		bbcode_text += "[color=white]%s[/color]" % m_name
		
		label.text = bbcode_text
		
		var click_btn = Button.new()
		click_btn.flat = true 
		click_btn.custom_minimum_size = Vector2(0, 100)
		click_btn.pressed.connect(_on_char_selected.bind(c))
		
		item_container.add_child(label)
		item_container.add_child(click_btn)
		
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
		var world = selected_char_data.get("world_state", {})
		print("Betrete Welt: ", world.get("map_name"))
		
		# BEST PRACTICE: Speichere die Charakterdaten im NetworkManager ab,
		# damit der GameScreen weiß, welche Position der Spieler hat.
		if NetworkManager:
			NetworkManager.current_player_data = selected_char_data
		
		# Szenenwechsel zum GameScreen
		var error = get_tree().change_scene_to_file("res://Screens/GameScreen.tscn")
		
		if error != OK:
			print("FEHLER: GameScreen.tscn konnte nicht geladen werden! Pfad prüfen.")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Screens/LoginScreen.tscn")
