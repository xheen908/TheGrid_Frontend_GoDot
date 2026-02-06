extends Panel

@onready var left_slots_container = %LeftSlots
@onready var right_slots_container = %RightSlots
@onready var bottom_slots_container = %BottomSlots
@onready var model_anchor = %ModelAnchor
@onready var stats_block = %StatsBlock
@onready var close_button = %CloseButton
@onready var title_label = %Title

var slot_scene = preload("res://Screens/InventorySlot.tscn")
var dragging = false
var drag_offset = Vector2.ZERO

var equipment_slots = {} # slot_name -> slot_node

# Icons
var icon_sword = preload("res://Assets/UI/item_iron_sword.jpg")
var icon_potion = preload("res://Assets/UI/item_health_potion.jpg")
var icon_armor = preload("res://Assets/UI/item_mythic_chest.jpg")
var icon_gm_kodex = preload("res://Assets/UI/item_gm_kodex.jpg")
var fallback_icon = preload("res://Assets/UI/spell_ice_barrier.jpg")
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

# Slot layout:
# Left: Kopf, Halskette, Schultern, Brust, Armschienen, Handschuhe, Gürtel
# Right: Rücken, Hose, Schuhe, Ring 1, Ring 2, Schmuck 1, Schmuck 2
# Bottom: Haupthand, Nebenhand, Fernkampf
const SLOTS_LEFT = ["Head", "Neck", "Shoulders", "Chest", "Bracers", "Gloves", "Waist"]
const SLOTS_RIGHT = ["Back", "Legs", "Feet", "Ring1", "Ring2", "Trinket1", "Trinket2"]
const SLOTS_BOTTOM = ["MainHand", "OffHand", "Ranged"]

func _ready():
	close_button.pressed.connect(hide)
	_setup_slots()
	_update_stats()
	
	NetworkManager.player_status_updated.connect(func(_data): _update_stats())
	NetworkManager.inventory_updated.connect(func(_items): _update_equipment())
	
	visible = false

func _setup_slots():
	for c in left_slots_container.get_children(): c.queue_free()
	for c in right_slots_container.get_children(): c.queue_free()
	for c in bottom_slots_container.get_children(): c.queue_free()
	
	equipment_slots.clear()
	
	for sn in SLOTS_LEFT: _create_slot(sn, left_slots_container)
	for sn in SLOTS_RIGHT: _create_slot(sn, right_slots_container)
	for sn in SLOTS_BOTTOM: _create_slot(sn, bottom_slots_container)

func _create_slot(slot_name: String, container: Control):
	var slot = slot_scene.instantiate()
	container.add_child(slot)
	equipment_slots[slot_name] = slot
	
	slot.set_meta("equipment_slot", true)
	slot.set_meta("slot_name", slot_name)
	slot.tooltip_text = _get_pretty_name(slot_name)
	
	var icon = slot.get_node_or_null("%Icon")
	if icon:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.2)

func _get_pretty_name(slot_name: String) -> String:
	match slot_name:
		"Head": return "Kopf"
		"Neck": return "Halskette"
		"Shoulders": return "Schultern"
		"Chest": return "Brust"
		"Bracers": return "Armschienen"
		"Gloves": return "Handschuhe"
		"Back": return "Rücken"
		"Waist": return "Gürtel"
		"Legs": return "Hose"
		"Feet": return "Schuhe"
		"Ring1", "Ring2": return "Ring"
		"Trinket1", "Trinket2": return "Schmuck"
		"MainHand": return "Haupthand"
		"OffHand": return "Nebenhand"
		"Ranged": return "Fernkampf / Zauberstab"
	return slot_name

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				move_to_front()
			else:
				dragging = false
	
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func _update_stats():
	for child in stats_block.get_children(): child.queue_free()
	
	if not NetworkManager.current_player_data: return
	
	var data = NetworkManager.current_player_data
	title_label.text = "%s - Stufe %d %s" % [
		data.get("char_name", "Unbekannt"),
		data.get("level", 1),
		data.get("char_class", "Klasse")
	]
	
	_add_stat("Gesundheit:", str(data.get("hp", 0)) + " / " + str(data.get("max_hp", 0)))
	_add_stat("Mana:", str(data.get("mana", 0)) + " / " + str(data.get("max_mana", 0)))
	_add_stat("Stärke:", str(data.get("strength", 10)))
	_add_stat("Beweglichkeit:", str(data.get("agility", 10)))
	_add_stat("Intelligenz:", str(data.get("intelligence", 10)))
	_add_stat("Ausdauer:", str(data.get("stamina", 10)))
	_add_stat("Rüstung:", str(data.get("armor", 0)))

func _add_stat(label_text: String, value_text: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lbl.add_theme_font_size_override("font_size", 14)
	stats_block.add_child(lbl)
	
	var val = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 14)
	stats_block.add_child(val)

func _update_equipment():
	if not NetworkManager.current_player_data: return
	
	for sn in equipment_slots:
		equipment_slots[sn].clear()
		var icon = equipment_slots[sn].get_node("%Icon")
		if icon: icon.modulate = Color(1, 1, 1, 0.2)

	var items = NetworkManager.current_player_data.get("inventory", [])
	for item in items:
		if item.get("equipped", false):
			var extra = item.get("extra_data", {})
			var slot_name = extra.get("equip_slot", "")
			if equipment_slots.has(slot_name):
				var slot = equipment_slots[slot_name]
				slot.item_data = item
				var icon = slot.get_node("%Icon")
				if icon:
					icon.modulate = Color(1, 1, 1, 1)
					icon.texture = get_item_icon(str(item.get("item_id", "")))

func toggle():
	visible = !visible
	if visible:
		_update_stats()
		_update_model()
		_update_equipment()

func _update_model():
	for child in model_anchor.get_children(): child.queue_free()
	if not NetworkManager.current_player_data: return
	
	var char_class = NetworkManager.current_player_data.get("char_class", "Mage")
	var model_path = "res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/%s.fbx" % char_class
	
	if not ResourceLoader.exists(model_path):
		model_path = "res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Mage.fbx"

	if ResourceLoader.exists(model_path):
		var model = load(model_path).instantiate()
		model_anchor.add_child(model)
		model.rotation_degrees.y = 180 
		model.scale = Vector3(1, 1, 1)
		
		var anim = model.get_node_or_null("AnimationPlayer")
		if anim:
			if anim.has_animation("Idle"):
				anim.play("Idle")
			elif anim.get_animation_list().size() > 0:
				anim.play(anim.get_animation_list()[0])
