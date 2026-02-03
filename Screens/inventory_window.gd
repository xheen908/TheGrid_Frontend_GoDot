extends Panel

@onready var grid = %GridContainer
var slot_scene = preload("res://Screens/InventorySlot.tscn")

signal gm_menu_requested()

var icon_sword = preload("res://Assets/UI/item_iron_sword.jpg")
var icon_potion = preload("res://Assets/UI/item_health_potion.jpg")
var icon_armor = preload("res://Assets/UI/item_mythic_chest.jpg")
var icon_gm_kodex = preload("res://Assets/UI/item_gm_kodex.jpg")
var fallback_icon = preload("res://Assets/UI/spell_ice_barrier.jpg")

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
		print("[UI] InventoryWindow: Mapping Item '", item.get("slug", ""), "' to Slot ", s_idx)
		
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		slot.slot_index = i # WICHTIG für Drag & Drop
		slot.item_used.connect(_on_item_used)
		
		if slots_map.has(i):
			var item = slots_map[i]
			slot.item_data = item
			print("[UI] InventoryWindow: Setting up Slot ", i, " with item ", item.get("slug", "unknown"))
			_setup_slot(slot, item)
		else:
			slot.item_data = {}
			slot.get_node("%Icon").texture = null
			slot.get_node("%QuantityLabel").hide()

func _setup_slot(slot, item):
	var icon_rect = slot.get_node("%Icon")
	var qty_label = slot.get_node("%QuantityLabel")
	
	# Icon Mapping - Check both slug and item_slug
	var slug = item.get("slug", item.get("item_slug", ""))
	var tex = null
	
	if "sword" in slug: tex = icon_sword
	elif "potion" in slug: tex = icon_potion
	elif "chest" in slug: tex = icon_armor
	elif "gm_kodex" in slug: tex = icon_gm_kodex
	
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
	
	if qty >= 1: # Zeige Zahl auch bei 1 an, falls gewünscht - sonst > 1
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
	
	var slug = used_item.get("slug", "")
	if slug == "gm_kodex":
		print("[UI] GMKodex benutzt! Öffne Menü.")
		gm_menu_requested.emit()
	else:
		print("[UI] Item benutzt: ", slug, " in Slot ", s_idx)
		# Hier könnte später Heilung etc. passieren

func _on_inventory_updated(items):
	print("InventoryWindow: Signal received. Count: ", items.size())
	update_inventory()
