extends Node3D

# Wir nutzen explizite Pfade zum Testen
@onready var world_container = $WorldContainer
@onready var hud = %MMO_Hud

var current_player = null
var remote_players = {} # username -> node
var mobs = {} # mob_id -> node

# Pfade zu deinen Szenen
var player_scene = preload("res://Screens/Player.tscn")
var remote_player_scene = preload("res://Screens/RemotePlayer.tscn")
var enemy_scene = preload("res://Screens/Enemy.tscn")
var frostbolt_scene = preload("res://Screens/Frostbolt.tscn")
var frostnova_scene = preload("res://Assets/Effects/FrostNova.tscn")
var levelup_effect_scene = preload("res://Assets/Effects/LevelUpEffect.tscn")

func _ready():
	load_map()
	spawn_player()
	
	if hud:
		hud.game_screen_ref = self
	
	if NetworkManager:
		NetworkManager.connect_to_ws()
		get_tree().create_timer(1.0).timeout.connect(NetworkManager.authenticate_ws)
		if not NetworkManager.map_changed.is_connected(_on_map_changed):
			NetworkManager.map_changed.connect(_on_map_changed)
		if not NetworkManager.player_moved.is_connected(_on_remote_player_moved):
			NetworkManager.player_moved.connect(_on_remote_player_moved)
		if not NetworkManager.player_left.is_connected(_on_player_left):
			NetworkManager.player_left.connect(_on_player_left)
		if not NetworkManager.chat_received.is_connected(_on_chat_received_for_bubbles):
			NetworkManager.chat_received.connect(_on_chat_received_for_bubbles)
		if not NetworkManager.spell_cast_started.is_connected(_on_spell_cast_started):
			NetworkManager.spell_cast_started.connect(_on_spell_cast_started)
		if not NetworkManager.spell_cast_finished.is_connected(_on_spell_cast_finished):
			NetworkManager.spell_cast_finished.connect(_on_spell_cast_finished)
		if not NetworkManager.mobs_synchronized.is_connected(_on_mobs_synchronized):
			NetworkManager.mobs_synchronized.connect(_on_mobs_synchronized)
		if not NetworkManager.combat_text_received.is_connected(_on_combat_text_received):
			NetworkManager.combat_text_received.connect(_on_combat_text_received)
		if not NetworkManager.player_status_updated.is_connected(_on_remote_player_status_updated):
			NetworkManager.player_status_updated.connect(_on_remote_player_status_updated)
		if not NetworkManager.player_leveled_up.is_connected(_on_player_leveled_up):
			NetworkManager.player_leveled_up.connect(_on_player_leveled_up)

func _on_remote_player_status_updated(data: Dictionary):
	var uname = data.get("username", "")
	if remote_players.has(uname):
		var rp = remote_players[uname]
		if "hp" in data: rp.hp = data["hp"]
		if "max_hp" in data: rp.max_hp = data["max_hp"]
		if "shield" in data: rp.shield = data["shield"]
		if "buffs" in data: rp.buffs = data["buffs"]
		if "level" in data: rp.level = data["level"]
		# Falls is_gm im Status-Paket ist, auch hier updaten
		if "is_gm" in data: rp.update_remote_data(rp.global_position, rp.rotation, data["is_gm"])
		if "char_class" in data: rp.initialise_class(data["char_class"])
		# EXPLIZITER SHIELD UPDATE
		rp.shield = data.get("shield", 0)
		rp.buffs = data.get("buffs", [])
	elif current_player and NetworkManager.current_player_data.get("char_name") == uname:
		if "hp" in data: current_player.hp = data["hp"]
		if "max_hp" in data: current_player.max_hp = data["max_hp"]
		if "shield" in data: current_player.shield = data["shield"]
		if "buffs" in data: current_player.buffs = data["buffs"]

func _on_player_leveled_up(uname: String):
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
	
	var target_node = null
	if uname.strip_edges().to_lower() == my_name:
		target_node = current_player
	elif remote_players.has(uname):
		target_node = remote_players[uname]
	
	if target_node:
		var effect = levelup_effect_scene.instantiate()
		add_child(effect) # Zu Szene hinzufügen
		effect.global_position = target_node.global_position
		print("LevelUp Effekt für: ", uname)

func _on_player_left(uname: String):
	if remote_players.has(uname):
		remote_players[uname].queue_free()
		remote_players.erase(uname)
		print("Player entfernt: ", uname)

func _on_chat_received_for_bubbles(data: Dictionary):
	# Sprechblasen nur für Map-Chat
	if data.get("mode") != "map":
		return
	
	var sender_name = data.get("from", "")
	var message = data.get("message", "")
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
	
	# GM-Tag für Vergleich entfernen
	var clean_sender = sender_name.replace("<GM> ", "").strip_edges().to_lower()
	
	if clean_sender == my_name:
		if current_player and current_player.has_method("show_message"):
			current_player.show_message(message)
	elif remote_players.has(sender_name): # Key im Dictionary ist der Name mit GM-Tag vom Server? Nein, Remote-Player Key ist uname.
		# Wir prüfen sowohl den Originalnamen als auch den bereinigten Namen
		var rp = null
		if remote_players.has(sender_name): rp = remote_players[sender_name]
		elif remote_players.has(clean_sender): rp = remote_players[clean_sender]
		
		if rp and rp.has_method("show_message"):
			rp.show_message(message)

func _on_map_changed(map_name: String, pos: Vector3, ry: float):
	load_map()
	if current_player:
		current_player.global_position = pos
		current_player.rotation.y = ry
	
	# Bei Map-Wechsel alle Remote-Player & Mobs löschen
	for p in remote_players.values(): p.queue_free()
	remote_players.clear()
	for m in mobs.values(): m.queue_free()
	mobs.clear()

func _on_mobs_synchronized(mob_data_list: Array):
	# Bestehende Mobs updaten oder neue spawnen
	var current_ids = []
	for data in mob_data_list:
		var mid = data.id
		current_ids.append(mid)
		
		if mobs.has(mid):
			mobs[mid].update_data(data)
		else:
			var m = enemy_scene.instantiate()
			add_child(m)
			m.setup(data)
			mobs[mid] = m
			print("Mob gespawnt: ", data.name)
	
	# Mobs löschen, die nicht mehr in der Liste sind
	var to_remove = []
	for mid in mobs.keys():
		if not mid in current_ids:
			to_remove.append(mid)
	
	for mid in to_remove:
		mobs[mid].queue_free()
		mobs.erase(mid)

func _on_remote_player_moved(data: Dictionary):
	var uname = data.get("username", "")
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
	
	# Sicherheits-Check: Falls uname unser eigener Name ist, ignorieren (verhindert Geister-Models)
	if uname == "" or uname.strip_edges().to_lower() == my_name:
		if current_player and current_player.has_method("update_gm_status"):
			current_player.update_gm_status(data.get("is_gm", false))
		return 
	
	var pos_dict = data.get("position", {"x":0, "y":0, "z":0})
	var pos = Vector3(pos_dict.x, pos_dict.y, pos_dict.z)
	var rot_dict = data.get("rotation", {"y":0})
	var rot = Vector3(0, rot_dict.y, 0)
	var is_gm = data.get("is_gm", false)
	
	if remote_players.has(uname):
		remote_players[uname].update_remote_data(pos, rot, is_gm)
		if "char_class" in data: remote_players[uname].initialise_class(data["char_class"])
	else:
		# KRITISCHER CHECK: Prüfen ob bereits ein Knoten für diesen Namen existiert
		# (Verhindert Duplikate bei schnellen Reconnects oder Sync-Fehlern)
		for existing_rp in get_tree().get_nodes_in_group("remote_player"):
			if existing_rp.get("username") == uname:
				print("Verwaistes Model gefunden für ", uname, ". Re-assigning.")
				remote_players[uname] = existing_rp
				existing_rp.update_remote_data(pos, rot, is_gm)
				if "char_class" in data: existing_rp.initialise_class(data["char_class"])
				return
		
		# Neuer Spieler!
		var rp = remote_player_scene.instantiate()
		add_child(rp)
		rp.setup(uname, pos, is_gm)
		if "char_class" in data: rp.initialise_class(data["char_class"])
		remote_players[uname] = rp
		print("Remote Player verbunden: ", uname)

func _on_spell_cast_started(caster: String, spell_id: String, _duration: float):
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()

	if caster.strip_edges().to_lower() == my_name:
		if current_player and current_player.has_method("start_casting"):
			current_player.start_casting(spell_id)
	elif remote_players.has(caster):
		var rp = remote_players[caster]
		if rp.has_method("start_casting"):
			rp.start_casting(spell_id)

func _on_spell_cast_finished(caster: String, target_id: String, spell_id: String, extra_data: Dictionary):
	var my_name = ""
	if NetworkManager and NetworkManager.current_player_data:
		my_name = str(NetworkManager.current_player_data.get("char_name", "")).strip_edges().to_lower()
	
	var caster_node = null
	
	if caster.strip_edges().to_lower() == my_name:
		caster_node = current_player
		if current_player and current_player.has_method("stop_casting"):
			current_player.stop_casting()
			if spell_id == "interrupted":
				if current_player.has_method("show_message"):
					current_player.show_message("Unterbrochen!")
	elif remote_players.has(caster):
		caster_node = remote_players[caster]
		if caster_node.has_method("stop_casting"):
			caster_node.stop_casting()

	if spell_id == "Eisbarriere":
		# AoE Spawnen (Optional falls Eisbarriere auch ein AoE-Effekt hat, hier eher Schild-Logik)
		if caster_node:
			caster_node.shield = 2666 # Sofortiger visueller Trigger
			if "buffs" in caster_node:
				# Temporären Buff hinzufügen bis das nächste Status-Update vom Server kommt
				var found = false
				for b in caster_node.buffs:
					if b.get("type") == "Eisbarriere":
						found = true
						break
				if not found:
					caster_node.buffs.append({"type": "Eisbarriere", "remaining": 30})
	
	if spell_id == "Frost Nova":
		# AoE Spawnen
		var pos_dict = extra_data.get("pos", {})
		var spawn_pos = Vector3(pos_dict.get("x", 0), pos_dict.get("y", 0), pos_dict.get("z", 0))
		if caster_node and spawn_pos == Vector3.ZERO:
			spawn_pos = caster_node.global_position
			
		var nova = frostnova_scene.instantiate()
		add_child(nova)
		nova.global_position = spawn_pos + Vector3(0, 0.1, 0)
	elif spell_id == "Frostblitz":
		# Projektil spawnen
		if caster_node and mobs.has(target_id):
			var target_node = mobs[target_id]
			var bolt = frostbolt_scene.instantiate()
			add_child(bolt)
			bolt.global_position = caster_node.global_position + Vector3(0, 1.5, 0)
			bolt.setup(target_node)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Cleanup if needed
		get_tree().quit()

func load_map():
	if not world_container:
		return
	
	var map_name = "WorldMap0" # Default
	if NetworkManager and NetworkManager.current_player_data:
		var world_state = NetworkManager.current_player_data.get("world_state", {})
		map_name = world_state.get("map_name", "WorldMap0")
	
	print("Lade Map: ", map_name)
	var map_path = "res://Maps/" + map_name + ".tscn"
	
	if ResourceLoader.exists(map_path):
		for child in world_container.get_children():
			child.queue_free()
			
		var map_res = load(map_path)
		var map = map_res.instantiate()
		world_container.add_child(map)
		print("Erfolg: Map ", map_name, " geladen.")
	else:
		printerr("FEHLER: Map-Datei nicht gefunden: ", map_path)

func spawn_player():
	if player_scene:
		# KRITISCHER FIX: Verhindere Doppel-Spawns
		var existing = get_tree().get_nodes_in_group("player")
		for ep in existing:
			print("Alten Player entfernt vor Neu-Spawn.")
			ep.queue_free()
			
		var player = player_scene.instantiate()
		add_child(player)
		current_player = player
		
		# HUD Link
		if hud:
			hud.player_ref = player
		
		# Position vom Server/Daten nutzen
		if NetworkManager and NetworkManager.current_player_data:
			var transform_data = NetworkManager.current_player_data.get("transform", {})
			var px = transform_data.get("position_x", 0.0)
			var py = transform_data.get("position_y", 5.0) # Etwas über dem Boden
			var pz = transform_data.get("position_z", 0.0) # Falls vorhanden
			player.global_position = Vector3(px, py, pz)
			print("Erfolg: Player gespawnt an ", player.global_position)
			
			# GM Status initial setzen
			var gm_status = NetworkManager.current_player_data.get("gm_status", false)
			if player.has_method("update_gm_status"):
				player.update_gm_status(gm_status)
				
			# Klasse initial setzen
			var char_class = NetworkManager.current_player_data.get("char_class", "")
			if char_class == "":
				var class_info = NetworkManager.current_player_data.get("class_info", {})
				char_class = class_info.get("class_name", "Mage")
			
			if player.has_method("initialise_class"):
				player.initialise_class(char_class)
		else:
			player.global_position = Vector3(0, 5, 0)
			print("Erfolg: Player gespawnt an Default Position.")
	else:
		printerr("FEHLER: Player.tscn konnte nicht geladen werden!")
func _on_combat_text_received(data: Dictionary):
	var target_id = data.get("target_id", "")
	var val = str(data.get("value", ""))
	var is_crit = data.get("is_crit", false)
	var color = Color(data.get("color", "#FFFFFF"))
	
	var spawn_pos = Vector3.ZERO
	
	if target_id == "player":
		if current_player:
			spawn_pos = current_player.global_position + Vector3(0, 2.5, 0)
	elif mobs.has(target_id):
		spawn_pos = mobs[target_id].global_position + Vector3(0, 2.0, 0)
	
	if spawn_pos != Vector3.ZERO:
		_spawn_floating_text_2d(spawn_pos, val, is_crit, color)

func _spawn_floating_text_2d(world_pos: Vector3, text: String, is_crit: bool, color: Color):
	# Wir nutzen jetzt 2D Labels für absolute Schärfe und feste Screen-Größe
	var label = Label.new()
	add_child(label)
	
	# Styling
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var font_size = 30 if is_crit else 22
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	if is_crit:
		label.text = "!!! " + text + " !!!"
		# Shake Effect (2D)
		var shake_tween = create_tween()
		shake_tween.set_loops(5)
		shake_tween.tween_property(label, "position:x", 5.0, 0.05).as_relative()
		shake_tween.tween_property(label, "position:x", -5.0, 0.05).as_relative()
		shake_tween.tween_property(label, "position:x", 0.0, 0.05).as_relative()

	# Positionierungs-Logik (Folgt der 3D-Welt im 2D-Raum)
	var cam = get_viewport().get_camera_3d()
	if not cam: 
		label.queue_free()
		return
		
	var screen_pos = cam.unproject_position(world_pos)
	label.position = screen_pos - label.size / 2.0
	
	# Animation (Ansteigen und Ausblenden)
	var tween = create_tween()
	tween.set_parallel(true)
	# Wir nutzen ein Custom-Property-Update für das Mitlaufen, wenn wir uns bewegen würden, 
	# aber für einen schnellen Effekt reicht das Ansteigen im 2D Raum:
	tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
