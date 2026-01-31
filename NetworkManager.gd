extends Node

const BASE_URL = "http://localhost:3000/api"
const WS_URL = "ws://localhost:3001/ws"
const SAVE_PATH = "user://session.cfg"

var auth_token: String = ""
var current_player_data = null
var socket = WebSocketPeer.new()
var is_connected_to_ws = false
var teleport_locked = false

signal login_finished(success: bool, message: String)
signal characters_loaded(chars: Array)
signal character_created(success: bool, message: String)
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
signal player_leveled_up(username: String)

func _ready():
	load_session()

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		is_connected_to_ws = true
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			_on_ws_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_ws:
			print("WS Verbindung verloren. Kehre zum Login zurück...")
			is_connected_to_ws = false
			current_player_data = null
			get_tree().change_scene_to_file("res://Screens/LoginScreen.tscn")
		elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			# Falls der Verbindungsaufbau fehlschlägt
			# Wir setzen is_connected_to_ws auf false zur Sicherheit
			is_connected_to_ws = false

func connect_to_ws():
	print("Verbinde zu WebSocket...")
	var err = socket.connect_to_url(WS_URL)
	if err != OK:
		print("WS Fehler beim Verbinden: ", err)
		return
	
	# Warten bis offen (passiert in _process)

func _on_ws_message(message: String):
	var data = JSON.parse_string(message)
	if data == null: return
	
	match data.get("type"):
		"authenticated":
			print("WS erfolgreich authentifiziert!")
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
			spell_cast_started.emit(data.get("caster", ""), data.get("spell", ""), data.get("duration", 0.0))
		"spell_cast_finish":
			spell_cast_finished.emit(data.get("caster", ""), data.get("target_id", ""), data.get("spell", ""), data)
		"player_status":
			var uname = data.get("username", "")
			if current_player_data.get("char_name") == uname:
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
		"level_up":
			player_leveled_up.emit(data.get("username", ""))
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

func create_character(char_name: String):
	if auth_token == "":
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_create_char_completed.bind(http))
	
	var body = JSON.stringify({"name": char_name})
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

# --- PERSISTENZ (Best Practice) ---
func save_session(token: String):
	var config = ConfigFile.new()
	config.set_value("Auth", "token", token)
	config.save(SAVE_PATH)

func load_session():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		auth_token = config.get_value("Auth", "token", "")
