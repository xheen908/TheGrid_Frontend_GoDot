extends CanvasLayer

@onready var hp_bar = %HealthBar
@onready var mana_bar = %ManaBar
@onready var minimap_camera = %MinimapCamera
@onready var esc_menu = %EscMenu
@onready var logout_label = %LogoutLabel
@onready var map_name_label = %MapNameLabel

@onready var target_frame = %TargetFrame
@onready var target_name_label = %TargetName
@onready var target_hp_bar = %TargetHealthBar
@onready var target_mana_bar = %TargetManaBar
@onready var hp_label = %HPLabel
@onready var target_hp_label = %TargetHPLabel

@onready var tot_frame = %TargetOfTargetFrame
@onready var tot_name_label = %ToTName
@onready var tot_hp_bar = %ToTHealthBar
@onready var tot_mana_bar = %ToTManaBar
@onready var tot_hp_label = %ToTHPLabel

@onready var unit_name_label = %UnitName
@onready var unit_level_label = %UnitLevel
@onready var xp_bar = %XPBar
@onready var xp_label = %XPLabel

@onready var debuff_container = %DebuffContainer
@onready var player_buff_container = %PlayerBuffContainer
var debuff_icon_scene = preload("res://Screens/DebuffIcon.tscn")
var icon_frostblitz = preload("res://Assets/UI/spell_frostblitz.jpg")
var icon_frost_nova = preload("res://Assets/UI/spell_frost_nova.jpg")
var icon_ice_barrier = preload("res://Assets/UI/spell_ice_barrier.jpg")
# Default icon removed to fix preload error

@onready var cast_bar = %CastBar
@onready var cast_label = %CastLabel

var player_ref = null : set = set_player_ref
var logout_seconds = 0
var pending_action = "" # "char_screen" oder "exit"

var casting_timer = 0.0
var casting_duration = 0.0
var is_casting = false

var last_whisper_sender = ""
var whisper_history = [] # Liste der Namen für Tab-Cycling
var current_whisper_index = -1

@onready var chat_log = %ChatLog
@onready var chat_input = %ChatInput

var is_rebinding = false
var rebinding_action = ""
var rebinding_slot = 0 # 0 = Default, 1 = Alt
const INPUT_CONFIG_PATH = "user://input_settings.cfg"

# Cooldown Tracking
var active_cooldowns = {} # "spell_name": { "current": float, "total": float }
var target_buff_timer = 0.0
var party_invite_sender = ""
var game_screen_ref = null # Wird von game_screen gesetzt
var last_party_members = []
var last_chat_mode = "" # Merkt sich z.B. "/p " oder "/1 "

func _ready():
	# Initialer Status
	if NetworkManager and NetworkManager.current_player_data:
		if unit_name_label:
			unit_name_label.text = NetworkManager.current_player_data.get("char_name", "Player")
		if unit_level_label:
			unit_level_label.text = "L" + str(NetworkManager.current_player_data.get("level", 1))
		
		# Map Name generieren
		var raw_map = NetworkManager.current_player_data.get("world_state", {}).get("map_name", "WorldMap0")
		map_name_label.text = _format_map_name(raw_map)
	_load_input_settings()
	
	_setup_action_slots()
	
	print("MMO_Hud: _ready() gestartet.")
	esc_menu.hide()
	logout_label.hide()
	
	# Sicherstellen, dass die UI-Container sichtbar sind
	print("MMO_Hud: Prüfe ActionBars Node...")
	if has_node("%ActionBars"):
		print("MMO_Hud: ActionBars gefunden, zeige an. Aktuelle Sichtbarkeit: ", %ActionBars.visible)
		%ActionBars.show()
	else:
		push_error("MMO_Hud: ActionBars Node NICHT gefunden!")
	%ResumeButton.pressed.connect(_on_resume_pressed)
	%CharScreenButton.pressed.connect(_on_char_screen_pressed)
	%BindingsButton.pressed.connect(_on_bindings_pressed)
	%ExitGameButton.pressed.connect(_on_exit_game_pressed)
	%CloseBindingsButton.pressed.connect(_on_close_bindings_pressed)
	%BindingsMenu.hide()
	
	%ActionSlot1.pressed.connect(func(): _on_action_slot_pressed(1))
	%ActionSlot2.pressed.connect(func(): _on_action_slot_pressed(2))
	%ActionSlot3.pressed.connect(func(): _on_action_slot_pressed(3))
	
	# Chat Signale
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_log.meta_clicked.connect(_on_chat_meta_clicked)
	
	# NetworkManager Signale
	if NetworkManager:
		NetworkManager.logout_timer_started.connect(_on_logout_timer_started)
		NetworkManager.logout_cancelled.connect(_on_logout_cancelled)
		NetworkManager.logout_complete.connect(_on_logout_complete)
		NetworkManager.chat_received.connect(_on_chat_received)
		NetworkManager.spell_cast_started.connect(_on_spell_cast_started)
		NetworkManager.spell_cast_finished.connect(_on_spell_cast_finished)
		NetworkManager.player_status_updated.connect(_on_player_status_updated)
		NetworkManager.party_invite_received.connect(_on_party_invite_received)
		NetworkManager.party_updated.connect(_on_party_updated)
	
	%TargetFrame.gui_input.connect(_on_target_frame_input)
	%PlayerFrame.gui_input.connect(_on_player_frame_input)
	
	# Fix mouse filters for unit frames so clicks reach the parent
	for child in %TargetFrame.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in %PlayerFrame.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	%TargetContextMenu.id_pressed.connect(_on_target_context_menu_id_pressed)
	%PartyInvitePopup.confirmed.connect(func(): NetworkManager.send_party_response(party_invite_sender, true))
	%PartyInvitePopup.canceled.connect(func(): NetworkManager.send_party_response(party_invite_sender, false))

func _input(event):
	if is_rebinding:
		if event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
			_update_action_binding(rebinding_action, rebinding_slot, event)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if %BindingsMenu.visible:
			_on_close_bindings_pressed()
		else:
			toggle_esc_menu()
	
	# Enter öffnet Chat (Präzise auf Enter-Taste prüfen, um Space/Leertaste für Sprung frei zu halten)
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if not chat_input.has_focus() and not esc_menu.visible:
			chat_input.grab_focus()
			
			# Letzten Chat-Modus visualisieren
			if last_chat_mode != "":
				%ChannelLabel.text = last_chat_mode
				%ChannelLabel.show()
				if last_chat_mode == "[Gruppe]":
					%ChannelLabel.add_theme_color_override("font_color", Color.GREEN)
				else:
					%ChannelLabel.add_theme_color_override("font_color", Color.WHITE)
			else:
				%ChannelLabel.hide()
				
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
	
	# R zum Antworten
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if not chat_input.has_focus() and last_whisper_sender != "" and not esc_menu.visible:
			_start_whisper(last_whisper_sender)
			get_viewport().set_input_as_handled()
			
	# Tab zum Durchwechseln der Partner (nur wenn Chat offen)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if chat_input.has_focus() and whisper_history.size() > 0:
			current_whisper_index = (current_whisper_index + 1) % whisper_history.size()
			_start_whisper(whisper_history[current_whisper_index])
			get_viewport().set_input_as_handled()

func _start_whisper(uname: String):
	chat_input.grab_focus()
	chat_input.text = "/w " + uname + " "
	chat_input.caret_column = chat_input.text.length()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_chat_meta_clicked(meta):
	# meta ist der Name des Spielers aus dem [url]-Tag
	_start_whisper(str(meta))

func _on_chat_submitted(text: String):
	var to_send = text
	text = text.strip_edges()
	
	if text != "":
		# Wenn ein Channel-Label aktiv ist, Nachricht davor hängen (AUẞER es ist selbst ein Befehl mit /)
		if %ChannelLabel.visible and not text.begins_with("/"):
			if %ChannelLabel.text == "[Gruppe]":
				to_send = "/p " + text
			elif %ChannelLabel.text == "[Allgemein]":
				to_send = "/1 " + text
		
		# Manuelle Befehle erkennen und Label setzen
		if text.begins_with("/p ") or text == "/p":
			to_send = text
			last_chat_mode = "[Gruppe]"
			if text == "/p": to_send = "" # Nur Modus wechseln
		elif text.begins_with("/1 ") or text == "/1":
			to_send = text
			last_chat_mode = "[Allgemein]"
			if text == "/1": to_send = "" # Nur Modus wechseln
		elif text.begins_with("/s ") or text == "/s":
			to_send = ""
			last_chat_mode = ""
		elif text.begins_with("/w "):
			to_send = text
			# Whisper ist oft einmalig, Modus nicht speichern
		elif not %ChannelLabel.visible:
			# Normaler Chat
			last_chat_mode = ""

		var tid = ""
		if player_ref and player_ref.current_target:
			var target = player_ref.current_target
			if target.has_method("get") and target.get("mob_id") != null:
				tid = target.mob_id
			elif "username" in target:
				tid = target.username
		NetworkManager.send_chat(to_send, tid)
	
	chat_input.text = ""
	chat_input.release_focus()
	# Zurück zum Game-Mode (Steuerung)
	if not esc_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_chat_received(data: Dictionary):
	var mode = data.get("mode", "map")
	var from = data.get("from", "System")
	var message = data.get("message", "")
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = NetworkManager.current_player_data.get("char_name", "")
	
	var bbcode = ""
	match mode:
		"map":
			bbcode = "[color=#00FFFF][[Umgebung] [url=%s]%s[/url]][/color]: %s" % [from, from, message]
		"world":
			bbcode = "[color=#FFFFFF][[Allgemein] [url=%s]%s[/url]][/color]: %s" % [from, from, message]
		"party":
			bbcode = "[color=#00FF00][[Gruppe] [url=%s]%s[/url]][/color]: %s" % [from, from, message]
		"whisper":
			var to = data.get("to", "")
			if from != my_name:
				last_whisper_sender = from
				if not from in whisper_history:
					whisper_history.push_front(from)
				bbcode = "[color=#FF00FF][Von [url=%s]%s[/url]][/color]: %s" % [from, from, message]
			else:
				bbcode = "[color=#FF00FF][An [url=%s]%s[/url]][/color]: %s" % [to, to, message]
		"system":
			bbcode = "[color=yellow][System][/color] %s" % message
		"combat":
			bbcode = "[color=#FFA500][Combat][/color] %s" % message
	
	chat_log.append_text("\n" + bbcode)

func toggle_esc_menu():
	if esc_menu.visible:
		esc_menu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		esc_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_player_ref(val):
	player_ref = val
	if player_ref and player_ref.has_signal("target_changed"):
		if not player_ref.target_changed.is_connected(_on_player_target_changed):
			player_ref.target_changed.connect(_on_player_target_changed)

func _process(delta):
	if is_instance_valid(player_ref):
		var pos = player_ref.global_position
		if minimap_camera:
			minimap_camera.global_position = Vector3(pos.x, 50, pos.z)
		_update_target_frames()

	# Update Cooldowns
	var keys = active_cooldowns.keys()
	for spell in keys:
		var cd = active_cooldowns[spell]
		if cd is Dictionary and "current" in cd:
			active_cooldowns[spell]["current"] -= delta
			if active_cooldowns[spell]["current"] <= 0:
				active_cooldowns.erase(spell)
		else:
			active_cooldowns.erase(spell)
	
	_update_action_bar_ui()
	
	if is_casting:
		casting_timer += delta
		if cast_bar:
			cast_bar.value = (casting_timer / casting_duration) * 100.0

func _on_spell_cast_started(caster: String, spell_id: String, duration: float):
	var my_name = NetworkManager.current_player_data.get("char_name", "")
	if caster == my_name:
		is_casting = true
		casting_timer = 0.0
		casting_duration = duration
		cast_label.text = spell_id.to_upper()
		cast_bar.value = 0
		cast_bar.show()
		
		# GCD starten
		if spell_id != "Frostblitz":
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}

func _on_spell_cast_finished(caster: String, _target_id: String, spell_id: String, _extra: Dictionary):
	var my_name = NetworkManager.current_player_data.get("char_name", "")
	if caster == my_name:
		is_casting = false
		cast_bar.hide()
		
		# Spezifische Cooldowns setzen
		if spell_id == "Frost Nova":
			active_cooldowns["Frost Nova"] = {"current": 25.0, "total": 25.0}
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}
		elif spell_id == "Eisbarriere":
			active_cooldowns["Eisbarriere"] = {"current": 30.0, "total": 30.0}
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}

func _on_player_target_changed(_new_target):
	_update_target_frames()

func _on_action_slot_pressed(slot):
	if player_ref and not is_casting:
		match slot:
			1: # Frostblitz
				if player_ref.current_target:
					NetworkManager.cast_spell("Frostblitz", player_ref.current_target.mob_id if "mob_id" in player_ref.current_target else "")
			2: # Frost Nova
				NetworkManager.cast_spell("Frost Nova", "")
			3: # Eisbarriere
				NetworkManager.cast_spell("Eisbarriere", "")

func _setup_action_slots():
	print("MMO_Hud: _setup_action_slots() gestartet.")
	# Nodes sind jetzt im TSCN definiert
	if has_node("%Slot1CDLabel"): %Slot1CDLabel.hide()
	if has_node("%Slot2CDLabel"): %Slot2CDLabel.hide()
	if has_node("%Slot3CDLabel"): %Slot3CDLabel.hide()
	
	if has_node("%Slot1Sweep"): %Slot1Sweep.value = 0
	if has_node("%Slot2Sweep"): %Slot2Sweep.value = 0
	if has_node("%Slot3Sweep"): %Slot3Sweep.value = 0
	
	# Icon Labels mit Fehlerprüfung
	var slots = {
		"%ActionSlot1": "res://Assets/UI/spell_frostblitz.jpg",
		"%ActionSlot2": "res://Assets/UI/spell_frost_nova.jpg",
		"%ActionSlot3": "res://Assets/UI/spell_ice_barrier.jpg"
	}
	
	for slot_name in slots:
		if has_node(slot_name):
			var slot = get_node(slot_name)
			var icon_node = slot.get_node_or_null("Icon")
			if icon_node:
				var tex_path = slots[slot_name]
				if ResourceLoader.exists(tex_path):
					icon_node.texture = load(tex_path)
				else:
					print("MMO_Hud: Textur fehlt: ", tex_path)
			else:
				print("MMO_Hud: Icon-Knoten fehlt in ", slot_name)
		else:
			print("MMO_Hud: Slot fehlt: ", slot_name)
	print("MMO_Hud: _setup_action_slots() beendet.")

func _update_action_bar_ui():
	# Slot 1
	if has_node("%Slot1Sweep"): %Slot1Sweep.hide()
	if has_node("%ActionSlot1"): %ActionSlot1.disabled = false
	
	# Slot 2: Frost Nova
	if active_cooldowns.has("Frost Nova") and has_node("%Slot2Sweep") and has_node("%Slot2CDLabel"):
		var fn = active_cooldowns["Frost Nova"]
		var total = fn.get("total", 25.0)
		if total > 0:
			%Slot2Sweep.value = (fn["current"] / total) * 100.0
			%Slot2Sweep.show()
		%Slot2CDLabel.text = str(ceil(fn["current"]))
		%Slot2CDLabel.show()
		if has_node("%ActionSlot2"): %ActionSlot2.disabled = true
	elif active_cooldowns.has("GCD") and has_node("%Slot2Sweep"):
		var gcd = active_cooldowns["GCD"]
		var total = gcd.get("total", 1.5)
		if total > 0:
			%Slot2Sweep.value = (gcd["current"] / total) * 100.0
			%Slot2Sweep.show()
		if has_node("%Slot2CDLabel"): %Slot2CDLabel.hide()
		if has_node("%ActionSlot2"): %ActionSlot2.disabled = true
	else:
		if has_node("%Slot2Sweep"): %Slot2Sweep.hide()
		if has_node("%Slot2CDLabel"): %Slot2CDLabel.hide()
		if has_node("%ActionSlot2"): %ActionSlot2.disabled = false
		
	# Slot 3: Eisbarriere
	if active_cooldowns.has("Eisbarriere") and has_node("%Slot3Sweep") and has_node("%Slot3CDLabel"):
		var eb = active_cooldowns["Eisbarriere"]
		var total = eb.get("total", 30.0)
		if total > 0:
			%Slot3Sweep.value = (eb["current"] / total) * 100.0
			%Slot3Sweep.show()
		%Slot3CDLabel.text = str(ceil(eb["current"]))
		%Slot3CDLabel.show()
		if has_node("%ActionSlot3"): %ActionSlot3.disabled = true
	elif active_cooldowns.has("GCD") and has_node("%Slot3Sweep"):
		var gcd = active_cooldowns["GCD"]
		var total = gcd.get("total", 1.5)
		if total > 0:
			%Slot3Sweep.value = (gcd["current"] / total) * 100.0
			%Slot3Sweep.show()
		if has_node("%Slot3CDLabel"): %Slot3CDLabel.hide()
		if has_node("%ActionSlot3"): %ActionSlot3.disabled = true
	else:
		if has_node("%Slot3Sweep"): %Slot3Sweep.hide()
		if has_node("%Slot3CDLabel"): %Slot3CDLabel.hide()
		if has_node("%ActionSlot3"): %ActionSlot3.disabled = false

func _on_player_status_updated(data: Dictionary):
	if not NetworkManager or not NetworkManager.current_player_data: return
	var uname = data.get("username", "")
	var my_name = NetworkManager.current_player_data.get("char_name", "")
	
	if uname == my_name:
		var current_hp = data.get("hp", 100)
		var mhp = data.get("max_hp", 100)
		hp_bar.max_value = mhp
		hp_bar.value = current_hp
		if hp_label:
			var s_text = ""
			var shield = data.get("shield", 0)
			if shield > 0:
				s_text = " (+%d)" % shield
			hp_label.text = "%d%s / %d" % [current_hp, s_text, mhp]
		
		if unit_level_label: unit_level_label.text = "L" + str(data.get("level", 1))
		if unit_name_label and NetworkManager.current_player_data: 
			unit_name_label.text = NetworkManager.current_player_data.get("char_name", "Player")
		
		# XP Bar
		var xp = data.get("xp", 0)
		var max_xp = data.get("max_xp", 1000)
		if xp_bar:
			xp_bar.max_value = max_xp
			xp_bar.value = xp
		if xp_label:
			var perc = (float(xp) / max_xp) * 100.0
			xp_label.text = "%d / %d (%d%%)" % [xp, max_xp, int(perc)]
		
		# Buffs anzeigen
		if player_buff_container:
			for child in player_buff_container.get_children(): child.queue_free()
			var buffs = data.get("buffs", [])
			for b in buffs:
				var icon = debuff_icon_scene.instantiate()
				player_buff_container.add_child(icon)
				var rect = icon.get_node("%IconRect")
				var b_type = b.get("type", "")
				if b_type == "Eisbarriere": rect.texture = icon_ice_barrier
				elif b_type == "Frozen": rect.texture = icon_frost_nova
				elif b_type == "Chill": rect.texture = icon_frostblitz
				else: rect.texture = null
				
				# Rahmenfarbe für Buffs (Gold)
				var style = icon.get_theme_stylebox("panel").duplicate()
				style.border_color = Color(1.0, 0.8, 0.0)
				icon.add_theme_stylebox_override("panel", style)
				
				icon.get_node("%TimeLabel").text = str(b.remaining)
	
	_update_target_frames()

func _update_target_frames():
	if not is_instance_valid(player_ref): return
	
	var target = player_ref.current_target
	if not is_instance_valid(target):
		target_frame.hide()
		tot_frame.hide()
		return
		
	# Target Frame Daten
	target_frame.show()
	target_name_label.text = _get_display_name(target)
	
	# Debuffs & Buffs anzeigen (Icons statt Text)
	target_buff_timer += get_process_delta_time()
	if target_buff_timer >= 0.2:
		target_buff_timer = 0.0
		for child in debuff_container.get_children(): child.queue_free()
		
		var all_effects = []
		if "debuffs" in target and target.debuffs is Array:
			for d in target.debuffs: all_effects.append({"data": d, "is_buff": false})
		if "buffs" in target and target.buffs is Array:
			for b in target.buffs: all_effects.append({"data": b, "is_buff": true})

		for effect in all_effects:
			var d = effect.data
			if d is Dictionary:
				var icon = debuff_icon_scene.instantiate()
				debuff_container.add_child(icon)
				
				var d_type = d.get("type", "Unknown")
				var d_rem = d.get("remaining", 0)
				
				# Icon und Zeit setzen
				var rect = icon.get_node("%IconRect")
				var style = icon.get_theme_stylebox("panel").duplicate()
				
				if d_type == "Eisbarriere": rect.texture = icon_ice_barrier
				elif d_type == "Frozen": rect.texture = icon_frost_nova
				elif d_type == "Chill": rect.texture = icon_frostblitz
				else: rect.texture = null
				
				if effect.is_buff:
					style.border_color = Color(1.0, 0.8, 0) # Gold für Buffs
				else:
					if d_type == "Frozen" or d_type == "Chill":
						style.border_color = Color(0.3, 0.7, 1.0) # Blau für Debuffs
					else:
						style.border_color = Color(1.0, 0.2, 0.2) # Rot für schädliches
				
				icon.add_theme_stylebox_override("panel", style)
				icon.get_node("%TimeLabel").text = str(d_rem)
	
	# Stats mit korrekter Skalierung (wichtig für Bosse!)
	var current_hp = target.get("hp") if "hp" in target else 100
	var current_max_hp = target.get("max_hp") if "max_hp" in target else 100
	target_hp_bar.max_value = current_max_hp
	target_hp_bar.value = current_hp
	if target_hp_label:
		target_hp_label.text = "%d / %d" % [current_hp, current_max_hp]
	
	target_mana_bar.value = 100
	
	# Target of Target
	var tot = null
	if target.has_method("get_target"):
		tot = target.get_target()
	elif "target_name" in target and target.target_name != null:
		# Suche Ziel des Mobs in Gruppen
		var potential = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("remote_player")
		for p in potential:
			if "username" in p and p.username == target.target_name:
				tot = p
				break
			elif p.name == target.target_name: # Fallback
				tot = p
				break
	elif "current_target" in target:
		tot = target.current_target
		
	if tot and tot.get("hp", 100) > 0:
		tot_frame.show()
		tot_name_label.text = _get_display_name(tot)
		var tot_hp = tot.get("hp") if "hp" in tot else 100
		var tot_max = tot.get("max_hp") if "max_hp" in tot else 100
		tot_hp_bar.max_value = tot_max
		tot_hp_bar.value = tot_hp
		if tot_hp_label:
			tot_hp_label.text = "%d/%d" % [tot_hp, tot_max]
		tot_mana_bar.value = 100
	else:
		tot_frame.hide()

func _get_display_name(node) -> String:
	if not node: return "Unknown"
	
	if "username" in node and node.username != "":
		var uname = node.username
		if node.get("is_gm_flagged") == true or node.get("is_gm") == true:
			if not uname.begins_with("<GM>"):
				uname = "<GM> " + uname
		return uname
	
	# Falls es ein Mob ist, hat er ein NameLabel
	var label = node.find_child("NameLabel", true)
	if label and "text" in label:
		return label.text
		
	return node.name

func _on_resume_pressed():
	esc_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_char_screen_pressed():
	pending_action = "char_screen"
	NetworkManager.request_logout()
	esc_menu.hide()

func _on_bindings_pressed():
	esc_menu.hide()
	%BindingsMenu.show()
	_populate_bindings()

func _on_close_bindings_pressed():
	%BindingsMenu.hide()
	esc_menu.show()

func _populate_bindings():
	var list = %ControlList
	# Header behalten, Rest löschen
	for i in range(list.get_child_count() - 1, 0, -1):
		list.get_child(i).queue_free()
	
	var actions = {
		"move_forward": "Vorwärts",
		"move_backward": "Rückwärts",
		"move_left": "Links drehen",
		"move_right": "Rechts drehen",
		"strafe_left": "Strafe Links",
		"strafe_right": "Strafe Rechts",
		"jump": "Springen",
		"cast_1": "Zauber 1",
		"cast_2": "Zauber 2",
		"target_cycle": "Ziel wechseln",
		"camera_left": "Kamera Links",
		"camera_right": "Kamera Rechts",
		"camera_up": "Kamera Hoch",
		"camera_down": "Kamera Runter"
	}
	
	for action in actions:
		var row = HBoxContainer.new()
		list.add_child(row)
		
		var label = Label.new()
		label.text = actions[action]
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		
		var events = InputMap.action_get_events(action)
		
		for i in range(2):
			var b = Button.new()
			b.custom_minimum_size = Vector2(120, 30)
			if events.size() > i:
				b.text = events[i].as_text().replace(" (Physical)", "")
			else:
				b.text = "---"
			
			b.pressed.connect(_on_binding_slot_pressed.bind(action, i, b))
			row.add_child(b)

func _on_binding_slot_pressed(action, slot, button):
	if is_rebinding: return
	is_rebinding = true
	rebinding_action = action
	rebinding_slot = slot
	button.text = "Taste drücken..."
	button.modulate = Color.YELLOW

func _update_action_binding(action, slot, new_event):
	var events = InputMap.action_get_events(action)
	
	# Alte Events entfernen
	InputMap.action_erase_events(action)
	
	# Neue Liste aufbauen
	var new_events = []
	for i in range(max(2, events.size())):
		if i == slot:
			new_events.append(new_event)
		elif i < events.size():
			new_events.append(events[i])
	
	# Alle wieder hinzufügen
	for e in new_events:
		InputMap.action_add_event(action, e)
	
	is_rebinding = false
	_save_input_settings()
	_populate_bindings()

func _save_input_settings():
	var config = ConfigFile.new()
	var actions = ["move_forward", "move_backward", "move_left", "move_right", "strafe_left", "strafe_right", "jump", "cast_1", "cast_2", "target_cycle", "camera_left", "camera_right", "camera_up", "camera_down"]
	for action in actions:
		var events = InputMap.action_get_events(action)
		config.set_value("Input", action, events)
	config.save(INPUT_CONFIG_PATH)

func _load_input_settings():
	var config = ConfigFile.new()
	if config.load(INPUT_CONFIG_PATH) == OK:
		for action in config.get_section_keys("Input"):
			var events = config.get_value("Input", action)
			InputMap.action_erase_events(action)
			for e in events:
				InputMap.action_add_event(action, e)

func _on_exit_game_pressed():
	pending_action = "exit"
	NetworkManager.request_logout()
	esc_menu.hide()

# --- Logout Logik ---

func _on_logout_timer_started(seconds):
	logout_seconds = seconds
	logout_label.text = "Logout in %ds..." % logout_seconds
	logout_label.show()
	_update_countdown()

func _update_countdown():
	if logout_seconds > 0 and logout_label.visible:
		logout_label.text = "Logout in %ds..." % logout_seconds
		await get_tree().create_timer(1.0).timeout
		logout_seconds -= 1
		_update_countdown()

func _on_logout_cancelled(reason):
	logout_label.hide()
	print("Logout abgebrochen: ", reason)
	# Falls das Menu noch offen war oder wir uns bewegt haben

func _on_logout_complete():
	logout_label.hide()
	if pending_action == "char_screen":
		get_tree().change_scene_to_file("res://Screens/CharacterScreen.tscn")
	elif pending_action == "exit":
		get_tree().quit()

func _format_map_name(raw: String) -> String:
	# Wandelt "WorldMap0" -> "WORLD MAP 0" um
	var formatted = ""
	for i in range(raw.length()):
		var char_at = raw[i]
		# Wir fügen ein Leerzeichen vor Großbuchstaben ein, außer wenn davor eine Zahl steht
		var prev_is_digit = i > 0 and raw[i-1] >= "0" and raw[i-1] <= "9"
		if i > 0 and char_at == char_at.to_upper() and not prev_is_digit:
			formatted += " "
		formatted += char_at.to_upper()
	return "ZONE: " + formatted

func _on_party_invite_received(from: String):
	party_invite_sender = from
	%PartyInvitePopup.dialog_text = "Spieler %s lädt dich in eine Gruppe ein." % from
	%PartyInvitePopup.show()

func _on_party_updated(members: Array):
	last_party_members = members
	# Bestehende Party-Frames löschen
	for child in %PartyContainer.get_children():
		child.queue_free()
	
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = NetworkManager.current_player_data.get("char_name", "")

	var count = 0
	for m in members:
		var m_name = m.get("name", "Unknown")
		if m_name == my_name: continue # Don't show self in party frames
		if count >= 4: break
		count += 1
		
		var frame = Panel.new()
		frame.custom_minimum_size = Vector2(200, 65) # Kleinerer, kompakterer Frame
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.3, 0.3, 1)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		frame.add_theme_stylebox_override("panel", style)
		
		# Name Label
		var is_offline = m.get("is_offline", false)
		var lbl = Label.new()
		lbl.text = m_name + (" (Offline)" if is_offline else "")
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if m.get("is_leader", false):
			lbl.text += " (L)"
			lbl.modulate = Color(1, 0.8, 0)
		elif is_offline:
			lbl.modulate = Color(0.6, 0.6, 0.6)
		lbl.set_position(Vector2(5, 2))
		lbl.add_theme_font_size_override("font_size", 11)
		frame.add_child(lbl)
		
		# Visual feedback for offline
		if is_offline:
			frame.modulate.a = 0.5
		
		# HP Bar
		var hp_bar = ProgressBar.new()
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.max_value = m.get("max_hp", 100)
		hp_bar.value = m.get("hp", 100)
		hp_bar.show_percentage = false
		hp_bar.set_position(Vector2(5, 18))
		hp_bar.set_size(Vector2(190, 12))
		var hp_fill = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.8, 0, 0, 1) # Red HP
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		frame.add_child(hp_bar)
		
		# Mana Bar
		var mana_bar = ProgressBar.new()
		mana_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mana_bar.max_value = m.get("max_mana", 100)
		mana_bar.value = m.get("mana", 100)
		mana_bar.show_percentage = false
		mana_bar.set_position(Vector2(5, 32))
		mana_bar.set_size(Vector2(190, 8))
		var mana_fill = StyleBoxFlat.new()
		mana_fill.bg_color = Color(0, 0.4, 0.8, 1) # Blue Mana
		mana_bar.add_theme_stylebox_override("fill", mana_fill)
		frame.add_child(mana_bar)
		
		# Target Label
		var target_lbl = Label.new()
		target_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t_id = m.get("target", "")
		target_lbl.text = "Ziel: " + (t_id if t_id != "" else "Keins")
		target_lbl.set_position(Vector2(5, 42))
		target_lbl.add_theme_font_size_override("font_size", 10)
		target_lbl.modulate = Color(0.7, 0.7, 0.7)
		frame.add_child(target_lbl)
		
		# Click to Target functionality
		frame.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if game_screen_ref and game_screen_ref.remote_players.has(m_name):
						player_ref.set_target(game_screen_ref.remote_players[m_name])
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_show_target_context_menu(m_name)
					
					# Still try to target them if they are in world
					if game_screen_ref and game_screen_ref.remote_players.has(m_name):
						player_ref.set_target(game_screen_ref.remote_players[m_name])
		)
		
		%PartyContainer.add_child(frame)

func _on_player_frame_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var my_name = ""
		if NetworkManager and NetworkManager.current_player_data:
			my_name = NetworkManager.current_player_data.get("char_name", "")
		if my_name != "":
			_show_target_context_menu(my_name)

func _on_target_frame_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var target = player_ref.current_target if player_ref else null
		if target:
			var t_name = target.get("username") if "username" in target else ""
			if t_name != "":
				_show_target_context_menu(t_name)

func _show_target_context_menu(t_name: String):
	%TargetContextMenu.clear()
	%TargetContextMenu.set_meta("context_name", t_name)
	
	%TargetContextMenu.add_item("Flüstern", 1)
	
	var is_in_party = false
	var am_leader = false
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = NetworkManager.current_player_data.get("char_name", "")
		
	for m in last_party_members:
		if m.get("name") == t_name:
			is_in_party = true
		if m.get("name") == my_name and m.get("is_leader"):
			am_leader = true
			
	if is_in_party:
		if am_leader and t_name != my_name:
			%TargetContextMenu.add_item("Aus Gruppe entfernen", 2)
		
		# JEDER in einer Gruppe kann die Gruppe verlassen (über das eigene Menü)
		if t_name == my_name:
			%TargetContextMenu.add_item("Gruppe verlassen", 3)
	else:
		if t_name != my_name:
			%TargetContextMenu.add_item("Einladen", 0)
		
	%TargetContextMenu.position = get_viewport().get_mouse_position()
	%TargetContextMenu.show()

func _on_target_context_menu_id_pressed(id: int):
	var target_name = ""
	
	if %TargetContextMenu.has_meta("context_name"):
		target_name = %TargetContextMenu.get_meta("context_name")
		# We'll clear it after use
	
	if target_name == "":
		return
	
	match id:
		0: # Einladen
			NetworkManager.send_party_invite(target_name)
		1: # Flüstern
			_start_whisper(target_name)
		2: # Kicken
			NetworkManager.send_party_kick(target_name)
		3: # Verlassen
			NetworkManager.send_party_leave()
	
	# Reset meta so it doesn't accidentally trigger on another target frame click
	%TargetContextMenu.set_meta("context_name", "")
