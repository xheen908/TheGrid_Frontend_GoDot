extends CharacterBody3D

const SPEED = 5.5
const JUMP_VELOCITY = 5.0
const MOUSE_SENSITIVITY = 0.003
const ROTATION_SPEED = 3.0

# Zoom settings
const ZOOM_SPEED = 0.5
const MIN_ZOOM = 0.0
const MAX_ZOOM = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@onready var visuals = $Visuals
@onready var anim_tree = $AnimationTree
@onready var chat_bubble = %ChatBubble
@onready var name_label = $NameLabel

var is_left_mouse_held = false
var is_right_mouse_held = false
var was_moving_last_frame = false

signal target_changed(new_target: Node3D)
var username = ""
var is_gm_flagged = false
var current_target: Node3D = null
var hp = 100
var max_hp = 100
var shield = 0
var buffs = []
var is_casting = false

var selection_circle_scene = preload("res://Screens/SelectionCircle.tscn")
var selection_circle = null

var casting_aura_scene = preload("res://Assets/Effects/CastingAura.tscn")
var casting_aura = null
var skeleton_debug_printed = false

var models = {
	"Barbarian": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Barbarian.fbx"),
	"Knight": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx"),
	"Mage": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Mage.fbx"),
	"Ranger": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Ranger.fbx"),
	"Rogue": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Rogue.fbx")
}
var character_class = "Mage"

func _ready():
	add_to_group("player")
	add_to_group("targetable")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.spring_length = 5.0 # Initial zoom

	_setup_animations()
	
	if anim_tree:
		anim_tree.active = true
		
	# Selection Circle initialisieren
	selection_circle = selection_circle_scene.instantiate()
	get_tree().root.add_child.call_deferred(selection_circle)
	selection_circle.hide()
	
	# Casting Aura initialisieren
	casting_aura = casting_aura_scene.instantiate()
	add_child(casting_aura)
	casting_aura.hide()

func update_gm_status(is_gm: bool):
	var uname = NetworkManager.current_player_data.get("char_name", "Local GM") if NetworkManager and NetworkManager.current_player_data else "GM"
	username = ("<GM> " + uname) if is_gm else uname
	is_gm_flagged = is_gm
	
	if name_label:
		if is_gm:
			name_label.text = "<GM> " + uname
			name_label.modulate = Color.YELLOW
			name_label.show()
		else:
			name_label.hide()

func start_casting(spell_id: String):
	is_casting = true
	if casting_aura and spell_id != "Frostblitz":
		casting_aura.show()
	# Später: Hier echte Animationen auf dem CharacterBody abspielen

func stop_casting():
	is_casting = false
	if casting_aura:
		if shield <= 0:
			casting_aura.hide()

func initialise_class(new_class: String):
	if new_class == "": new_class = "Mage"
	if character_class == new_class and visuals: return
	
	character_class = new_class
	if models.has(new_class):
		var model_scene = models[new_class]
		if visuals:
			var old_transform = visuals.transform
			var old_name = visuals.name
			visuals.queue_free()
			
			visuals = model_scene.instantiate()
			visuals.name = old_name
			visuals.transform = old_transform
			add_child(visuals)
			
			# Re-setup animations for the new model
			_setup_animations()
			if anim_tree:
				var new_anim_player = visuals.find_child("AnimationPlayer", true)
				if new_anim_player:
					anim_tree.anim_player = new_anim_player.get_path()

func _setup_animations():
	# Ensure AnimationPlayer exists
	var anim_player = null
	if visuals:
		anim_player = visuals.find_child("AnimationPlayer", true)
	
	if not anim_player:
		if visuals:
			anim_player = AnimationPlayer.new()
			anim_player.name = "AnimationPlayer"
			visuals.add_child(anim_player)
			print("PlayerAnims: Created new AnimationPlayer")
	
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var lib = anim_player.get_animation_library("")

	# Reset Visuals rotation (Try 180 degrees if ZERO was backward)
	if visuals:
		visuals.rotation.y = PI # Rotate 180 degrees
		
	if name_label:
		if NetworkManager and NetworkManager.current_player_data:
			var uname = NetworkManager.current_player_data.get("char_name", "Local Player")
			name_label.text = uname
		name_label.hide() # Standardmäßig aus, außer GM Flag ist an

	# Define where to find animations and how to map them
	# Key: Target Name (for AnimationTree), Value: { "file": path, "anim": source_name }
	var anim_mapping = {
		"Idle": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Idle_A", "loop": true},
		"Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Walking Backwards": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Left Strafe Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Right Strafe Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Jump": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Start", "loop": false}
	}

	for target_name in anim_mapping:
		var data = anim_mapping[target_name]
		var path = data.file
		var source_name = data.source

		if ResourceLoader.exists(path):
			var res = load(path)
			if res:
				var scene = res.instantiate()
				var source_player = scene.find_child("AnimationPlayer")
				if source_player and source_player.has_animation(source_name):
					var source_anim = source_player.get_animation(source_name)
					var anim = source_anim.duplicate()
					
					# DEBUG: Print original first track
					if anim.get_track_count() > 0:
						print("DEBUG [", target_name, "] Original Track 0: ", anim.track_get_path(0))
					
					# Retargeting: Dynamic Skeleton Path
					# 1. Find the actual Skeleton3D node in our Visuals
					var target_skeleton: Skeleton3D = null
					if visuals:
						target_skeleton = _find_skeleton_recursive(visuals)
					
					var target_skeleton_path = ""
					if target_skeleton and anim_player:
						target_skeleton_path = str(anim_player.get_path_to(target_skeleton))
					else:
						# Fallback if no skeleton found (unlikely for a character)
						print("PlayerAnims: WARNING - No Skeleton3D found in Visuals!")
						target_skeleton_path = "Skeleton3D" # Best guess
					

					if not skeleton_debug_printed and target_skeleton:
						print("DEBUG: Target Skeleton Bone List (First 10):")
						for b in range(min(10, target_skeleton.get_bone_count())):
							print(" - ", target_skeleton.get_bone_name(b))
						skeleton_debug_printed = true

					var track_count = anim.get_track_count()
					for i in range(track_count):
						var track_path = str(anim.track_get_path(i))
						var parts = track_path.split("/")
						var bone_name_in_track = parts[parts.size() - 1]
						
						# Check if it's an attribute track (:)
						if ":" in bone_name_in_track:
							# For 3D skeleton anims in Godot, path is NodePath:BoneName
							# But sometimes it's NodePath:Property (like blend shapes)
							# If we suspect it's a bone...
							pass
						
						# If the path actually used : to separate bone, the split might be tricky.
						# Standard path: "Skeleton3D:Hips" -> parts=["Skeleton3D:Hips"]? 
						# No, NodePath("A/B:C") splits by slash to A, B:C.
						
						# Let's handle the NodePath properly
						var np = anim.track_get_path(i)
						var subname = np.get_concatenated_subnames() # effectively the property or bone name
						
						# Optimization: Assuming the problem is Case Sensitivity or Prefix
						if target_skeleton:
							var final_bone_name = subname
							
							# 1. Try Exact Match
							if target_skeleton.find_bone(final_bone_name) == -1:
								# 2. Try Capitalized (hips -> Hips)
								var cap_name = final_bone_name.capitalize().replace(" ", "")
								# Capitalize often adds spaces "hip node" -> "Hip Node", we want PascalCase usually
								# Better: Try manually uppercase first letter
								var pascal = final_bone_name.substr(0,1).to_upper() + final_bone_name.substr(1)
								
								if target_skeleton.find_bone(pascal) != -1:
									final_bone_name = pascal
								# 3. Try Lowercase
								elif target_skeleton.find_bone(final_bone_name.to_lower()) != -1:
									final_bone_name = final_bone_name.to_lower()
								# 4. Try KeyKit/Mixamo patterns
								elif target_skeleton.find_bone("mixamorig:" + final_bone_name) != -1:
									final_bone_name = "mixamorig:" + final_bone_name
								elif target_skeleton.find_bone(final_bone_name.replace("mixamorig:", "")) != -1:
									final_bone_name = final_bone_name.replace("mixamorig:", "")
								
								# Apply correction if changed
								if final_bone_name != subname:
									# Reconstruct path using our mapped Skeleton Path
									var new_full_path = target_skeleton_path + ":" + final_bone_name
									anim.track_set_path(i, new_full_path)
									continue # Done for this track

						# Default fallback if no match or no skeleton
						anim.track_set_path(i, target_skeleton_path + ":" + subname)
							
					# DEBUG: Print new first track
					if anim.get_track_count() > 0:
						print("DEBUG [", target_name, "] Retargeted Track 0: ", anim.track_get_path(0))

					if data.loop:
						anim.loop_mode = Animation.LOOP_LINEAR
					else:
						anim.loop_mode = Animation.LOOP_NONE
						
					lib.add_animation(target_name, anim)
					print("PlayerAnims: Mapped ", source_name, " -> ", target_name)
				else:
					print("PlayerAnims: Source anim '", source_name, "' not found in ", path)
					if source_player:
						print(" - Available animations: ", source_player.get_animation_list())
				
				scene.queue_free()

			else:
				print("PlayerAnims: Failed to load ", path)


func _unhandled_input(event):
	# Handle Mouse Buttons for Pointer Lock and Selection
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_held = event.pressed
			if event.pressed:
				_pick_target()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_held = event.pressed
		
		# Update Mouse Mode: Only capture if we clicked in the world (unhandled)
		if is_left_mouse_held or is_right_mouse_held:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
		# Handle Zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			spring_arm.spring_length = clamp(spring_arm.spring_length - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			spring_arm.spring_length = clamp(spring_arm.spring_length + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		
		# First Person Check (Hide visuals if zoomed in)
		if visuals:
			visuals.visible = spring_arm.spring_length > 0.5
			
	# Handle Camera Rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rot_x = -event.relative.y * MOUSE_SENSITIVITY
		var rot_y = -event.relative.x * MOUSE_SENSITIVITY
		
		# Vertical rotation (on the SpringArm)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x + rot_x, -PI/2.1, PI/4)
		spring_arm.rotation.z = 0 # No sideways tilt
		
		if is_right_mouse_held:
			# Right click: Rotate character directly (Y)
			rotation.y += rot_y + spring_arm.rotation.y
			spring_arm.rotation.y = 0
		else:
			# Left click: Rotate only the camera around the character
			spring_arm.rotation.y += rot_y
		
		rotation.z = 0 # Character should never tilt

func _input(event):
	# Target cycling (Tab / LT)
	if event.is_action_pressed("target_cycle") and not get_viewport().gui_get_focus_owner():
		_cycle_targets()
		get_viewport().set_input_as_handled()
		
	# Frostblitz (Action cast_1)
	if event.is_action_pressed("cast_1"):
		if not get_viewport().gui_get_focus_owner():
			if not current_target:
				_cycle_targets() # Versuche ein Ziel zu finden
				
			if current_target:
				var mid = ""
				if "mob_id" in current_target:
					mid = current_target.mob_id
				if mid != "":
					if velocity.length() > 0.5:
						show_message("Du kannst das nicht während der Bewegung wirken!")
						return
					NetworkManager.cast_spell("Frostblitz", mid)
					get_viewport().set_input_as_handled()
				
	# Frost Nova (Action cast_2)
	if event.is_action_pressed("cast_2"):
		if not get_viewport().gui_get_focus_owner():
			NetworkManager.cast_spell("Frost Nova", "")
			get_viewport().set_input_as_handled()
			
	# Eisbarriere (Action cast_3)
	if event.is_action_pressed("cast_3"):
		if not get_viewport().gui_get_focus_owner():
			NetworkManager.cast_spell("Eisbarriere", "")
			get_viewport().set_input_as_handled()

func _pick_target():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 6 # Layer 2 (Player) + Layer 4 (Enemy)
	query.exclude = [get_rid()] # Don't hit ourselves
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		var target_hp = collider.get("hp") if "hp" in collider else 1 # Default 1 if no hp var
		if collider.is_in_group("targetable") and target_hp > 0:
			set_target(collider)
		else:
			set_target(null) # Deselect
	else:
		set_target(null)

func _cycle_targets():
	var targets = get_tree().get_nodes_in_group("targetable")
	
	# 1. Grundfilter: Nicht ich selbst und nur lebende Ziele
	targets = targets.filter(func(t): 
		var target_hp = t.get("hp") if "hp" in t else 1
		return t != self and target_hp > 0
	)
	
	if targets.size() == 0:
		set_target(null)
		return

	# 2. Sichtfeld-Filter (Ziele vor mir bevorzugen)
	var forward = -global_transform.basis.z # Richtung, in die der Spieler schaut
	var targets_in_front = targets.filter(func(t):
		var to_target = (t.global_position - global_position).normalized()
		var angle = forward.angle_to(to_target)
		return angle < deg_to_rad(45) # 90 Grad Kegel (45 Grad links/rechts)
	)
	
	# Wenn Ziele vor uns sind, nutzen wir nur diese
	if targets_in_front.size() > 0:
		targets = targets_in_front
	
	# 3. Sortierung nach Distanz
	targets.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	
	# 4. Durchwechseln
	if current_target == null or not targets.has(current_target):
		set_target(targets[0])
	else:
		var current_index = targets.find(current_target)
		var next_index = (current_index + 1) % targets.size()
		set_target(targets[next_index])

func set_target(new_target):
	# Wir aktualisieren die Variable nur bei Änderung für die UI
	if current_target != new_target:
		current_target = new_target
		target_changed.emit(current_target)
		print("Neues Ziel: ", current_target.name if current_target else "Keins")
	
	# ABER: Wir synchronisieren IMMER mit dem Server, wenn diese Funktion aufgerufen wird
	# (z.B. durch Klick), um sicherzustellen, dass der Server-State stimmt.
	var target_id = ""
	var target_name = "Keins"
	if current_target:
		if "mob_id" in current_target:
			target_id = current_target.mob_id
			target_name = current_target.name if "name" in current_target else "Monster"
		elif "username" in current_target:
			target_id = current_target.username
			target_name = target_id
	
	if NetworkManager:
		NetworkManager.send_target_update(target_id)
		# Optional: Debug-Text im lokalen Log
		print("Server-Ziel-Update gesendet: ", target_id)

var last_sent_pos = Vector3.ZERO
var last_sent_rot = Vector3.ZERO

func _physics_process(delta):
	# Aura permanent anzeigen wenn ein Schild aktiv ist
	if casting_aura:
		var has_shield_buff = false
		for b in buffs:
			if b.get("type") == "Eisbarriere":
				has_shield_buff = true
				break
				
		if shield > 0 or has_shield_buff:
			casting_aura.show()
		elif not is_casting:
			casting_aura.hide()
			
	# Auto-Deselect dead targets
	if is_instance_valid(current_target):
		var thp = current_target.get("hp") if "hp" in current_target else 1
		if thp <= 0:
			set_target(null)
			
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not get_viewport().gui_get_focus_owner():
		velocity.y = JUMP_VELOCITY
		if anim_tree:
			anim_tree.set("parameters/conditions/jump", true)
	else:
		if anim_tree:
			anim_tree.set("parameters/conditions/jump", false)

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Vector2.ZERO
	if not get_viewport().gui_get_focus_owner():
		# Vorwärts/Rückwärts
		input_dir.y = Input.get_axis("move_forward", "move_backward")
		
		# Seitwärts (Strafe) über Q/E oder A/D (wenn rechte Maus gedrückt)
		var strafe_input = Input.get_axis("strafe_left", "strafe_right")
		
		var ad_input = Input.get_axis("move_left", "move_right")
		
		if is_right_mouse_held:
			# Rechte Maus: A/D wird zu Strafe (zusätzlich zu Q/E)
			input_dir.x = clamp(strafe_input + ad_input, -1.0, 1.0)
		else:
			# Keine rechte Maus: A/D dreht den Charakter
			if ad_input != 0:
				rotation.y -= ad_input * delta * ROTATION_SPEED
			input_dir.x = strafe_input # Nur Q/E macht Strafe
		
		# --- Gamepad Kamera (Rechter Stick) ---
		var cam_input = Vector2(
			Input.get_axis("camera_left", "camera_right"),
			Input.get_axis("camera_up", "camera_down")
		)
		if cam_input.length() > 0.1:
			var cam_speed = 2.0 # Geschwindigkeit für Controller
			spring_arm.rotation.x = clamp(spring_arm.rotation.x - cam_input.y * delta * cam_speed, -PI/2.1, PI/4)
			rotation.y -= cam_input.x * delta * cam_speed
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		var current_speed = SPEED
		if input_dir.y > 0: # Rückwärts laufen
			current_speed *= 0.5
			
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2.0)
		velocity.z = move_toward(velocity.z, 0, SPEED * 2.0)

	# Animation Blending
	if anim_tree:
		anim_tree.set("parameters/conditions/is_on_floor", is_on_floor())
		# Blend values: x is strafe (-1 left, 1 right), y is forward/back (-1 fwd, 1 back)
		var blend_pos = Vector2(input_dir.x, input_dir.y)
		anim_tree.set("parameters/IWS/blend_position", blend_pos)

	move_and_slide()
	
	# Real-time update to server
	_check_and_send_update()
	_update_selection_circle()

func _update_selection_circle():
	if not selection_circle: return
	
	if current_target == null or not is_instance_valid(current_target):
		selection_circle.hide()
		return
		
	selection_circle.show()
	# Position am Boden unter dem Ziel
	selection_circle.global_position = current_target.global_position + Vector3(0, 0.05, 0)
	
	# Farbe anpassen
	var mat = selection_circle.get_surface_override_material(0)
	if mat:
		if current_target.is_in_group("mobs"):
			mat.set_shader_parameter("circle_color", Color(1, 0, 0, 1)) # Rot für Gegner
		else:
			mat.set_shader_parameter("circle_color", Color(0, 1, 1, 1)) # Türkis für Spieler/Neutrale

func _check_and_send_update():
	var is_moving_now = velocity.length() > 0.1
	var pos_changed = global_position.distance_to(last_sent_pos) > 0.05
	var rot_changed = abs(rotation.y - last_sent_rot.y) > 0.01
	
	# Sende Update wenn sich etwas geändert hat ODER wenn wir gerade angehalten haben
	if pos_changed or rot_changed or (was_moving_last_frame and not is_moving_now):
		if NetworkManager and NetworkManager.is_ws_connected():
			NetworkManager.send_player_update(global_position, rotation)
			last_sent_pos = global_position
			last_sent_rot = rotation
	
	was_moving_last_frame = is_moving_now

func show_message(text: String):
	if not chat_bubble: return
	
	chat_bubble.text = text
	chat_bubble.show()
	
	await get_tree().create_timer(5.0).timeout
	
	if chat_bubble.text == text:
		chat_bubble.hide()

func _exit_tree():
	if selection_circle:
		selection_circle.queue_free()

func _print_tree(node: Node, indent: String = ""):
	print(indent + node.name + " (" + node.get_class() + ")")
	for c in node.get_children():
		_print_tree(c, indent + "  ")

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var result = _find_skeleton_recursive(c)
		if result: return result
	return null
