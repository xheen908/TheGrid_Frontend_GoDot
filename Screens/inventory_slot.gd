extends Panel

signal item_used(slot_idx: int)
signal item_hovered(data: Dictionary, entered: bool)

var slot_index: int = -1
var item_data: Dictionary = {}

@onready var icon_rect = %Icon
@onready var qty_label = %QuantityLabel

# We need references to preloaded icons if we want setup() to work here
# But usually inventory_window does the mapping. 
# Let's move the mapping logic to a central place or keep it in inventory_window for now.
# However, TradeWindow needs it too.

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if not item_data.is_empty():
		item_hovered.emit(item_data, true)

func _on_mouse_exited():
	item_hovered.emit({}, false)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not item_data.is_empty():
				item_used.emit(slot_index)

func _get_drag_data(_at_position):
	if item_data.is_empty():
		return null
		
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)
	
	return {"from_slot": slot_index, "item": item_data}

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("from_slot")

func _drop_data(_at_position, data):
	var from_slot = data["from_slot"]
	
	if has_meta("trade_slot") and get_meta("side") == "me":
		NetworkManager.send_trade_add_item(from_slot)
		return

	var to_slot = slot_index
	if from_slot == -1 or to_slot == -1 or from_slot == to_slot:
		return
		
	NetworkManager.send_move_item(from_slot, to_slot)

func setup(data: Dictionary, icon_texture: Texture):
	item_data = data
	slot_index = int(data.get("slot", -1))
	
	if icon_rect:
		icon_rect.texture = icon_texture
		icon_rect.show()
	
	var qty = int(data.get("quantity", 1))
	if qty_label:
		if qty > 1:
			qty_label.text = str(qty)
			qty_label.show()
		else:
			qty_label.hide()
	
	if data.get("equipped", false):
		self.self_modulate = Color(0.5, 1, 0.5, 1)
	else:
		self.self_modulate = Color(1, 1, 1, 1)

func clear():
	item_data = {}
	# slot_index = -1 # Keep slot index if it's a fixed inventory slot
	if icon_rect:
		icon_rect.texture = null
		icon_rect.hide()
	if qty_label:
		qty_label.hide()
	self.self_modulate = Color(1, 1, 1, 1)
