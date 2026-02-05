extends Node

var BASE_URL = "http://localhost:3000/api"
var WS_URL = "ws://localhost:3001/ws"
const SAVE_PATH = "user://session.cfg"

var auth_token: String = ""
var current_player_data = null
var socket = WebSocketPeer.new()
var is_connected_to_ws = false
var is_authenticating = false
var teleport_locked = false
var item_template_cache = {} # id -> {name, description, rarity, extra_data}

signal ws_connected
signal ws_connection_failed(reason: String)
signal ws_authenticated

signal login_finished(success: bool, message: String)
signal characters_loaded(chars: Array)
signal character_created(success: bool, message: String)
signal character_deleted(success: bool, message: String)
signal player_moved(data: Dictionary)
signal logout_timer_started(seconds: int)
signal logout_cancelled(reason: String)
signal logout_complete()
signal map_changed(new_map: String, position: Vector3, rotation_y: float)
signal player_left(username: String)
signal chat_received(data: Dictionary)
signal mobs_synchronized(mob_data: Array)
signal spell_cast_started(caster: String, spell_id: String, duration: float)
signal spell_cast_finished(caster: String, target_id: String, spell_id: String, extra_data: Dictionary)
signal player_status_updated(data: Dictionary)
signal combat_text_received(data: Dictionary)
signal party_invite_received(from: String)
signal party_updated(members: Array)
signal trade_invited(from_username: String, from_charname: String)
signal trade_started(partner_name: String)
signal trade_updated(my_items: Array, partner_items: Array, my_ready: bool, partner_ready: bool)
signal trade_completed()
signal trade_canceled()
signal player_leveled_up(username: String)
signal game_objects_received(objects: Array)
signal inventory_updated(items: Array)
signal quest_info_received(data: Dictionary)
signal quest_accepted(data: Dictionary)
signal quest_completed(quest_id: String)
signal quest_rewarded(quest_id: String)
signal quest_progress_updated(quest_id: String, progress: Dictionary)
signal quest_sync_received(quests: Array)
signal spellbook_updated(abilities: Array)

func _ready():
	load_realmlist()
	load_session()

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_ws:
			print("NetworkManager: WebSocket offen!")
			is_connected_to_ws = true
			ws_connected.emit()
			
		var packets_processed = 0
		while socket.get_available_packet_count() > 0 and packets_processed < 25:
			var packet = socket.get_packet()
			_on_ws_message(packet.get_string_from_utf8())
			packets_processed += 1
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		
		if is_connected_to_ws:
			print("WS Verbindung verloren. Code: ", code, " Grund: ", reason)
			is_connected_to_ws = false
			is_authenticating = false
			current_player_data = null
			get_tree().change_scene_to_file("res://Screens/LoginScreen.tscn")
		else:
			# Verbindung wurde gar nicht erst aufgebaut
			pass 
	elif state == WebSocketPeer.STATE_CONNECTING:
		pass


func connect_to_ws():
	if is_ws_connected(): 
		ws_connected.emit()
		return
		
	print("NetworkManager: Verbinde zu WebSocket: ", WS_URL)
	is_connected_to_ws = false
	is_authenticating = false
	
	var err = socket.connect_to_url(WS_URL)
	if err != OK:
		print("WS Fehler beim Verbinden: ", err)
		ws_connection_failed.emit("Verbindung konnte nicht gestartet werden.")
		return
	
	# Timeout Timer
	get_tree().create_timer(5.0).timeout.connect(func():
		if not is_connected_to_ws:
			socket.close()
			ws_connection_failed.emit("Zeitüberschreitung bei Verbindung zum Worldserver.")
	)

func _on_ws_message(message: String):
	var data = JSON.parse_string(message)
	if data == null: return
	
	match data.get("type"):
		"authenticated":
			print("[NET] Received authenticated packet: ", data)
			if current_player_data:
				# Merge all authentication data into current_player_data
				for key in data:
					if key != "type":
						current_player_data[key] = data[key]
				
				if data.has("username"):
					current_player_data["username"] = data.get("username")
					print("NetworkManager: Username stored: ", current_player_data["username"])
			is_authenticating = false
			ws_authenticated.emit()
		"player_moved":
			player_moved.emit(data)
		"logout_timer_started":
			logout_timer_started.emit(data.get("seconds", 10))
		"logout_cancelled":
			logout_cancelled.emit(data.get("reason", ""))
		"logout_complete":
			logout_complete.emit()
		"map_changed":
			var new_map = data.get("map_name")
			var pos_dict = data.get("position", {"x":0, "y":0, "z":0})
			var ry = data.get("rotation_y", 0.0)
			var pos = Vector3(pos_dict.x, pos_dict.y, pos_dict.z)
			
			if current_player_data:
				current_player_data["world_state"]["map_name"] = new_map
				current_player_data["transform"]["position_x"] = pos.x
				current_player_data["transform"]["position_y"] = pos.y
				current_player_data["transform"]["position_z"] = pos.z
				current_player_data["transform"]["rotation"] = ry
			map_changed.emit(new_map, pos, ry)
			
			# Lock für 2 Sekunden aufrechterhalten nach Ankunft
			await get_tree().create_timer(2.0).timeout
			teleport_locked = false
		"player_left":
			player_left.emit(data.get("username"))
		"chat_receive":
			chat_received.emit(data)
		"mob_sync":
			mobs_synchronized.emit(data.get("mobs", []))
		"spell_cast_start":
			print("[NET] Spell cast start: ", data)
			spell_cast_started.emit(data.get("caster", ""), data.get("spell", ""), data.get("duration", 0.0))
		"spell_cast_finish":
			print("[NET] Spell cast finish: ", data)
			spell_cast_finished.emit(data.get("caster", ""), data.get("target_id", ""), data.get("spell", ""), data)
		"player_status":
			var tech_uname = data.get("username", "")
			if current_player_data and current_player_data.get("username") == tech_uname:
				# Merge data
				for key in data:
					current_player_data[key] = data[key]
			player_status_updated.emit(data)
		"combat_text":
			combat_text_received.emit(data)
		"party_invite_request":
			party_invite_received.emit(data.get("from", "Unbekannt"))
		"party_update":
			party_updated.emit(data.get("members", []))
		"trade_invited":
			trade_invited.emit(data.get("from_user", ""), data.get("from_char", ""))
		"trade_started":
			trade_started.emit(data.get("partner", ""))
		"trade_update":
			trade_updated.emit(
				data.get("my_items", []),
				data.get("partner_items", []),
				data.get("my_ready", false),
				data.get("partner_ready", false)
			)
		"trade_complete":
			trade_completed.emit()
		"trade_canceled":
			trade_canceled.emit()
		"level_up":
			player_leveled_up.emit(data.get("username", ""))
		"game_objects_init":
			print("WebSocket: Game Objects Init empfangen")
			game_objects_received.emit(data.get("objects", []))
		"inventory_sync":
			var items = data.get("items", [])
			print("[NET] Received inventory_sync with ", items.size(), " items: ", items)
			if current_player_data:
				current_player_data["inventory"] = items
				print("[NET] current_player_data['inventory'] updated. First item id: ", items[0].get("item_id") if items.size() > 0 else "none")
			
			# Cache templates for tooltips (e.g. from chat)
			print("[NET] Updating Template Cache. Items: ", items.size())
			for item in items:
				var iid = str(item.get("item_id", ""))
				if iid != "" and not item_template_cache.has(iid):
					item_template_cache[iid] = {
						"name": item.get("name"),
						"description": item.get("description"),
						"rarity": item.get("rarity"),
						"extra_data": item.get("extra_data", {})
					}
			
			inventory_updated.emit(items)
		"quest_info":
			quest_info_received.emit(data)
		"quest_accepted":
			if current_player_data:
				if not current_player_data.has("quests"): current_player_data["quests"] = []
				current_player_data["quests"].append({
					"quest_id": data.get("quest_id"),
					"status": "active",
					"progress": {}
				})
			quest_accepted.emit(data)
		"quest_completed":
			var qid = data.get("quest_id", "")
			if current_player_data and current_player_data.has("quests"):
				for q in current_player_data["quests"]:
					if q.quest_id == qid:
						q.status = "completed"
						break
			quest_completed.emit(qid)
		"quest_rewarded":
			var qid = data.get("quest_id", "")
			if current_player_data and current_player_data.has("quests"):
				var idx = -1
				for i in range(current_player_data["quests"].size()):
					if current_player_data["quests"][i].quest_id == qid:
						idx = i
						break
				if idx != -1:
					current_player_data["quests"].remove_at(idx)
			quest_rewarded.emit(qid)
		"quest_progress":
			quest_progress_updated.emit(data.get("quest_id", ""), data.get("progress", {}))
		"quest_sync":
			var quests = data.get("quests", [])
			if current_player_data:
				current_player_data["quests"] = quests
			quest_sync_received.emit(quests)
		"spellbook_sync":
			var abilities = data.get("abilities", [])
			if current_player_data:
				current_player_data["abilities"] = abilities
			spellbook_updated.emit(abilities)
		"error":
			print("WS Server Fehler: ", data.get("message"))

func is_ws_connected() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func _send_ws(data: Dictionary):
	if is_ws_connected():
		socket.send_text(JSON.stringify(data))

func send_chat(message: String, target_id: String = ""):
	_send_ws({"type": "chat_message", "message": message, "target_id": target_id})

func cast_spell(spell_id: String, target_id: String):
	_send_ws({
		"type": "cast_spell",
		"spell_id": spell_id,
		"target_id": target_id
	})

func send_party_invite(target_name: String):
	_send_ws({"type": "party_invite", "target_name": target_name})

func send_party_response(from_name: String, accept: bool):
	_send_ws({"type": "party_invite_response", "from": from_name, "accept": accept})

func send_party_leave():
	_send_ws({"type": "party_leave"})

func send_party_kick(target_name: String):
	_send_ws({"type": "party_kick", "target_name": target_name})

func send_target_update(target_id: String):
	_send_ws({"type": "target_update", "target_id": target_id})

func send_move_item(from_slot: int, to_slot: int):
	_send_ws({
		"type": "move_item",
		"from_slot": from_slot,
		"to_slot": to_slot
	})

func use_item(slot_index: int):
	_send_ws({
		"type": "use_item",
		"slot_index": slot_index
	})

func send_destroy_item(slot_index: int):
	_send_ws({
		"type": "destroy_item",
		"slot_index": slot_index
	})

func send_trade_request(target_name: String):
	_send_ws({
		"type": "trade_request",
		"target": target_name
	})

func send_trade_response(partner_name: String, accepted: bool):
	_send_ws({
		"type": "trade_response",
		"partner": partner_name,
		"accepted": accepted
	})

func send_trade_add_item(slot_index: int):
	_send_ws({
		"type": "trade_add_item",
		"slot_index": slot_index
	})

func send_trade_remove_item(trade_slot_index: int):
	_send_ws({
		"type": "trade_remove_item",
		"trade_slot": trade_slot_index
	})

func send_trade_ready(is_ready: bool):
	_send_ws({
		"type": "trade_ready",
		"ready": is_ready
	})

func send_trade_confirm():
	_send_ws({
		"type": "trade_confirm"
	})

func send_quest_interact(npc_id: int):
	_send_ws({"type": "quest_interact", "npc_id": npc_id})

func send_quest_accept(quest_id: String):
	_send_ws({"type": "quest_accept", "quest_id": quest_id})

func send_quest_reward(quest_id: String):
	_send_ws({"type": "quest_reward", "quest_id": quest_id})

func send_trade_cancel():
	_send_ws({
		"type": "trade_cancel"
	})

func request_map_change(map_name: String, position: Vector3, rotation_y: float = 0.0):
	print("!!! NetworkManager: request_map_change. Locked: ", teleport_locked, " Conn: ", is_ws_connected())
	if is_ws_connected() and not teleport_locked:
		teleport_locked = true
		socket.send_text(JSON.stringify({
			"type": "map_change_request",
			"map_name": map_name,
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"rotation_y": rotation_y
		}))
		
		# Fallback: Falls der Server nicht antwortet, nach 5 Sekunden entsperren
		get_tree().create_timer(5.0).timeout.connect(func(): teleport_locked = false)

func request_logout():
	if is_ws_connected():
		socket.send_text(JSON.stringify({"type": "logout_request"}))

func send_player_update(pos: Vector3, rot: Vector3):
	if is_ws_connected():
		var data = {
			"type": "player_update",
			"position": {"x": pos.x, "y": pos.y, "z": pos.z},
			"rotation": {"x": rot.x, "y": rot.y, "z": rot.z}
		}
		socket.send_text(JSON.stringify(data))

func authenticate_ws():
	if auth_token != "" and current_player_data:
		var data = {
			"type": "authenticate",
			"token": auth_token,
			"character_id": current_player_data.get("id")
		}
		socket.send_text(JSON.stringify(data))

# --- LOGIN LOGIK ---
func login_request(username: String, password: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_completed.bind(http))
	
	var body = JSON.stringify({"username": username, "password": password})
	var headers = ["Content-Type: application/json"]
	
	http.request(BASE_URL + "/login", headers, HTTPClient.METHOD_POST, body)

func _on_login_completed(_result, response_code, _headers, body, http):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and response.has("token"):
		auth_token = response["token"]
		save_session(auth_token) # Token für "Only once" Login speichern
		login_finished.emit(true, "Authentifiziert")
	else:
		var err_msg = response.get("error", "Login fehlgeschlagen") if response else "Serverfehler"
		login_finished.emit(false, err_msg)
	
	http.queue_free()

# --- CHARAKTER LOGIK ---
func fetch_characters():
	if auth_token == "":
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_chars_completed.bind(http))
	
	# JWT im Authorization Header mitsenden
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	]
	
	http.request(BASE_URL + "/characters", headers, HTTPClient.METHOD_GET)

func _on_chars_completed(_result, response_code, _headers, body, http):
	if response_code == 200:
		var chars = JSON.parse_string(body.get_string_from_utf8())
		characters_loaded.emit(chars)
	else:
		print("Fehler beim Laden der Charaktere")
	
	http.queue_free()

func create_character(char_name: String, char_class: String):
	if auth_token == "":
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_create_char_completed.bind(http))
	
	var body = JSON.stringify({"name": char_name, "class": char_class})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	]
	
	http.request(BASE_URL + "/characters", headers, HTTPClient.METHOD_POST, body)

func _on_create_char_completed(_result, response_code, _headers, body, http):
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		character_created.emit(true, "Charakter erfolgreich erstellt")
	else:
		var err_msg = response.get("error", "Erstellung fehlgeschlagen") if response else "Serverfehler"
		character_created.emit(false, err_msg)
	http.queue_free()

func delete_character(char_id: int):
	if auth_token == "":
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_delete_char_completed.bind(http))
	
	var body = JSON.stringify({"id": char_id})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	]
	
	http.request(BASE_URL + "/characters/delete", headers, HTTPClient.METHOD_POST, body)

func _on_delete_char_completed(_result, response_code, _headers, body, http):
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		character_deleted.emit(true, "Charakter gelöscht")
	else:
		var err_msg = response.get("error", "Löschen fehlgeschlagen") if response else "Serverfehler"
		character_deleted.emit(false, err_msg)
	http.queue_free()

# --- PERSISTENZ (Best Practice) ---
func save_session(token: String):
	var config = ConfigFile.new()
	config.set_value("Auth", "token", token)
	config.save(SAVE_PATH)

func load_session():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		auth_token = config.get_value("Auth", "token", "")

func load_realmlist():
	var file_path = "res://realmlist.config"
	
	# Falls wir in einem Export-Build sind, schauen wir auch neben der EXE
	if not FileAccess.file_exists(file_path):
		var exe_dir = OS.get_executable_path().get_base_dir()
		file_path = exe_dir + "/realmlist.config"
	
	if FileAccess.file_exists(file_path):
		var f = FileAccess.open(file_path, FileAccess.READ)
		var host_address = f.get_as_text().strip_edges()
		if host_address != "":
			print("NetworkManager: Lade Realmlist von ", file_path, " -> ", host_address)
			BASE_URL = host_address + "/api"
			
			# Wir versuchen die WS URL basierend auf dem Host abzuleiten
			# Wir entfernen http:// oder https:// um den Hostnamen zu bekommen
			var clean_host = host_address.replace("http://", "").replace("https://", "")
			if ":" in clean_host:
				clean_host = clean_host.split(":")[0]
			
			WS_URL = "ws://" + clean_host + ":3001/ws"
			print("NetworkManager: BASE_URL=", BASE_URL, " WS_URL=", WS_URL)
	else:
		print("NetworkManager: Keine realmlist.config gefunden, nutze Standard: ", BASE_URL)
