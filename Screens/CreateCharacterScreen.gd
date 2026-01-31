extends Control

@onready var char_name_input = %CharName
@onready var class_option = %ClassOption
@onready var create_button = %CreateButton
@onready var back_button = %BackButton
@onready var error_label = %ErrorLabel

func _ready():
	if not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	
	if NetworkManager:
		if not NetworkManager.character_created.is_connected(_on_character_created):
			NetworkManager.character_created.connect(_on_character_created)

func _on_create_pressed():
	var char_name = char_name_input.text.strip_edges()
	if char_name.length() < 3:
		error_label.text = "Name muss mindestens 3 Zeichen lang sein."
		return
	
	# Ersten Buchstaben groß machen
	char_name = char_name[0].to_upper() + char_name.substr(1)
	
	var char_class = class_option.get_item_text(class_option.selected)
	
	error_label.text = ""
	create_button.disabled = true
	NetworkManager.create_character(char_name, char_class)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Screens/CharacterScreen.tscn")

func _on_character_created(success: bool, message: String):
	create_button.disabled = false
	if success:
		print("Charakter erstellt, gehe zurück zum CharacterScreen")
		get_tree().change_scene_to_file("res://Screens/CharacterScreen.tscn")
	else:
		error_label.text = message
