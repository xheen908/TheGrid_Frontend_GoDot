extends CharacterBody3D

@onready var visuals = $Visuals
@onready var anim_tree = $AnimationTree
@onready var name_label = $NameLabel
@onready var chat_bubble = %ChatBubble

var bubble_timer: SceneTreeTimer = null

var target_position = Vector3.ZERO
var target_rotation = Vector3.ZERO
var username = "Unknown"
var char_name = ""
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

var models = {
	"Barbarian": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Barbarian.fbx"),
	"Knight": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx"),
	"Mage": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Mage.fbx"),
	"Ranger": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Ranger.fbx"),
	"Rogue": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Rogue.fbx")
}
var character_class = "Mage"

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
	if anim_tree:
		anim_tree.set("parameters/conditions/is_casting", true)
		anim_tree.set("parameters/conditions/not_casting", false)
	if casting_aura and spell_id != "Frostblitz": 
		casting_aura.show()

func stop_casting():
	is_casting = false
	if anim_tree:
		anim_tree.set("parameters/conditions/is_casting", false)
		anim_tree.set("parameters/conditions/not_casting", true)
	if casting_aura: casting_aura.hide()

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
func setup(p_username: String, p_char_name: String, start_pos: Vector3, p_is_gm: bool = false):
	username = p_username
	char_name = p_char_name
	global_position = start_pos
	target_position = start_pos
	self.is_gm = p_is_gm
	_update_name_label(p_is_gm)

func update_remote_data(pos: Vector3, rot: Vector3, p_is_gm: bool = false):
	target_position = pos
	target_rotation = rot
	if self.is_gm != p_is_gm:
		self.is_gm = p_is_gm
		_update_name_label(p_is_gm)

func _update_name_label(is_gm: bool):
	if name_label:
		var display_name = char_name if char_name != "" else username
		if is_gm:
			name_label.text = "<GM> " + display_name
			name_label.modulate = Color.YELLOW
		else:
			name_label.text = display_name
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
		var has_shield_buff = false
		for b in buffs:
			if b.get("type") == "Eisbarriere":
				has_shield_buff = true
				break
				
		if shield > 0 or has_shield_buff:
			casting_aura.show()
		else:
			casting_aura.hide()
	
	# Sehr einfache Animation (Walking if moving)
	var move_dist = global_position.distance_to(target_position)
	if anim_tree:
		var blend_y = -1.0 if move_dist > 0.05 else 0.0
		anim_tree.set("parameters/IWS/blend_position", Vector2(0, blend_y))
		
		# Falls nicht gecastet wird, sicherstellen dass wir in IWS sind
		if not is_casting:
			anim_tree.set("parameters/conditions/is_casting", false)
			anim_tree.set("parameters/conditions/not_casting", true)

func _setup_animations():
	var anim_player = null
	if visuals:
		anim_player = visuals.find_child("AnimationPlayer", true)
	
	if not anim_player:
		if visuals:
			anim_player = AnimationPlayer.new()
			anim_player.name = "AnimationPlayer"
			visuals.add_child(anim_player)
			print("RemotePlayerAnims: Created new AnimationPlayer")
	
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
		"Jump": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Start", "loop": false},
		"Casting": {"file": "res://Assets/models/KayKit_Adventurers_2.0_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Attack_Staff", "loop": true}
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
					
					if real_source_name != "":
						var source_anim = source_player.get_animation(real_source_name)
						var anim = source_anim.duplicate()
						
						var target_skeleton: Skeleton3D = _find_skeleton_recursive(visuals) if visuals else null
						var target_skeleton_path = str(anim_player.get_path_to(target_skeleton)) if target_skeleton else "Skeleton3D"
						
						for i in range(anim.get_track_count()):
							var np = anim.track_get_path(i)
							var bone_name = np.get_concatenated_subnames()
							
							if target_skeleton:
								var final_bone = bone_name
								if target_skeleton.find_bone(final_bone) == -1:
									var pascal = final_bone.substr(0,1).to_upper() + final_bone.substr(1)
									if target_skeleton.find_bone(pascal) != -1: final_bone = pascal
									elif target_skeleton.find_bone(final_bone.to_lower()) != -1: final_bone = final_bone.to_lower()
									elif target_skeleton.find_bone("mixamorig:" + final_bone) != -1: final_bone = "mixamorig:" + final_bone
								
								anim.track_set_path(i, target_skeleton_path + ":" + final_bone)
							else:
								anim.track_set_path(i, target_skeleton_path + ":" + bone_name)
						
						anim.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
						lib.add_animation(target_name, anim)
					else:
						print("RemotePlayerAnims: Source anim '", data.source, "' not found in ", data.file)
				scene.queue_free()

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var result = _find_skeleton_recursive(c)
		if result: return result
	return null


