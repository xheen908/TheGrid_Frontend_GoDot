extends PanelContainer

var ability_data: Dictionary

func _get_drag_data(_at_position):
	var preview = Control.new()
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var icon_path = ability_data.get("icon", "")
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	icon.position = -Vector2(20, 20)
	preview.add_child(icon)
	set_drag_preview(preview)
	
	return {
		"type": "spell",
		"spell_name": ability_data.get("name", ""),
		"icon_path": icon_path
	}
