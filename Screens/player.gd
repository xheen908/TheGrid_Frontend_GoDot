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
var anim_player_ref: AnimationPlayer = null

signal target_changed(new_target: Node3D)
var username = ""
var char_name = ""
var level = 1
var is_gm_flagged = false
var current_target: Node3D = null
var hp = 100
var max_hp = 100
var shield = 0
var buffs = []
var is_casting = false
var gravity_enabled = true
var speed_multiplier = 1.0

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
		anim_tree.active = false
		anim_tree.active = true
		print("Player: AnimationTree initial refresh")
		
	# Selection Circle initialisieren
	selection_circle = selection_circle_scene.instantiate()
	get_tree().root.add_child.call_deferred(selection_circle)
	selection_circle.hide()
	
	# Casting Aura initialisieren
	casting_aura = casting_aura_scene.instantiate()
	add_child(casting_aura)
	casting_aura.hide()

func update_gm_status(is_gm: bool):
	var uname = NetworkManager.current_player_data.get("char_name", "Local Player") if NetworkManager and NetworkManager.current_player_data else "Local Player"
	# TECHNICAL username stays as is (e.g. from NetworkManager data)
	# We only change the visual representation
	is_gm_flagged = is_gm
	
	if name_label:
		if is_gm:
			name_label.text = "<GM> " + uname
			name_label.modulate = Color.YELLOW
			name_label.show()
		else:
			name_label.text = uname
			name_label.hide()

func start_casting(spell_id: String, duration: float = 0.0):
	if is_casting: return # Verhindert Mehrfach-Triggern
	is_casting = true
	
	if anim_tree:
		# Spezielle Animation für Frostblitz
		var state_machine = anim_tree.tree_root as AnimationNodeStateMachine
		if state_machine:
			var casting_node = state_machine.get_node("Casting") as AnimationNodeAnimation
			if casting_node:
				var target_anim = "Frostblitz_Casting" if spell_id == "Frostblitz" else "Casting"
				casting_node.animation = target_anim
				
				# Animation-Speed exakt an die Cast-Dauer anpassen für perfekten Sync
				if anim_player_ref and anim_player_ref.has_animation(target_anim) and duration > 0:
					var anim_len = anim_player_ref.get_animation(target_anim).length
					anim_player_ref.speed_scale = anim_len / duration
					print("PlayerAnims: Sync speed: ", anim_player_ref.speed_scale, " for duration: ", duration)
		
		anim_tree.set("parameters/conditions/is_casting", true)
		anim_tree.set("parameters/conditions/not_casting", false)
		var playback = anim_tree.get("parameters/playback")
		if playback:
			playback.travel("Casting")
		print("PlayerAnims: Conditions set and travel() called to Casting")
	
	if casting_aura and spell_id != "Frostblitz":
		casting_aura.show()

func stop_casting():
	is_casting = false
	if anim_tree:
		anim_tree.set("parameters/conditions/is_casting", false)
		anim_tree.set("parameters/conditions/not_casting", true)
		var playback = anim_tree.get("parameters/playback")
		if playback:
			playback.travel("IWS")
		
		# Speed zurücksetzen
		if anim_player_ref:
			anim_player_ref.speed_scale = 1.0
			
		print("PlayerAnims: Conditions reset and travel() called to IWS")
		
	if casting_aura:
		if shield <= 0:
			casting_aura.hide()

func initialise_class(new_class: String):
	if new_class == "": new_class = "Mage"
	if character_class == new_class and visuals: return
	
	print("Player: Changing class to ", new_class)
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
					anim_tree.anim_player = anim_tree.get_path_to(new_anim_player)
					anim_tree.active = false
					anim_tree.active = true
					print("PlayerAnims: AnimationTree re-linked to ", anim_tree.anim_player)

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
	
	anim_player_ref = anim_player
	
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var lib = anim_player.get_animation_library("")
	print("PlayerAnims: Library found/created. Anim count: ", lib.get_animation_list().size())

	# AnimationTree Verbindung erneuern
	if anim_tree:
		anim_tree.anim_player = anim_tree.get_path_to(anim_player)
		anim_tree.active = true
		anim_tree.set("parameters/IWS/blend_position", Vector2.ZERO)
		print("PlayerAnims: AnimationTree linked to: ", anim_tree.anim_player)

	if visuals:
		visuals.rotation.y = PI # Rotate 180 degrees
		
	if name_label:
		if NetworkManager and NetworkManager.current_player_data:
			var uname = NetworkManager.current_player_data.get("char_name", "Local Player")
			name_label.text = uname
		name_label.hide() # Standardmäßig aus, außer GM Flag ist an

	# Define where to find animations and how to map them
	var anim_mapping = {
		"Idle": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Idle_A", "loop": true},
		"Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Walking Backwards": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_B", "loop": true},
		"Left Strafe Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_C", "loop": true},
		"Right Strafe Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_C", "loop": true},
		"Jump": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Start", "loop": false},
		"Casting": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Attack", "loop": true},
		"Frostblitz_Casting": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_CombatRanged.fbx", "source": "Ranged_Magic_Spellcasting_Long", "loop": true}
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
				if source_player:
					# Find animation - if specific source not found, fallback to Walking_A
					var real_source_name = ""
					var available_anims = source_player.get_animation_list()
					
					for a_name in available_anims:
						if a_name.ends_with(source_name) or a_name.ends_with("/" + source_name):
							real_source_name = a_name
							break
					
					# Fallback logic
					if real_source_name == "":
						for a_name in available_anims:
							if a_name.ends_with("Walking_A"): # Best generic fallback
								real_source_name = a_name
								break
					
					if real_source_name != "":
						var source_anim = source_player.get_animation(real_source_name)
						var anim = source_anim.duplicate()
						
						# Retargeting logic: Wir setzen den Root des Players auf den Parent (Modell-Root)
						# Das ist Godot-Standard für FBX.
						anim_player.root_node = NodePath("..")
						var anim_root = anim_player.get_node(anim_player.root_node)
						var target_skeleton: Skeleton3D = _find_skeleton_recursive(visuals) if visuals else null
						var target_skeleton_path = str(anim_root.get_path_to(target_skeleton)) if target_skeleton and anim_root else "Skeleton3D"
						
						var matched_tracks = 0
						for i in range(anim.get_track_count()):
							var np = anim.track_get_path(i)
							var bone_name = np.get_concatenated_subnames()
							
							if target_skeleton:
								var final_bone = bone_name
								if target_skeleton.find_bone(final_bone) == -1:
									# Intelligentes Matching (wie bei Enemy)
									var parts = final_bone.split("_")
									var base_bone = parts[-1]
									
									var found = false
									for b_idx in target_skeleton.get_bone_count():
										var t_name = target_skeleton.get_bone_name(b_idx)
										if t_name == base_bone or t_name.ends_with("_" + base_bone) or t_name.ends_with(":" + base_bone):
											final_bone = t_name
											found = true
											break
									
									if not found:
										var pascal = final_bone.substr(0,1).to_upper() + final_bone.substr(1)
										if target_skeleton.find_bone(pascal) != -1: final_bone = pascal
										elif target_skeleton.find_bone(final_bone.to_lower()) != -1: final_bone = final_bone.to_lower()
										elif target_skeleton.find_bone("mixamorig:" + final_bone) != -1: final_bone = "mixamorig:" + final_bone
								
								if target_skeleton.find_bone(final_bone) != -1:
									matched_tracks += 1
								anim.track_set_path(i, target_skeleton_path + ":" + final_bone)
							else:
								anim.track_set_path(i, target_skeleton_path + ":" + bone_name)
						
						anim.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
						lib.add_animation(target_name, anim)
						print("PlayerAnims: Mapped ", real_source_name, " -> ", target_name, " (", matched_tracks, "/", anim.get_track_count(), " bones matched)")
					else:
						print("PlayerAnims: Source anim '", source_name, "' not found in ", path)
				
				scene.queue_free()
	
	# Am Ende: AnimationTree hart triggern
	if anim_tree and anim_player:
		anim_tree.anim_player = anim_tree.get_path_to(anim_player)
		anim_tree.active = true
		var playback = anim_tree.get("parameters/playback")
		if playback:
			playback.start("IWS")
			anim_tree.set("parameters/conditions/is_casting", false)
			anim_tree.set("parameters/conditions/not_casting", true)
			print("PlayerAnims: StateMachine started at IWS, conditions reset")


func _unhandled_input(event):
	# Handle Mouse Buttons for Pointer Lock and Selection
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_held = event.pressed
			if event.pressed:
				_pick_target()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_mouse_held = event.pressed
		
		# Update Mouse Mode: Capture if either button is held
		var target_mode = Input.MOUSE_MODE_CAPTURED if (is_right_mouse_held or is_left_mouse_held) else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != target_mode:
			Input.mouse_mode = target_mode
			
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
			# Right click: Rotate character directly (Steering)
			rotation.y += rot_y + spring_arm.rotation.y
			spring_arm.rotation.y = 0
		elif is_left_mouse_held:
			# Left click: Rotate only the camera around the character (Orbiting)
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
			# Falls kein Ziel da ist, versuche eins zu finden
			if not current_target:
				_cycle_targets()
				
			if current_target:
				var target_id = ""
				if "mob_id" in current_target:
					target_id = current_target.mob_id
				elif "username" in current_target:
					target_id = current_target.username
				
				if target_id != "":
					if velocity.length() > 0.5:
						show_message("Du kannst das nicht während der Bewegung wirken!")
						return
					
					print("Player: Casting Frostblitz on ", target_id)
					NetworkManager.cast_spell("Frostblitz", target_id)
					get_viewport().set_input_as_handled()
				else:
					print("Player: Target has no ID (mob_id/username)")
					show_message("Ungültiges Ziel!")
			else:
				print("Player: No target for Frostblitz")
				show_message("Kein Ziel ausgewählt!")
				
	# Frost Nova (Action cast_2)
	if event.is_action_pressed("cast_2"):
		if not get_viewport().gui_get_focus_owner():
			NetworkManager.cast_spell("Frost Nova", "")
			get_viewport().set_input_as_handled()
			
	# Kältekegel (Action cast_3)
	if event.is_action_pressed("cast_3"):
		if not get_viewport().gui_get_focus_owner():
			print("Player: Casting Kältekegel")
			NetworkManager.cast_spell("Kältekegel", "")
			get_viewport().set_input_as_handled()
			
	# Eisbarriere (Action cast_4)
	if event.is_action_pressed("cast_4"):
		if not get_viewport().gui_get_focus_owner():
			NetworkManager.cast_spell("Eisbarriere", "")
			get_viewport().set_input_as_handled()

func _pick_target():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	print("[RAY] Starting pick_target from camera: ", mouse_pos)
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 6 # Layer 2 (Player) + Layer 4 (Enemy)
	query.exclude = [get_rid()] # Don't hit ourselves
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		print("[RAY] Hit collider: ", collider.name, " Groups: ", collider.get_groups())
		var target_hp = collider.get("hp") if "hp" in collider else 1 # Default 1 if no hp var
		if collider.is_in_group("targetable") and target_hp > 0:
			print("[RAY] Targeting valid: ", collider.name)
			set_target(collider)
		else:
			print("[RAY] Hit but not targetable or dead.")
			set_target(null) # Deselect
	else:
		print("[RAY] No hit.")
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
		# print("Neues Ziel: ", current_target.name if current_target else "Keins")
	
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
		print("[UI] Sending target update to server: ", target_id)
		NetworkManager.send_target_update(target_id)

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
	if gravity_enabled:
		if not is_on_floor():
			velocity.y -= gravity * delta
	else:
		# In zero gravity, velocity.y decays less or we handle it via input
		velocity.y = move_toward(velocity.y, 0, delta * 5.0)

	# Handle jump / fly up.
	if Input.is_action_pressed("jump") and not get_viewport().gui_get_focus_owner():
		if gravity_enabled:
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				if anim_tree:
					anim_tree.set("parameters/conditions/jump", true)
		else:
			# Flying up
			velocity.y = JUMP_VELOCITY
	
	if gravity_enabled and anim_tree:
		if not Input.is_action_pressed("jump"):
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
		var current_speed = SPEED * speed_multiplier
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
