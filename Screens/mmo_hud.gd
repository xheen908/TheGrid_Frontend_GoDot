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
# Node Caching
@onready var action_slot_1 = %ActionSlot1
@onready var action_slot_2 = %ActionSlot2
@onready var action_slot_3 = %ActionSlot3
@onready var action_slot_4 = %ActionSlot4
@onready var slot_1_sweep = %Slot1Sweep
@onready var slot_2_sweep = %Slot2Sweep
@onready var slot_3_sweep = %Slot3Sweep
@onready var slot_4_sweep = %Slot4Sweep
@onready var slot_1_cd_label = %Slot1CDLabel
@onready var slot_2_cd_label = %Slot2CDLabel
@onready var slot_3_cd_label = %Slot3CDLabel
@onready var slot_4_cd_label = %Slot4CDLabel
@onready var channel_label = %ChannelLabel
@onready var tooltip = %Tooltip
@onready var tooltip_title = %TooltipTitle
@onready var tooltip_type = %TooltipType
@onready var tooltip_description = %TooltipDescription
var last_mouseover_node = null
var target_buff_timer = 0.0
var party_invite_sender = ""
var game_screen_ref = null # Wird von game_screen gesetzt
var last_party_members = []
var last_chat_mode = "" # Merkt sich z.B. "/p " oder "/1 "
var debuff_update_timer = 0.0
var is_refreshing_ui = false
var should_update_target = false

var destroy_dialog: ConfirmationDialog
var destroy_pending_slot: int = -1

func _ready():
	# Initialer Status
	if NetworkManager and NetworkManager.current_player_data:
		if unit_name_label:
			unit_name_label.text = NetworkManager.current_player_data.get("char_name", "Player")
		if unit_level_label:
			unit_level_label.text = "L" + str(NetworkManager.current_player_data.get("level", 1))
		
		# Map Name generieren
		if map_name_label:
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
	%ActionSlot4.pressed.connect(func(): _on_action_slot_pressed(4))
	
	# Chat Signale
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_log.meta_clicked.connect(_on_chat_meta_clicked)
	chat_log.meta_hover_started.connect(_on_chat_meta_hover.bind(true))
	chat_log.meta_hover_ended.connect(_on_chat_meta_hover.bind(false))
	chat_log.meta_underlined = true
	chat_log.mouse_filter = Control.MOUSE_FILTER_STOP
	print("[UI] ChatLog initialized. Mouse filter: ", chat_log.mouse_filter)
	
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
		NetworkManager.trade_invited.connect(_on_trade_invited)
		NetworkManager.trade_started.connect(_on_trade_started)
		NetworkManager.party_updated.connect(_on_party_updated)
	
	%InventoryWindow.gm_menu_requested.connect(func(): %GMCommandMenu.visible = !%GMCommandMenu.visible)
	%InventoryWindow.item_hovered.connect(_on_inventory_item_hovered)
	
	%TargetFrame.gui_input.connect(_on_target_frame_input)
	%PlayerFrame.gui_input.connect(_on_player_frame_input)
	
	# Fix mouse filters for unit frames so clicks reach the parent
	for child in %TargetFrame.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in %PlayerFrame.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	# Fix Action Slots Focus Mode (Prevent locking movement on click)
	var slots = [action_slot_1, action_slot_2, action_slot_3, action_slot_4]
	for slot in slots:
		if slot: slot.focus_mode = Control.FOCUS_NONE
	if has_node("%ActionSlot5"):
		%ActionSlot5.focus_mode = Control.FOCUS_NONE
		
	%TargetContextMenu.id_pressed.connect(_on_target_context_menu_id_pressed)
	%PartyInvitePopup.confirmed.connect(func(): NetworkManager.send_party_response(party_invite_sender, true))
	%PartyInvitePopup.canceled.connect(func(): NetworkManager.send_party_response(party_invite_sender, false))
	
	if has_node("%TradeWindow"):
		print("[INIT] TradeWindow found.")
	else:
		push_error("[INIT] TradeWindow NOT found!")
		
	if has_node("%TradeInvitePopup"):
		print("[INIT] TradeInvitePopup found.")
		%TradeInvitePopup.confirmed.connect(_on_trade_invite_accepted)
		%TradeInvitePopup.canceled.connect(_on_trade_invite_declined)
	else:
		push_error("[INIT] TradeInvitePopup NOT found!")

	if cast_bar: cast_bar.hide()
	
	_setup_destruction_logic()

func _setup_destruction_logic():
	# Create the drop zone (Full screen)
	var drop_zone = Control.new()
	drop_zone.name = "ScreenDropZone"
	drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(drop_zone)
	move_child(drop_zone, 0) # Place it at the back (but it's a CanvasLayer, so it's over the 3D world anyway)
	
	drop_zone.set_script(load("res://Screens/screen_drop_zone.gd"))
	drop_zone.item_dropped_on_screen.connect(_on_item_dropped_on_screen)

	# Create confirmation dialog
	destroy_dialog = ConfirmationDialog.new()
	destroy_dialog.title = "Gegenstand zerstören"
	destroy_dialog.dialog_text = "Möchtest du diesen Gegenstand wirklich unwiderruflich zerstören?"
	destroy_dialog.ok_button_text = "Ja, Zerstören"
	destroy_dialog.cancel_button_text = "Abbrechen"
	add_child(destroy_dialog)
	destroy_dialog.confirmed.connect(_on_destroy_confirmed)

func _on_item_dropped_on_screen(data: Dictionary):
	var item = data.get("item", {})
	destroy_pending_slot = data.get("from_slot", -1)
	
	if destroy_pending_slot != -1:
		var item_name = item.get("name", "Unbekannter Gegenstand")
		destroy_dialog.dialog_text = "Möchtest du \"%s\" wirklich unwiderruflich zerstören?" % item_name
		destroy_dialog.popup_centered()

func _on_destroy_confirmed():
	if destroy_pending_slot != -1:
		print("[UI] Zerstöre Item in Slot: ", destroy_pending_slot)
		NetworkManager.send_destroy_item(destroy_pending_slot)
		destroy_pending_slot = -1

func _input(event):
	if is_rebinding:
		if event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
			_update_action_binding(rebinding_action, rebinding_slot, event)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if %BindingsMenu.visible:
			_on_close_bindings_pressed()
		elif %InventoryWindow.visible:
			%InventoryWindow.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif %GMCommandMenu.visible:
			%GMCommandMenu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			toggle_esc_menu()
	
	if event.is_action_pressed("toggle_inventory"):
		if %InventoryWindow.visible:
			%InventoryWindow.hide()
			if not esc_menu.visible and not %GMCommandMenu.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			%InventoryWindow.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Enter öffnet Chat (Nur echte Enter-Tasten, damit Space frei zum Springen bleibt)
	var is_enter = event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	if is_enter and not chat_input.has_focus() and not %BindingsMenu.visible and not %InventoryWindow.visible and not %GMCommandMenu.visible:
		if not esc_menu.visible:
			chat_input.grab_focus()
			
			# Letzten Chat-Modus visualisieren
			# Letzten Chat-Modus visualisieren
			if last_chat_mode != "" and has_node("%ChannelLabel"):
				var channel_label = %ChannelLabel
				channel_label.text = last_chat_mode
				channel_label.show()
				if last_chat_mode == "[Gruppe]":
					channel_label.add_theme_color_override("font_color", Color.GREEN)
				else:
					channel_label.add_theme_color_override("font_color", Color.WHITE)
			elif has_node("%ChannelLabel"):
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

func _on_chat_meta_hover(meta, entered: bool):
	if not entered:
		hide_tooltip()
		return
		
	var s_meta = str(meta)
	print("[UI] Chat Hover: ", s_meta)
	if s_meta.begins_with("item:"):
		var item_id = s_meta.split(":")[1]
		if NetworkManager.item_template_cache.has(item_id):
			var item_data = NetworkManager.item_template_cache[item_id]
			print("[UI] Showing tooltip from cache for item: ", item_id)
			_on_inventory_item_hovered(item_data, true)
		else:
			print("[UI] Item not in cache: ", item_id, ". Cache size: ", NetworkManager.item_template_cache.size())
			# Fallback if not cached
			show_tooltip({"title": "Gegenstand", "description": "ID: " + item_id, "type": "Unbekannt", "color": Color.WHITE})

func _on_chat_meta_clicked(meta):
	# meta ist der Name des Spielers aus dem [url]-Tag
	_start_whisper(str(meta))

func _on_chat_submitted(text: String):
	var to_send = text
	text = text.strip_edges()
	
	if text != "":
		# --- QUICK TELEPORT COMMAND (tele map) ---
		if text.to_lower().begins_with("tele "):
			to_send = "/" + text
			
		# --- GM COMMAND INTERCEPTION ---
		var is_gm = false
		if player_ref and "is_gm_flagged" in player_ref and player_ref.is_gm_flagged:
			is_gm = true
		elif NetworkManager and NetworkManager.current_player_data and NetworkManager.current_player_data.get("is_gm", false):
			is_gm = true
			
		if is_gm and text.begins_with("/"):
			var parts = text.split(" ", false)
			var cmd = parts[0].to_lower()
			
			if cmd == "/gravity":
				if parts.size() > 1:
					var sub = parts[1].to_lower()
					if sub == "off":
						player_ref.gravity_enabled = false
						_on_chat_received({"mode": "system", "message": "Gravitation deaktiviert (Fly-Mode AN)."})
						chat_input.text = ""
						chat_input.release_focus()
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
						return
					elif sub == "on":
						player_ref.gravity_enabled = true
						_on_chat_received({"mode": "system", "message": "Gravitation aktiviert."})
						chat_input.text = ""
						chat_input.release_focus()
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
						return
			
			elif cmd == "/speed":
				if parts.size() > 1:
					var val = parts[1].to_float()
					if val > 0:
						player_ref.speed_multiplier = val
						_on_chat_received({"mode": "system", "message": "Geschwindigkeit auf %.1f gesetzt." % val})
						chat_input.text = ""
						chat_input.release_focus()
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
						return

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
		elif not has_node("%ChannelLabel") or not %ChannelLabel.visible:
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
	
	# Begrenze Chat-Log auf 100 Einträge um Performance-Einbruch zu verhindern
	if chat_log.get_content_height() > 5000:
		var raw = chat_log.text
		if raw.length() > 5000:
			chat_log.text = raw.right(2500)

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
		
		# Limit UI refresh frequency to avoid stutters (10 Hz instead of 60 Hz)
		debuff_update_timer += delta
		if (debuff_update_timer >= 0.1 or should_update_target) and not is_refreshing_ui:
			debuff_update_timer = 0.0
			should_update_target = false
			_update_target_frames()
		
		_update_3d_mouseover()

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
	var my_name = ""
	var my_username = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
		my_username = str(NetworkManager.current_player_data.get("username", "")).strip_edges().to_lower()
	
	var caster_clean = caster.strip_edges().to_lower()
	
	if caster_clean == my_name or caster_clean == my_username:
		is_casting = true
		casting_timer = 0.0
		casting_duration = duration
		cast_label.text = spell_id.to_upper()
		cast_bar.value = 0
		cast_bar.show()

func _on_spell_cast_finished(caster: String, _target_id: String, spell_id: String, _extra: Dictionary):
	var my_name = ""
	var my_username = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
		my_username = str(NetworkManager.current_player_data.get("username", "")).strip_edges().to_lower()
		
	var caster_clean = caster.strip_edges().to_lower()
	if caster_clean == my_name or caster_clean == my_username:
		is_casting = false
		if cast_bar:
			cast_bar.value = 100.0 # Snap to 100% so shader/effects trigger
			# Kleiner Delay zum Anzeigen des fertigen Balkens
			get_tree().create_timer(0.15).timeout.connect(func(): if not is_casting: cast_bar.hide())
		
		# Spezifische Cooldowns setzen
		if spell_id == "Frost Nova":
			active_cooldowns["Frost Nova"] = {"current": 25.0, "total": 25.0}
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}
		elif spell_id == "Eisbarriere":
			active_cooldowns["Eisbarriere"] = {"current": 30.0, "total": 30.0}
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}
		elif spell_id == "Kältekegel":
			active_cooldowns["Kältekegel"] = {"current": 10.0, "total": 10.0}
			active_cooldowns["GCD"] = {"current": 1.5, "total": 1.5}

func _on_player_target_changed(_new_target):
	_update_target_frames()

func _on_action_slot_pressed(slot):
	if player_ref and not is_casting:
		match slot:
			1: # Frostblitz
				if player_ref.current_target:
					var target = player_ref.current_target
					var tid = target.mob_id if "mob_id" in target else (target.username if "username" in target else "")
					print("[UI] Casting Frostblitz on target: ", tid)
					NetworkManager.cast_spell("Frostblitz", tid)
				else:
					print("[UI] Cannot cast Frostblitz: No target!")
			2: # Frost Nova
				NetworkManager.cast_spell("Frost Nova", "")
			3: # Kältekegel
				NetworkManager.cast_spell("Kältekegel", "")
			4: # Eisbarriere
				NetworkManager.cast_spell("Eisbarriere", "")
	
	# Fokus sicherheitshalber freigeben (obwohl focus_mode=NONE gesetzt ist)
	if get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()



func _update_action_bar_ui():
	# Slot 1
	if slot_1_sweep: slot_1_sweep.hide()
	if action_slot_1: action_slot_1.disabled = false
	
	# Slot 2: Frost Nova
	if active_cooldowns.has("Frost Nova") and slot_2_sweep and slot_2_cd_label:
		var fn = active_cooldowns["Frost Nova"]
		var total = fn.get("total", 25.0)
		if total > 0:
			slot_2_sweep.value = (fn["current"] / total) * 100.0
			slot_2_sweep.show()
		slot_2_cd_label.text = str(ceil(fn["current"]))
		slot_2_cd_label.show()
		if action_slot_2: action_slot_2.disabled = true
	elif active_cooldowns.has("GCD") and slot_2_sweep:
		var gcd = active_cooldowns["GCD"]
		var total = gcd.get("total", 1.5)
		if total > 0:
			slot_2_sweep.value = (gcd["current"] / total) * 100.0
			slot_2_sweep.show()
		if slot_2_cd_label: slot_2_cd_label.hide()
		if action_slot_2: action_slot_2.disabled = true
	else:
		if slot_2_sweep: slot_2_sweep.hide()
		if slot_2_cd_label: slot_2_cd_label.hide()
		if action_slot_2: action_slot_2.disabled = false
		
	# Slot 3: Kältekegel
	if active_cooldowns.has("Kältekegel") and slot_3_sweep and slot_3_cd_label:
		var kc = active_cooldowns["Kältekegel"]
		var total = kc.get("total", 10.0)
		if total > 0:
			slot_3_sweep.value = (kc["current"] / total) * 100.0
			slot_3_sweep.show()
		slot_3_cd_label.text = str(ceil(kc["current"]))
		slot_3_cd_label.show()
		if action_slot_3: action_slot_3.disabled = true
	elif active_cooldowns.has("GCD") and slot_3_sweep:
		var gcd = active_cooldowns["GCD"]
		var total = gcd.get("total", 1.5)
		if total > 0:
			slot_3_sweep.value = (gcd["current"] / total) * 100.0
			slot_3_sweep.show()
		if slot_3_cd_label: slot_3_cd_label.hide()
		if action_slot_3: action_slot_3.disabled = true
	else:
		if slot_3_sweep: slot_3_sweep.hide()
		if slot_3_cd_label: slot_3_cd_label.hide()
		if action_slot_3: action_slot_3.disabled = false
		
	# Slot 4: Eisbarriere
	if active_cooldowns.has("Eisbarriere") and slot_4_sweep and slot_4_cd_label:
		var eb = active_cooldowns["Eisbarriere"]
		var total = eb.get("total", 30.0)
		if total > 0:
			slot_4_sweep.value = (eb["current"] / total) * 100.0
			slot_4_sweep.show()
		slot_4_cd_label.text = str(ceil(eb["current"]))
		slot_4_cd_label.show()
		if action_slot_4: action_slot_4.disabled = true
	elif active_cooldowns.has("GCD") and slot_4_sweep:
		var gcd = active_cooldowns["GCD"]
		var total = gcd.get("total", 1.5)
		if total > 0:
			slot_4_sweep.value = (gcd["current"] / total) * 100.0
			slot_4_sweep.show()
		if slot_4_cd_label: slot_4_cd_label.hide()
		if action_slot_4: action_slot_4.disabled = true
	else:
		if slot_4_sweep: slot_4_sweep.hide()
		if slot_4_cd_label: slot_4_cd_label.hide()
		if action_slot_4: action_slot_4.disabled = false

func _on_player_status_updated(data: Dictionary):
	if not NetworkManager or not NetworkManager.current_player_data: return
	var uname_clean = data.get("username", "").strip_edges().to_lower()
	var my_name = NetworkManager.current_player_data.get("char_name", "").strip_edges().to_lower()
	var my_username = NetworkManager.current_player_data.get("username", "").strip_edges().to_lower()
	
	if uname_clean == my_name or uname_clean == my_username:
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
		if player_ref: player_ref.level = data.get("level", 1)
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
		
	# Player Buff rendering moved to _update_target_frames periodic call to save CPU
	
	# ONLY refresh target if THIS packet belongs to our target
	if is_instance_valid(player_ref) and is_instance_valid(player_ref.current_target):
		var target = player_ref.current_target
		var target_id = target.mob_id if "mob_id" in target else (target.username if "username" in target else "")
		if target_id == uname_clean or target_id == data.get("username", ""):
			should_update_target = true # Flag setzen, _process macht den Rest gedrosselt

func _update_target_frames():
	if not is_instance_valid(player_ref) or is_refreshing_ui: return
	is_refreshing_ui = true
	
	var target = player_ref.current_target
	if not is_instance_valid(target):
		target_frame.hide()
		tot_frame.hide()
		is_refreshing_ui = false
		return
		
	# Target Frame Daten
	target_frame.show()
	target_name_label.text = _get_display_name(target)
	
	# --- OPTIMIZED PLAYER BUFFS (REUSE NODES) ---
	if player_buff_container and NetworkManager.current_player_data:
		var my_buffs = NetworkManager.current_player_data.get("buffs", [])
		_sync_buff_icons(player_buff_container, my_buffs, true)
	
	# --- TARGET BUFFS (REUSE NODES) ---
	var all_effects = []
	if "debuffs" in target and target.debuffs is Array:
		for d in target.debuffs: all_effects.append({"data": d, "is_buff": false})
	if "buffs" in target and target.buffs is Array:
		for b in target.buffs: all_effects.append({"data": b, "is_buff": true})
	
	_sync_buff_icons(debuff_container, all_effects, false)
	
	# Stats mit korrekter Skalierung (wichtig für Bosse!)
	var current_hp = target.get("hp") if target.has_method("get") and target.get("hp") != null else 100
	var current_max_hp = target.get("max_hp") if target.has_method("get") and target.get("max_hp") != null else 100
	
	target_hp_bar.max_value = float(current_max_hp)
	target_hp_bar.value = float(current_hp)
	if target_hp_label:
		target_hp_label.text = "%d / %d" % [int(current_hp), int(current_max_hp)]
	
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
		
	if tot and (tot.hp if "hp" in tot else 100) > 0:
		tot_frame.show()
		tot_name_label.text = _get_display_name(tot)
		var tot_hp = tot.hp if "hp" in tot else 100
		var tot_max = tot.max_hp if "max_hp" in tot else 100
		tot_hp_bar.max_value = tot_max
		tot_hp_bar.value = tot_hp
		if tot_hp_label:
			tot_hp_label.text = "%d/%d" % [tot_hp, tot_max]
		tot_mana_bar.value = 100
	else:
		tot_frame.hide()
	
	is_refreshing_ui = false

func _get_display_name(node) -> String:
	if not node: return "Unknown"
	
	var d_name = ""
	
	# Priority 1: Properties
	if node.get("char_name") and str(node.get("char_name")) != "":
		d_name = str(node.get("char_name"))
	elif node.get("username") and str(node.get("username")) != "":
		d_name = str(node.get("username"))
	elif node.get("mob_name") and str(node.get("mob_name")) != "":
		d_name = str(node.get("mob_name"))
	elif node.get("name") and str(node.get("name")) != "" and not str(node.get("name")).begins_with("@") and str(node.get("name")) != "CharacterBody3D":
		d_name = str(node.get("name"))
	
	# Final Fallback
	if d_name == "":
		d_name = "Unbekannt"
		
	# GM logic
	var is_gm = node.get("is_gm") if node.has_method("get") else false
	if is_gm:
		if not d_name.begins_with("<GM>"):
			d_name = "<GM> " + d_name
			
	return d_name
	
	if "name_label" in node and is_instance_valid(node.name_label):
		return node.name_label.text
		
	return node.name

func _sync_buff_icons(container: Control, effects_data: Array, is_player_data: bool):
	# Bestehende Icons verstecken statt löschen
	var existing_icons = container.get_children()
	for i in range(existing_icons.size()):
		existing_icons[i].hide()
	
	for i in range(effects_data.size()):
		var data = effects_data[i]
		var effect_dict = data.get("data") if data.has("data") else data
		var is_buff_type = data.get("is_buff", true) if data.has("is_buff") else true
		
		var icon = null
		if i < existing_icons.size():
			icon = existing_icons[i]
		else:
			icon = debuff_icon_scene.instantiate()
			container.add_child(icon)
		
		icon.show()
		var d_type = effect_dict.get("type", "Unknown")
		var d_rem = effect_dict.get("remaining", 0)
		
		var rect = icon.get_node("%IconRect")
		if d_type == "Eisbarriere": rect.texture = icon_ice_barrier
		elif d_type == "Frozen": rect.texture = icon_frost_nova
		elif d_type == "Chill": rect.texture = icon_frostblitz
		else: rect.texture = null
		
		var style = icon.get_theme_stylebox("panel").duplicate()
		if is_buff_type:
			style.border_color = Color(1.0, 0.8, 0) # Gold
		else:
			if d_type == "Frozen" or d_type == "Chill":
				style.border_color = Color(0.3, 0.7, 1) # Blau
			else:
				style.border_color = Color(1, 0.2, 0.2) # Rot
		
		icon.add_theme_stylebox_override("panel", style)
		icon.get_node("%TimeLabel").text = str(d_rem)
		
		# Tooltip Signals
		if not icon.mouse_entered.is_connected(_on_buff_icon_hover):
			icon.mouse_entered.connect(_on_buff_icon_hover.bind(data, true, is_buff_type))
			icon.mouse_exited.connect(_on_buff_icon_hover.bind(data, false, is_buff_type))

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
		"cast_3": "Kältekegel",
		"cast_4": "Eisbarriere",
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
	var actions = ["move_forward", "move_backward", "move_left", "move_right", "strafe_left", "strafe_right", "jump", "cast_1", "cast_2", "cast_3", "cast_4", "target_cycle", "camera_left", "camera_right", "camera_up", "camera_down"]
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
	%PartyInvitePopup.dialog_text = "%s lädt dich in eine Gruppe ein." % from
	%PartyInvitePopup.popup_centered()

var trade_invite_sender_username = ""
func _on_trade_invited(from_user: String, from_char: String):
	trade_invite_sender_username = from_user
	%TradeInvitePopup.dialog_text = "%s möchte mit dir handeln." % from_char
	%TradeInvitePopup.popup_centered()

func _on_trade_invite_accepted():
	NetworkManager.send_trade_response(trade_invite_sender_username, true)

func _on_trade_invite_declined():
	NetworkManager.send_trade_response(trade_invite_sender_username, false)

func _on_trade_started(partner: String):
	%TradeWindow.open(partner)
	if %InventoryWindow:
		%InventoryWindow.show() # Automatically show inventory when trading

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
		var my_tech_id = ""
		if NetworkManager and NetworkManager.current_player_data:
			my_tech_id = NetworkManager.current_player_data.get("username", "")
		if my_tech_id != "":
			_show_target_context_menu(my_tech_id)

func _on_target_frame_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var target = player_ref.current_target if player_ref else null
		if target:
			var tech_id = target.get("username") if target.has_method("get") and "username" in target else (target.username if "username" in target else "")
			if tech_id != "":
				_show_target_context_menu(tech_id)

func _show_target_context_menu(t_name: String):
	%TargetContextMenu.clear()
	%TargetContextMenu.set_meta("context_name", t_name)
	
	%TargetContextMenu.add_item("Flüstern", 1)
	
	var is_in_party = false
	var am_leader = false
	var my_name = ""
	var my_tech_id = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = NetworkManager.current_player_data.get("char_name", "")
		my_tech_id = NetworkManager.current_player_data.get("username", "")
		
	for m in last_party_members:
		if m.get("username") == t_name:
			is_in_party = true
		if m.get("username") == my_tech_id and m.get("is_leader"):
			am_leader = true
			
	if t_name != my_tech_id:
		%TargetContextMenu.add_item("Handeln", 4)

	if is_in_party:
		if am_leader and t_name != my_tech_id:
			%TargetContextMenu.add_item("Aus Gruppe entfernen", 2)
		if t_name == my_tech_id:
			%TargetContextMenu.add_item("Gruppe verlassen", 3)
	else:
		if t_name != my_tech_id:
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
		4: # Handeln
			NetworkManager.send_trade_request(target_name)
	
	# Reset meta so it doesn't accidentally trigger on another target frame click
	%TargetContextMenu.set_meta("context_name", "")

func _update_3d_mouseover():
	if not is_instance_valid(game_screen_ref) or not game_screen_ref.is_inside_tree(): return
	
	# Only do raycast if mouse is not over UI
	if _is_mouse_over_ui():
		if last_mouseover_node:
			last_mouseover_node = null
			hide_tooltip()
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_dir = cam.project_ray_normal(mouse_pos)
	var ray_length = 50.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * ray_length)
	query.collide_with_areas = false
	query.collision_mask = 1 | 2 # Layer 1 (Default) or 2 (Mobs)
	
	var space_state = cam.get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	
	if result:
		var node = result.collider
		# Traverse up until we find a targetable group node
		while node and not node.is_in_group("targetable"):
			node = node.get_parent()
			
		if node and node.is_in_group("targetable"):
			if node != last_mouseover_node:
				last_mouseover_node = node
				if node != player_ref:
					_show_node_tooltip(node)
				else:
					hide_tooltip()
			return

	if last_mouseover_node:
		last_mouseover_node = null
		hide_tooltip()

func _is_mouse_over_ui() -> bool:
	var panels = []
	if has_node("%TargetFrame"): panels.append(%TargetFrame)
	if has_node("%PlayerFrame"): panels.append(%PlayerFrame)
	if has_node("%ChatContainer"): panels.append(%ChatContainer)
	if has_node("%ActionBars"): panels.append(%ActionBars)
	if has_node("%MinimapContainer"): panels.append(%MinimapContainer)
	if has_node("%PartyContainer"): panels.append(%PartyContainer)
	if has_node("%GMCommandMenu"): panels.append(%GMCommandMenu)
	if has_node("%TradeWindow"): panels.append(%TradeWindow)
	
	var m_pos = get_viewport().get_mouse_position()
	for p in panels:
		if is_instance_valid(p) and p.visible and p.get_global_rect().has_point(m_pos):
			return true
	return false

func _show_node_tooltip(node):
	if not is_instance_valid(node): return
	var data = {
		"title": _get_display_name(node),
		"type": "Stufe " + str(node.get("level") if node.has_method("get") and node.get("level") != null else 1),
		"color": Color.WHITE
	}
	
	var hp_perc = 100
	if "hp" in node and "max_hp" in node and node.max_hp > 0:
		hp_perc = int((float(node.hp) / node.max_hp) * 100)
	
	if node.is_in_group("mobs"):
		data["type"] += " (Gegner)"
		data["color"] = Color.LIGHT_CORAL
		data["description"] = "[color=red]Gesundheit: %d%%[/color]\nEin gefährliches Wesen." % hp_perc
	elif node.is_in_group("player") or node.is_in_group("remote_player"):
		data["type"] += " (Spieler)"
		data["color"] = Color.AQUAMARINE
		data["description"] = "[color=green]Gesundheit: %d%%[/color]\nEin Verbündeter des Grids." % hp_perc
		
	show_tooltip(data)

func show_tooltip(data: Dictionary):
	if not tooltip: return
	var main_color = data.get("color", Color.WHITE)
	tooltip_title.text = data.get("title", "Unbekannt")
	tooltip_title.modulate = main_color
	tooltip_type.text = data.get("type", "")
	tooltip_description.text = data.get("description", "")
	
	# Border Farbe anpassen
	var style = tooltip.get_theme_stylebox("panel").duplicate()
	style.border_color = main_color
	tooltip.add_theme_stylebox_override("panel", style)
	
	print("[UI] show_tooltip: ", data.get("title"))
	tooltip.show()

func hide_tooltip():
	if tooltip and tooltip.visible:
		print("[UI] hide_tooltip")
		tooltip.hide()

func _on_unit_frame_hover(node, entered):
	if entered and is_instance_valid(node):
		_show_node_tooltip(node)
	else:
		hide_tooltip()

func _on_spell_hover(spell_id: String, entered: bool):
	if entered:
		var data = {"title": spell_id, "type": "Zauber", "color": Color(0.3, 0.7, 1.0)}
		match spell_id:
			"Frostblitz": data["description"] = "Schießt Frost auf das Ziel.\n[color=cyan]Verursacht Frost-Schaden.[/color]"
			"Frost Nova": data["description"] = "Friert alle Gegner in der Nähe ein.\n[color=cyan]Dauer: 8 Sek.[/color]"
			"Kältekegel": data["description"] = "Schaden und Verlangsamung vor dir.\n[color=cyan]Dauer: 6 Sek.[/color]"
			"Eisbarriere": data["description"] = "Schützt dich mit einem Eisschild.\n[color=cyan]Absorbiert Schaden.[/color]"
		show_tooltip(data)
	else:
		hide_tooltip()

func _on_buff_icon_hover(buff_data: Dictionary, entered: bool, is_buff: bool):
	if entered:
		var b_type = buff_data.get("data", {}).get("type", "Unbekannt") if buff_data.has("data") else buff_data.get("type", "Unbekannt")
		var b_rem = buff_data.get("data", {}).get("remaining", 0) if buff_data.has("data") else buff_data.get("remaining", 0)
		
		var data = {
			"title": b_type,
			"type": "Vorteil" if is_buff else "Nachteil",
			"color": Color.GOLD if is_buff else Color.RED,
			"description": "Verbleibende Zeit: [color=yellow]%ds[/color]" % b_rem
		}
		show_tooltip(data)
	else:
		hide_tooltip()

func _setup_action_slots():
	# Tooltip Signals verbinden
	if action_slot_1:
		action_slot_1.mouse_entered.connect(_on_spell_hover.bind("Frostblitz", true))
		action_slot_1.mouse_exited.connect(_on_spell_hover.bind("Frostblitz", false))
	if action_slot_2:
		action_slot_2.mouse_entered.connect(_on_spell_hover.bind("Frost Nova", true))
		action_slot_2.mouse_exited.connect(_on_spell_hover.bind("Frost Nova", false))
	if action_slot_3:
		action_slot_3.mouse_entered.connect(_on_spell_hover.bind("Kältekegel", true))
		action_slot_3.mouse_exited.connect(_on_spell_hover.bind("Kältekegel", false))
	if action_slot_4:
		action_slot_4.mouse_entered.connect(_on_spell_hover.bind("Eisbarriere", true))
		action_slot_4.mouse_exited.connect(_on_spell_hover.bind("Eisbarriere", false))
	
	# Icon Mapping (Fixing swap: 3 is Cone of Cold, 4 is Ice Barrier)
	var slots = {
		"%ActionBar1Icon": "res://Assets/UI/spell_frostblitz.jpg",
		"%ActionBar2Icon": "res://Assets/UI/spell_frost_nova.jpg",
		"%ActionBar3Icon": "res://Assets/UI/spell_cone_of_cold.jpg",
		"%ActionBar4Icon": "res://Assets/UI/spell_ice_barrier.jpg"
	}
	
	# Compatibility check for direct node access
	var icon_slots = {
		"%ActionSlot1": "res://Assets/UI/spell_frostblitz.jpg",
		"%ActionSlot2": "res://Assets/UI/spell_frost_nova.jpg",
		"%ActionSlot3": "res://Assets/UI/spell_cone_of_cold.jpg",
		"%ActionSlot4": "res://Assets/UI/spell_ice_barrier.jpg"
	}
	
	for slot_name in icon_slots:
		if has_node(slot_name):
			var slot = get_node(slot_name)
			var icon_node = slot.get_node_or_null("Icon")
			if icon_node:
				var tex_path = icon_slots[slot_name]
				if ResourceLoader.exists(tex_path):
					icon_node.texture = load(tex_path)
	
	if %PlayerFrame:
		%PlayerFrame.mouse_entered.connect(func(): if is_instance_valid(player_ref): _on_unit_frame_hover(player_ref, true))
		%PlayerFrame.mouse_exited.connect(func(): _on_unit_frame_hover(null, false))
	if target_frame:
		target_frame.mouse_entered.connect(func(): if is_instance_valid(player_ref) and player_ref.current_target: _on_unit_frame_hover(player_ref.current_target, true))
		target_frame.mouse_exited.connect(func(): _on_unit_frame_hover(null, false))
	if tot_frame:
		tot_frame.mouse_entered.connect(func(): 
			if is_instance_valid(player_ref) and player_ref.current_target and "current_target" in player_ref.current_target:
				var tot = player_ref.current_target.current_target
				if is_instance_valid(tot): _on_unit_frame_hover(tot, true))
		tot_frame.mouse_exited.connect(func(): _on_unit_frame_hover(null, false))

func _on_inventory_item_hovered(item_data: Dictionary, entered: bool):
	if entered:
		var name = item_data.get("name", "Unbekannt")
		var description = item_data.get("description", "")
		var rarity = item_data.get("rarity", "Common")
		var extra_data = item_data.get("extra_data", {})
		
		var data = {
			"title": name,
			"type": "Gegenstand",
			"color": Color.WHITE
		}
		
		# Rarity Mapping
		match rarity:
			"Common":
				data["color"] = Color.WHITE
				data["type"] = "Normal"
			"Rare":
				data["color"] = Color.YELLOW
				data["type"] = "Rar"
			"Epic":
				data["color"] = Color.ROYAL_BLUE
				data["type"] = "Episch"
			"Legendary":
				data["color"] = Color.RED
				data["type"] = "Legendär"
		
		# Build description with yellow text from component data if present
		var full_desc = description
		if extra_data and extra_data is Dictionary and extra_data.has("yellow_text"):
			if full_desc != "": full_desc += "\n"
			full_desc += "[color=yellow]" + str(extra_data.get("yellow_text")) + "[/color]"
			
		data["description"] = full_desc
		show_tooltip(data)
	else:
		hide_tooltip()
