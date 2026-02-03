extends Panel

signal item_used(slot_idx: int)

var slot_index: int = -1
var item_data: Dictionary = {}

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not item_data.is_empty():
				item_used.emit(slot_index)

func _get_drag_data(_at_position):
	if item_data.is_empty():
		return null
		
	# Create preview
	var preview = TextureRect.new()
	preview.texture = %Icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)
	
	return {"from_slot": slot_index, "item": item_data}

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("from_slot")

func _drop_data(_at_position, data):
	var from_slot = data["from_slot"]
	var to_slot = slot_index
	
	if from_slot == to_slot:
		return
		
	# Tell the network manager to move the item
	NetworkManager.send_move_item(from_slot, to_slot)
