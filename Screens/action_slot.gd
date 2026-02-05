extends Button

@export var slot_index: int = 0
var current_spell_name: String = ""

@onready var icon_rect = get_node_or_null("Icon")

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.get("type") == "spell"

func _drop_data(_at_position, data):
	var spell_name = data.get("spell_name", "")
	var icon_path = data.get("icon_path", "")
	
	current_spell_name = spell_name
	
	# Update visual
	if icon_rect and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	
	# Inform HUD
	if find_hud_owner(self):
		var hud = find_hud_owner(self)
		if hud.has_method("_on_spell_assigned_to_slot"):
			hud._on_spell_assigned_to_slot(slot_index, spell_name)

func find_hud_owner(node):
	var p = node.get_parent()
	while p:
		if p.name == "MMO_Hud" or p is CanvasLayer: # Adjust based on name
			return p
		p = p.get_parent()
	return null
