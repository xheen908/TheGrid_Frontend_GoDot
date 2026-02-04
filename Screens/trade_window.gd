extends PanelContainer

@onready var partner_label = %PartnerLabel
@onready var my_grid = %MyGrid
@onready var partner_grid = %PartnerGrid
@onready var ready_check = %ReadyCheck
@onready var partner_ready_box = %PartnerReadyBox
@onready var confirm_button = %ConfirmButton

var slot_scene = preload("res://Screens/InventorySlot.tscn")
var partner_name = ""

func _ready():
	# Clear grids
	for child in my_grid.get_children(): child.queue_free()
	for child in partner_grid.get_children(): child.queue_free()
	
	for i in range(8):
		var s1 = slot_scene.instantiate()
		s1.set_meta("trade_slot", i)
		s1.set_meta("side", "me")
		my_grid.add_child(s1)
		s1.item_hovered.connect(_on_slot_item_hovered)
		
		var s2 = slot_scene.instantiate()
		s2.set_meta("trade_slot", i)
		s2.set_meta("side", "partner")
		partner_grid.add_child(s2)
		s2.item_hovered.connect(_on_slot_item_hovered)

	NetworkManager.trade_updated.connect(_on_trade_updated)
	NetworkManager.trade_completed.connect(_on_trade_completed)
	NetworkManager.trade_canceled.connect(_on_trade_canceled)
	
	confirm_button.disabled = true

func open(p_name: String):
	partner_name = p_name
	partner_label.text = p_name
	ready_check.button_pressed = false
	partner_ready_box.color = Color.RED
	show()

func _on_trade_updated(my_items: Array, p_items: Array, my_ready: bool, p_ready: bool):
	_update_grid(my_grid, my_items)
	_update_grid(partner_grid, p_items)
	
	ready_check.set_block_signals(true)
	ready_check.button_pressed = my_ready
	ready_check.set_block_signals(false)
	
	partner_ready_box.color = Color.GREEN if p_ready else Color.RED
	
	# Enable confirm only if both ready
	confirm_button.disabled = !(my_ready and p_ready)

func _update_grid(grid: GridContainer, items: Array):
	var slots = grid.get_children()
	var inv_window = get_node_or_null("%InventoryWindow")
	
	for i in range(slots.size()):
		var slot = slots[i]
		var item = null
		if i < items.size():
			item = items[i]
		
		if item:
			var tex = null
			var iid = str(item.get("item_id", ""))
			# Access InventoryWindow globally or find it in tree
			var inv = get_tree().root.find_child("InventoryWindow", true, false)
			if inv:
				tex = inv.get_item_icon(iid)
			slot.setup(item, tex)
		else:
			slot.clear()

func _on_ready_check_toggled(toggled_on):
	NetworkManager.send_trade_ready(toggled_on)

func _on_confirm_button_pressed():
	NetworkManager.send_trade_confirm()

func _on_cancel_button_pressed():
	NetworkManager.send_trade_cancel()
	hide()

func _on_trade_completed():
	# Maybe play a sound
	hide()

func _on_trade_canceled():
	hide()

func _on_slot_item_hovered(data: Dictionary, entered: bool):
	var hud = get_tree().root.find_child("MMO_Hud", true, false)
	if hud and hud.has_method("_on_inventory_item_hovered"):
		hud._on_inventory_item_hovered(data, entered)
