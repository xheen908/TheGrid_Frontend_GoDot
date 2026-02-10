extends CharacterBody3D

@onready var visuals = $Visuals
@onready var name_label = $NameLabel
@onready var quest_indicator = %QuestIndicator

var quest_id = ""
var game_object_id = 0
var mob_idValue = "" # Using mob_idValue to avoid conflict if any
var npc_name = ""
var model_name = "Knight"

var indicator_time = 0.0

# Movement & Interpolation
var target_position = Vector3.ZERO
var target_rotation = 0.0
var hp = 100
var is_moving = false
var move_start_pos = Vector3.ZERO
var move_target_pos = Vector3.ZERO
var move_speed = 0.0
var move_start_time = 0.0
var _anim_frame_counter = 0

var models = {
	"Barbarian": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Barbarian.fbx"),
	"Knight": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx"),
	"Mage": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Mage.fbx"),
	"Ranger": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Ranger.fbx"),
	"Rogue": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Rogue.fbx")
}

func setup(data: Dictionary):
	mob_idValue = str(data.get("id", ""))
	game_object_id = int(data.get("id", 0))
	npc_name = data.get("name", "Questgeber")
	quest_id = data.get("quest_id", data.get("extra_data", {}).get("quest_id", ""))
	model_name = data.get("model", data.get("model_id", "Knight"))
	
	name_label.text = npc_name + "\n[Questgeber]"
	name_label.modulate = Color(1, 1, 0) # Gelb für Quests
	
	_update_model()
	_setup_animations()
	update_data(data)
	
	var trans = data.get("transform", {})
	global_position = Vector3(trans.get("x", 0.0), trans.get("y", global_position.y), trans.get("z", 0.0))
	rotation.y = trans.get("rot", 0.0) + PI
	target_position = global_position
	target_rotation = trans.get("rot", 0.0)

func setup_dynamic(data: Dictionary):
	setup(data)

func update_data(data: Dictionary):
	hp = data.get("hp", 100)
	var new_name = data.get("name", npc_name)
	if new_name != "": npc_name = new_name
	
	name_label.text = npc_name + "\n[Questgeber]"
	
	var new_model = data.get("model", data.get("model_id", ""))
	if new_model != "" and new_model != model_name:
		model_name = new_model
		_update_model()
	
	var trans = data.get("transform", {})
	var sync_pos = Vector3(trans.get("x", 0.0), trans.get("y", 0.0), trans.get("z", 0.0))
	target_position = sync_pos
	
	if not is_moving:
		var xz_diff = Vector2(global_position.x - sync_pos.x, global_position.z - sync_pos.z).length()
		if xz_diff > 0.5:
			global_position.x = sync_pos.x
			global_position.z = sync_pos.z
	
	target_rotation = trans.get("rot", 0.0)
	update_indicator()

func on_mob_move(data: Dictionary):
	var from = data.get("from", {})
	var to = data.get("to", {})
	
	move_start_pos = Vector3(from.get("x", global_position.x), global_position.y, from.get("z", global_position.z))
	move_target_pos = Vector3(to.get("x", global_position.x), global_position.y, to.get("z", global_position.z))
	move_speed = data.get("speed", 2.5)
	move_start_time = Time.get_ticks_msec() / 1000.0
	is_moving = true
	target_rotation = data.get("rot", 0.0)

func on_mob_stop(data: Dictionary):
	var pos = data.get("pos", {})
	is_moving = false
	move_speed = 0.0
	global_position.x = pos.get("x", global_position.x)
	global_position.z = pos.get("z", global_position.z)
	target_position = global_position
	add_to_group("targetable")
	add_to_group("quest_giver")
	
	if NetworkManager:
		NetworkManager.quest_sync_received.connect(func(_q): update_indicator())
		NetworkManager.quest_accepted.connect(func(_d): update_indicator())
		NetworkManager.quest_completed.connect(func(_q): update_indicator())
		NetworkManager.quest_rewarded.connect(func(_q): update_indicator())
		NetworkManager.quest_progress_updated.connect(func(_qid, _prog): update_indicator())
	
	update_indicator()
	
	# Set blend position to Idle
	# Set blend position to Idle
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

var _debug_timer = 0.0

func _process(delta):
	_debug_timer += delta
	if _debug_timer > 1.0:
		_debug_timer = 0.0
		var v = visuals.get_child(0) if visuals.get_child_count() > 0 else null
		if v:
			print("QuestGiver Debug: Name=", npc_name, " Pos=", global_position, " VisualsChild=", v.name, " Vis=", v.visible, " Scale=", v.scale)
			var skel = _find_skeleton_recursive(v)
			print("  Skeleton found: ", skel, " Path: ", get_path_to(skel) if skel else "N/A")
		else:
			print("QuestGiver Debug: NO VISUALS CHILD FOUND! Model Name: ", model_name)

	if quest_indicator and quest_indicator.visible:
		indicator_time += delta
		# Leichtes Schweben und Pulsieren (Premium Feeling)
		quest_indicator.position.y = 3.5 + sin(indicator_time * 3.0) * 0.2
		var s = 1.0 + sin(indicator_time * 5.0) * 0.05
		quest_indicator.scale = Vector3(s, s, s)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	if hp > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		var computed_target = global_position
		
		# 1. Spline Movement Interpolation
		if is_moving and move_speed > 0:
			var elapsed = current_time - move_start_time
			var total_distance = move_start_pos.distance_to(move_target_pos)
			var travel_time = total_distance / move_speed if move_speed > 0 else 0.0
			
			if elapsed >= travel_time:
				computed_target = move_target_pos
				is_moving = false
			else:
				var t = elapsed / travel_time if travel_time > 0 else 1.0
				computed_target = move_start_pos.lerp(move_target_pos, t)
		else:
			computed_target = target_position
		
		# 2. Apply movement
		var diff = computed_target - global_position
		diff.y = 0
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
			
		if diff.length_squared() > 0.005:
			var move_dir = diff.normalized()
			var speed = move_speed if is_moving else 2.5
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
			
			# Rotation follows movement
			rotation.y = lerp_angle(rotation.y, target_rotation + PI, delta * 10.0)
			
			# Animation
			if anim_player and anim_player.has_animation("Walking"):
				if anim_player.current_animation != "Walking":
					anim_player.play("Walking", 0.5)
		else:
			velocity.x = 0
			velocity.z = 0
			rotation.y = lerp_angle(rotation.y, target_rotation + PI, delta * 5.0)
			
			if anim_player and anim_player.has_animation("Idle"):
				if anim_player.current_animation != "Idle":
					anim_player.play("Idle", 0.5)
		
		move_and_slide()

func update_indicator():
	if quest_indicator and quest_indicator.has_method("set_billboard_mode"):
		quest_indicator.set_billboard_mode(1) # Billboard Mode: Enabled
		
	if quest_id == "" or not is_inside_tree(): 
		if quest_indicator: quest_indicator.hide()
		return
	
	var status = "available"
	var has_quest = false
	var quest_data = {}
	
	# Hole Quest-Liste aus dem NetworkManager
	if NetworkManager.current_player_data and NetworkManager.current_player_data.has("quests"):
		for q in NetworkManager.current_player_data["quests"]:
			if str(q.get("quest_id", "")) == str(quest_id):
				status = q.get("status", "active")
				quest_data = q
				has_quest = true
				break
	
	# Fallback: Wenn Quest aktiv ist, aber laut Progress schon "fertig" aussieht
	if status == "active" and quest_data.has("progress") and quest_data.has("objectives"):
		var all_done = true
		var objectives = quest_data.get("objectives", {})
		var progress = quest_data.get("progress", {})
		for obj_id in objectives.keys():
			if progress.get(obj_id, 0) < objectives[obj_id]:
				all_done = false
				break
		if all_done and objectives.size() > 0:
			status = "completed"
	
	print("[NPC] ", npc_name, " check (", quest_id, ") -> Final Status: ", status)
			
	match status:
		"available":
			quest_indicator.text = "!"
			quest_indicator.modulate = Color(1, 1, 0) # Gelb
			quest_indicator.show()
		"completed":
			quest_indicator.text = "?"
			quest_indicator.modulate = Color(1, 1, 0) # Gelb
			quest_indicator.show()
		_:
			quest_indicator.hide()

func _update_model():
	# Entferne altes Modell falls vorhanden
	for child in visuals.get_children():
		visuals.remove_child(child)
		child.queue_free()
		
	var model_key = model_name
	if not models.has(model_key):
		# Case-insensitive check
		for key in models.keys():
			if key.to_lower() == model_name.to_lower():
				model_key = key
				break
				
	var scene
	if models.has(model_key):
		scene = models[model_key].instantiate()
		visuals.add_child(scene)
		scene.rotation.y = PI
	else:
		scene = models["Knight"].instantiate()
		visuals.add_child(scene)
		scene.rotation.y = PI
	
	_setup_animations()

var anim_tree: AnimationTree = null
var anim_player: AnimationPlayer = null

func _setup_animations():
	# Ensure AnimationPlayer exists
	anim_player = visuals.find_child("AnimationPlayer", true)
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		visuals.add_child(anim_player)
	
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var lib = anim_player.get_animation_library("")

	# Logic adapted from Enemy.gd
	var target_skeleton: Skeleton3D = _find_skeleton_recursive(visuals)
	
	# WICHTIG: Setze root_node auf den AnimationPlayer selbst (.)
	anim_player.root_node = "." 
	var target_skeleton_path = str(anim_player.get_path_to(target_skeleton)) if target_skeleton else "Skeleton3D"

	var anim_mapping = {
		"Idle": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx", "source": "Idle", "loop": true}, # Fallback/Primary
		"Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx", "source": "Walking", "loop": true}, # Fallback/Primary
	}
	
	# Update Anim Mapping based on kaykit structure (separate files usually)
	# But here we use loop to find from mapping
	anim_mapping = {
		"Idle": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Idle_A", "loop": true},
		"Walking": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
	}


	for target_name in anim_mapping:
		var data = anim_mapping[target_name]
		if ResourceLoader.exists(data.file):
			var res = load(data.file)
			if res:
				var scene = res.instantiate()
				var source_player = scene.find_child("AnimationPlayer")
				if source_player:
					var real_source_name = ""
					for a_name in source_player.get_animation_list():
						if a_name.ends_with(data.source) or a_name.ends_with("/" + data.source):
							real_source_name = a_name
							break
					
					if real_source_name == "":
						for a_name in source_player.get_animation_list():
							if a_name.ends_with("Walking_A") and target_name == "Walking": 
								real_source_name = a_name
								break
					
					if real_source_name != "":
						var source_anim = source_player.get_animation(real_source_name)
						var anim = source_anim.duplicate()
						
						for i in range(anim.get_track_count()):
							var np = anim.track_get_path(i)
							var bone_name = np.get_concatenated_subnames()
							
							if target_skeleton:
								var final_bone = bone_name
								if target_skeleton.find_bone(final_bone) == -1:
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
								
								anim.track_set_path(i, target_skeleton_path + ":" + final_bone)
							else:
								anim.track_set_path(i, target_skeleton_path + ":" + bone_name)
						
						anim.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
						lib.add_animation(target_name, anim)
				scene.queue_free()

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var res = _find_skeleton_recursive(c)
		if res: return res
		
	# Fallback: Check if node itself is a Skeleton3D (sometimes imported as root) or Child of it
	if node.get_class() == "Skeleton3D": return node
	
	return null
