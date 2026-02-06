extends Panel

@onready var skill_list = %SkillList
@onready var close_button = %CloseButton
@onready var title_label = $VBox/Header/Title

var dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	close_button.pressed.connect(hide)
	NetworkManager.spellbook_updated.connect(_on_spellbook_updated)
	
	if NetworkManager.current_player_data:
		var char_class = NetworkManager.current_player_data.get("char_class", "Mage")
		title_label.text = "Zauberbuch - " + char_class
		
		if NetworkManager.current_player_data.has("abilities"):
			_on_spellbook_updated(NetworkManager.current_player_data["abilities"])

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				# Move to front
				move_to_front()
			else:
				dragging = false
	
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func toggle():
	visible = !visible
	if visible:
		# Always refresh when opening
		if NetworkManager.current_player_data and NetworkManager.current_player_data.has("abilities"):
			_on_spellbook_updated(NetworkManager.current_player_data["abilities"])

func _on_spellbook_updated(abilities: Array):
	# Clear list
	for child in skill_list.get_children():
		child.queue_free()
		
	for ability in abilities:
		_add_ability_entry(ability)

func _add_ability_entry(ability: Dictionary):
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = 60
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var icon_path = ability.get("icon", "")
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	
	hbox.add_child(icon_rect)
	
	# Text Info
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = ability.get("name", "Unbekannt")
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)
	
	var cat_label = Label.new()
	cat_label.text = ability.get("category", "Allgemein")
	cat_label.add_theme_font_size_override("font_size", 10)
	cat_label.modulate = Color(0.7, 0.7, 1.0) # Light blue for mage category
	vbox.add_child(cat_label)
	
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = ability.get("description", "")
	desc_label.fit_content = true
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	hbox.add_child(vbox)
	
	# Drag and Drop support?
	# For now, let's just make it look good.
	
	var panel = PanelContainer.new()
	panel.set_script(load("res://Screens/skill_entry.gd"))
	panel.ability_data = ability
	panel.add_child(hbox)
	
	# Add some style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	
	skill_list.add_child(panel)
