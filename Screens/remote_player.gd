extends CharacterBody3D

@onready var visuals = $Visuals
@onready var anim_tree = $AnimationTree
@onready var name_label = $NameLabel
@onready var chat_bubble = %ChatBubble

var bubble_timer: SceneTreeTimer = null

var target_position = Vector3.ZERO
var target_rotation = Vector3.ZERO
var username = "Unknown"
var hp = 100
var max_hp = 100
var level = 1
var is_gm = false
var current_target: Node3D = null
var shield = 0
var is_casting = false
var buffs = []

var casting_aura_scene = preload("res://Assets/Effects/CastingAura.tscn")
var casting_aura = null

func _ready():
	add_to_group("remote_player")
	add_to_group("targetable")
	
	_setup_animations()
	
	if anim_tree:
		anim_tree.active = true
		
	casting_aura = casting_aura_scene.instantiate()
	add_child(casting_aura)
	casting_aura.hide()

func start_casting(spell_id: String):
	is_casting = true
	if casting_aura and spell_id != "Frostblitz": 
		casting_aura.show()

func stop_casting():
	is_casting = false
	if casting_aura: casting_aura.hide()
func setup(p_username: String, start_pos: Vector3, p_is_gm: bool = false):
	username = p_username
	global_position = start_pos
	target_position = start_pos
	self.is_gm = p_is_gm
	_update_name_label(p_is_gm)

func update_remote_data(pos: Vector3, rot: Vector3, p_is_gm: bool = false):
	target_position = pos
	target_rotation = rot
	self.is_gm = p_is_gm
	_update_name_label(p_is_gm)

func _update_name_label(is_gm: bool):
	if name_label:
		if is_gm:
			name_label.text = "<GM> " + username
			name_label.modulate = Color.YELLOW
		else:
			name_label.text = username
			name_label.modulate = Color.WHITE

func show_message(text: String):
	if not chat_bubble: return
	
	chat_bubble.text = text
	chat_bubble.show()
	
	# Vorherigen Timer ignorieren falls vorhanden (vereinfacht über neuen Timer)
	await get_tree().create_timer(5.0).timeout
	
	# Nur verstecken wenn der Text immer noch derselbe ist (keine neuere Nachricht)
	if chat_bubble.text == text:
		chat_bubble.hide()

func _physics_process(delta):
	# Interpolation für flüssige Bewegung
	global_position = global_position.lerp(target_position, delta * 15.0)
	rotation.y = lerp_angle(rotation.y, target_rotation.y, delta * 15.0)
	
	# Aura permanent anzeigen wenn ein Schild aktiv ist
	if casting_aura:
		if shield > 0:
			casting_aura.show()
		else:
			casting_aura.hide()
	
	# Sehr einfache Animation (Walking if moving)
	var move_dist = global_position.distance_to(target_position)
	if anim_tree:
		var blend_y = -1.0 if move_dist > 0.05 else 0.0
		anim_tree.set("parameters/IWS/blend_position", Vector2(0, blend_y))

func _setup_animations():
	var anim_player = find_child("AnimationPlayer", true)
	if not anim_player:
		if visuals:
			anim_player = visuals.find_child("AnimationPlayer", true)
			if not anim_player:
				anim_player = AnimationPlayer.new()
				anim_player.name = "AnimationPlayer"
				visuals.add_child(anim_player)
	
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var lib = anim_player.get_animation_library("")

	if visuals:
		visuals.rotation.y = PI

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
					
					# Retargeting: Dynamic Skeleton Path
					var target_skeleton: Skeleton3D = null
					if visuals:
						target_skeleton = _find_skeleton_recursive(visuals)
					
					var target_skeleton_path = "Skeleton3D"
					if target_skeleton and anim_player:
						target_skeleton_path = str(anim_player.get_path_to(target_skeleton))
					
					var track_count = anim.get_track_count()
					for i in range(track_count):
						var np = anim.track_get_path(i)
						var subname = np.get_concatenated_subnames()
						
						if target_skeleton:
							var final_bone_name = subname
							if target_skeleton.find_bone(final_bone_name) == -1:
								var pascal = final_bone_name.substr(0,1).to_upper() + final_bone_name.substr(1)
								if target_skeleton.find_bone(pascal) != -1:
									final_bone_name = pascal
								elif target_skeleton.find_bone(final_bone_name.to_lower()) != -1:
									final_bone_name = final_bone_name.to_lower()
								
								if final_bone_name != subname:
									var new_full_path = target_skeleton_path + ":" + final_bone_name
									anim.track_set_path(i, new_full_path)
									continue
									
						anim.track_set_path(i, target_skeleton_path + ":" + subname)
					
					if data.loop:
						anim.loop_mode = Animation.LOOP_LINEAR
					else:
						anim.loop_mode = Animation.LOOP_NONE
						
					lib.add_animation(target_name, anim)
				scene.queue_free()

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var result = _find_skeleton_recursive(c)
		if result: return result
	return null


