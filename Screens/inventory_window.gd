extends Panel

@onready var grid = %GridContainer
var slot_scene = preload("res://Screens/InventorySlot.tscn")

signal gm_menu_requested()
signal item_hovered(item_data, entered)

var icon_sword = preload("res://Assets/UI/item_iron_sword.jpg")
var icon_potion = preload("res://Assets/UI/item_health_potion.jpg")
var icon_armor = preload("res://Assets/UI/item_mythic_chest.jpg")
var icon_gm_kodex = preload("res://Assets/UI/item_gm_kodex.jpg")
var fallback_icon = preload("res://Assets/UI/spell_ice_barrier.jpg")

# New Icons
var icon_broadsword = preload("res://Assets/UI/item_broadsword.jpg")
var icon_magic_staff = preload("res://Assets/UI/item_magic_staff.jpg")
var icon_sneaky_dagger = preload("res://Assets/UI/item_sneaky_dagger.jpg")
var icon_divine_barricade = preload("res://Assets/UI/item_divine_barricade.jpg")
var icon_mana_potion = preload("res://Assets/UI/item_mana_potion.jpg")
var icon_speed_potion = preload("res://Assets/UI/item_speed_potion.jpg")
var icon_strength_potion = preload("res://Assets/UI/item_strength_potion.jpg")
var icon_intellect_potion = preload("res://Assets/UI/item_intellect_potion.jpg")
var icon_luck_potion = preload("res://Assets/UI/item_luck_potion.jpg")

func get_item_icon(slug: String) -> Texture:
	match slug:
		"1": return icon_gm_kodex
		"2": return icon_potion
		"3": return icon_sword
		"4": return icon_armor
		"6": return icon_broadsword
		"7": return icon_magic_staff
		"8": return icon_sneaky_dagger
		"9": return icon_divine_barricade
		"10": return icon_mana_potion
		"11": return icon_speed_potion
		"12": return icon_strength_potion
		"13": return icon_intellect_potion
		"14": return icon_luck_potion
	return fallback_icon

func _ready():
	print("[UI] InventoryWindow: Script ready and alive.")
	NetworkManager.inventory_updated.connect(_on_inventory_updated)
	if NetworkManager.current_player_data:
		update_inventory()

func update_inventory():
	if not NetworkManager.current_player_data: 
		print("[UI] InventoryWindow: No player data yet.")
		return
	
	var items = NetworkManager.current_player_data.get("inventory", [])
	var max_slots = int(NetworkManager.current_player_data.get("inventory_size", 30))
	
	print("[UI] InventoryWindow: Updating slots. Max: ", max_slots, " Items in array: ", items.size())
	
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	
	# Create slots map
	var slots_map = {}
	for item in items:
		var raw_slot = item.get("slot", item.get("slot_index", 0))
		var s_idx = int(raw_slot) # ZWINGEND als int konvertieren
		slots_map[s_idx] = item
		print("[UI] InventoryWindow: Mapping Item '", item.get("item_id", ""), "' to Slot ", s_idx)
		
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		slot.slot_index = i # WICHTIG für Drag & Drop
		slot.item_used.connect(_on_item_used)
		slot.mouse_entered.connect(func(): if not slot.item_data.is_empty(): item_hovered.emit(slot.item_data, true))
		slot.mouse_exited.connect(func(): item_hovered.emit({}, false))
		
		if slots_map.has(i):
			var item = slots_map[i]
			slot.item_data = item
			print("[UI] InventoryWindow: Setting up Slot ", i, " with item ", item.get("item_id", "unknown"))
			_setup_slot(slot, item)
		else:
			slot.item_data = {}
			slot.get_node("%Icon").texture = null
			slot.get_node("%QuantityLabel").hide()

func _setup_slot(slot, item):
	var icon_rect = slot.get_node("%Icon")
	var qty_label = slot.get_node("%QuantityLabel")
	
	# Icon Mapping - Check item_id
	var slug = str(item.get("item_id", ""))
	var tex = null
	
	if slug == "1": tex = icon_gm_kodex
	elif slug == "2": tex = icon_potion
	elif slug == "3": tex = icon_sword
	elif slug == "4": tex = icon_armor
	elif slug == "6": tex = icon_broadsword
	elif slug == "7": tex = icon_magic_staff
	elif slug == "8": tex = icon_sneaky_dagger
	elif slug == "9": tex = icon_divine_barricade
	elif slug == "10": tex = icon_mana_potion
	elif slug == "11": tex = icon_speed_potion
	elif slug == "12": tex = icon_strength_potion
	elif slug == "13": tex = icon_intellect_potion
	elif slug == "14": tex = icon_luck_potion
	
	if tex:
		if tex.get_width() > 0:
			icon_rect.texture = tex
			print("[UI] InventoryWindow: Applied texture for '", slug, "'. Size: ", tex.get_size())
		else:
			print("[ERROR] InventoryWindow: Texture for '", slug, "' exists but has 0 size! Fallback.")
			icon_rect.texture = fallback_icon
	else: 
		print("[UI] InventoryWindow: No specific icon mapping for '", slug, "'. Fallback.")
		icon_rect.texture = fallback_icon
	
	var qty = int(item.get("quantity", 1))
	print("[UI] InventoryWindow: Slot ", slot.slot_index, " quantity: ", qty)
	
	if qty > 1:
		qty_label.text = str(qty)
		qty_label.show()
	else:
		qty_label.hide()
		
	if item.get("equipped", false):
		slot.modulate = Color(0.5, 1, 0.5, 1) # Simple modulate for equip status
	else:
		slot.modulate = Color(1, 1, 1, 1)

func _on_item_used(s_idx: int):
	var items = NetworkManager.current_player_data.get("inventory", [])
	var used_item = null
	for it in items:
		if int(it.get("slot", -1)) == s_idx:
			used_item = it
			break
			
	if not used_item: return
	
	var slug = used_item.get("item_id", "")
	if slug == "1":
		print("[UI] GMKodex benutzt! Öffne Menü.")
		gm_menu_requested.emit()
	else:
		print("[UI] Item benutzt: ", slug, " in Slot ", s_idx)
		NetworkManager.use_item(s_idx)

func _on_inventory_updated(items):
	print("InventoryWindow: Signal received. Count: ", items.size())
	update_inventory()
