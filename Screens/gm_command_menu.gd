extends Panel

var is_invisible = false
var is_gm_tag = false
var is_fly = false

var available_maps = ["WorldMap0", "Arena0", "Arena1", "Arena2", "Dungeon0", "TestMap0"]

func _ready():
	# Populate Dropdown
	%MapDropdown.clear()
	for map in available_maps:
		%MapDropdown.add_item(map)
		
	%LevelBtn.pressed.connect(_on_level_pressed)
	%TeleBtn.pressed.connect(_on_tele_pressed)
	%InvisibleBtn.pressed.connect(_on_invisible_pressed)
	%TagBtn.pressed.connect(_on_tag_pressed)
	%FlyBtn.pressed.connect(_on_fly_pressed)
	%SpeedBtn.pressed.connect(_on_speed_pressed)
	%InfoBtn.pressed.connect(_on_info_pressed)
	%KickBtn.pressed.connect(_on_kick_pressed)
	%CloseBtn.pressed.connect(hide)
	
	NetworkManager.player_status_updated.connect(_on_status_updated)

func _on_status_updated(data):
	if data.has("username"):
		# Check if our target changed
		pass

func _process(_delta):
	if not visible: return
	
	var target = "Keines"
	if NetworkManager.current_player_data and NetworkManager.current_player_data.has("target_id"):
		target = NetworkManager.current_player_data.target_id
		if target == "": target = "Keines"
	
	%TargetLabel.text = "Ziel: " + target

func _on_level_pressed():
	var val = %LevelInput.value
	NetworkManager.send_chat("/level " + str(val))

func _on_tele_pressed():
	var map_idx = %MapDropdown.selected
	if map_idx >= 0:
		var map = available_maps[map_idx]
		NetworkManager.send_chat("/goto " + map)

func _on_invisible_pressed():
	is_invisible = !is_invisible
	NetworkManager.send_chat("/invisible " + ("on" if is_invisible else "off"))
	%InvisibleBtn.text = "Unsichtbarkeit " + ("AUS" if is_invisible else "AN")

func _on_tag_pressed():
	is_gm_tag = !is_gm_tag
	NetworkManager.send_chat("/gm " + ("on" if is_gm_tag else "off"))
	%TagBtn.text = "GM Tag " + ("AUS" if is_gm_tag else "AN")

func _on_fly_pressed():
	is_fly = !is_fly
	NetworkManager.send_chat("/gravity " + ("off" if is_fly else "on"))
	%FlyBtn.text = "Fly Mode " + ("AUS" if is_fly else "AN")

func _on_speed_pressed():
	NetworkManager.send_chat("/speed 2.5")

func _on_info_pressed():
	NetworkManager.send_chat("/info")

func _on_kick_pressed():
	NetworkManager.send_chat("/kick")
