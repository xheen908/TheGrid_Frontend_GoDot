extends CharacterBody3D

@onready var name_label = $NameLabel

var mob_id = ""
var target_position = Vector3.ZERO
var target_rotation = 0.0
var hp = 100
var max_hp = 100
var level = 1
var is_frozen = false
var is_chilled = false
var debuffs = []
var target_name = null # Name vom Server
var char_name = ""
var model_id = ""

var model_configs = {
	"neon_cube": {"type": "geo", "shape": "cube", "color": Color(0, 1, 0)},
	"neon_cone": {"type": "geo", "shape": "cone", "color": Color(1, 0, 1)},
	"neon_pyramid": {"type": "geo", "shape": "pyramid", "color": Color(1, 0.5, 0)},
	"neon_sphere": {"type": "geo", "shape": "sphere", "color": Color(1, 1, 0)},
	"neon_torus": {"type": "geo", "shape": "torus", "color": Color(0, 0.5, 1)},
	"neon_capsule": {"type": "geo", "shape": "capsule", "color": Color(0.5, 1, 0.5)},
	"skeleton_mage": {"type": "fbx", "path": "res://Assets/models/KayKit_Skeletons_1.1_FREE/characters/fbx/Skeleton_Mage.fbx"},
	"skeleton_minion": {"type": "fbx", "path": "res://Assets/models/KayKit_Skeletons_1.1_FREE/characters/fbx/Skeleton_Minion.fbx"},
	"skeleton_rogue": {"type": "fbx", "path": "res://Assets/models/KayKit_Skeletons_1.1_FREE/characters/fbx/Skeleton_Rogue.fbx"},
	"skeleton_warrior": {"type": "fbx", "path": "res://Assets/models/KayKit_Skeletons_1.1_FREE/characters/fbx/Skeleton_Warrior.fbx"},
}

var casting_aura_scene = preload("res://Assets/Effects/CastingAura.tscn")
var casting_aura = null
static var neon_shader = preload("res://Assets/Shaders/neon_wireframe.gdshader")

var is_geometric = false
var current_geo_name = ""
var geo_mesh_instance: Node3D = null
var floating_time = 0.0
var geo_base_color = Color(0, 1, 1)

var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null

func _ready():
	add_to_group("mobs")
	add_to_group("targetable")
	
	casting_aura = casting_aura_scene.instantiate()
	add_child(casting_aura)
	casting_aura.hide()

func setup(data: Dictionary):
	mob_id = data.id
	_update_model(data.get("model_id", ""))
	update_data(data)
	global_position = target_position
	rotation.y = target_rotation + PI

func update_data(data: Dictionary):
	hp = data.get("hp", 100)
	max_hp = data.get("maxHp", 100)
	level = data.get("level", 1)
	var new_name = data.get("name", "Unbekannt")
	if new_name == "": new_name = "Unbekannt"
	char_name = new_name
	
	name_label.text = "[L" + str(level) + "] " + new_name
	
	if data.has("model_id") and data.model_id != model_id:
		_update_model(data.model_id)
	
	var trans = data.transform
	target_position = Vector3(trans.x, trans.y, trans.z)
	target_rotation = trans.get("rot", 0.0)
	target_name = data.get("target_name")
	
	# Debuffs prüfen
	var old_frozen = is_frozen
	var old_chilled = is_chilled
	debuffs = data.get("debuffs", [])
	is_frozen = false
	is_chilled = false
	for d in debuffs:
		if d.type == "Frozen": is_frozen = true
		if d.type == "Chill": is_chilled = true
			
	if is_frozen != old_frozen or is_chilled != old_chilled:
		_update_visuals()
	
	if hp <= 0:
		if visible and (not $CollisionShape3D.disabled or (geo_mesh_instance and is_geometric)):
			_die()
	else:
		if not visible or $CollisionShape3D.disabled:
			_respawn()

func _update_visuals():
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if not mesh or not mesh is MeshInstance3D: return
	var mat = mesh.material_override
	if not mat: return
	
	if is_frozen:
		if is_geometric:
			mat.set_shader_parameter("line_color", Color(0.5, 0.5, 1.0))
			mat.set_shader_parameter("glow_intensity", 8.0)
		else:
			mat.albedo_color = Color(0.3, 0.9, 1.0)
			mat.emission = Color(0.3, 0.9, 1.0)
			mat.emission_energy_multiplier = 4.0
	else:
		# Normal (Chill Effekt visuell entfernt)
		if is_geometric:
			mat.set_shader_parameter("line_color", geo_base_color)
			if hp > 0: # Nur wenn lebend leuchten
				mat.set_shader_parameter("glow_intensity", 4.0)
		else:
			mat.albedo_color = Color(1.0, 0, 0)
			mat.emission = Color(1.0, 0, 0)
			mat.emission_energy_multiplier = 2.0

func _update_model(p_model_id: String):
	if p_model_id == model_id: return
	model_id = p_model_id
	
	# Cleanup old custom meshes or FBX models
	if geo_mesh_instance:
		geo_mesh_instance.queue_free()
		geo_mesh_instance = null
	
	# Hide original mesh by default if we have a config
	if has_node("MeshInstance3D"):
		$MeshInstance3D.show() # Reset visibility
		
	if not model_configs.has(model_id):
		is_geometric = false
		return
		
	var cfg = model_configs[model_id]
	if cfg.type == "geo":
		_setup_geo_model(cfg)
	elif cfg.type == "fbx":
		_setup_fbx_model(cfg)

func _setup_geo_model(cfg: Dictionary):
	var mesh: Mesh = null
	var color = cfg.color
	
	match cfg.shape:
		"cube": mesh = BoxMesh.new()
		"cone": 
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.0
		"pyramid":
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 1.0
			mesh.height = 1.27
			mesh.radial_segments = 4
			mesh.rings = 1
		"sphere": mesh = SphereMesh.new()
		"torus":
			mesh = TorusMesh.new()
			mesh.inner_radius = 0.5
			mesh.outer_radius = 1.0
		"capsule": mesh = CapsuleMesh.new()
		
	if mesh:
		is_geometric = true
		if has_node("MeshInstance3D"): $MeshInstance3D.hide()
			
		geo_mesh_instance = MeshInstance3D.new()
		geo_mesh_instance.mesh = mesh
		geo_mesh_instance.position.y = 2.5
		geo_mesh_instance.scale = Vector3(1.5, 1.5, 1.5)
		add_child(geo_mesh_instance)
		
		geo_base_color = color
		var mat = ShaderMaterial.new()
		mat.shader = neon_shader
		mat.set_shader_parameter("line_color", color)
		mat.set_shader_parameter("line_thickness", 0.12)
		mat.set_shader_parameter("glow_intensity", 2.5)
		mat.set_shader_parameter("frequency", 4.0)
		geo_mesh_instance.material_override = mat

func _setup_fbx_model(cfg: Dictionary):
	is_geometric = false
	if has_node("MeshInstance3D"): $MeshInstance3D.hide()
	
	var res = load(cfg.path)
	if res:
		var model = res.instantiate()
		add_child(model)
		geo_mesh_instance = model 
		model.scale = Vector3(1, 1, 1)
		model.position = Vector3(0, 0, 0)
		model.rotation.y = PI # Korrektur: Modell schaut im Node jetzt nach vorne (-Z)
		
		_setup_animations()

func _setup_animations():
	anim_player = geo_mesh_instance.find_child("AnimationPlayer", true)
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		geo_mesh_instance.add_child(anim_player)
	
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var lib = anim_player.get_animation_library("")

	var target_skeleton: Skeleton3D = _find_skeleton_recursive(geo_mesh_instance)
	
	# WICHTIG: Wir setzen den root_node auf den AnimationPlayer selbst (.)
	# Dadurch funktionieren Pfade, die mit get_path_to berechnet wurden, garantiert.
	anim_player.root_node = "."
	var target_skeleton_path = str(anim_player.get_path_to(target_skeleton)) if target_skeleton else "Skeleton3D"

	var anim_mapping = {
		"Idle": {"file": "res://Assets/models/KayKit_Skeletons_1.1_FREE/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx", "source": "Idle_A", "loop": true},
		"Walking": {"file": "res://Assets/models/KayKit_Skeletons_1.1_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Walking_A", "loop": true},
		"Jump_Start": {"file": "res://Assets/models/KayKit_Skeletons_1.1_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Start", "loop": false},
		"Jump_Idle": {"file": "res://Assets/models/KayKit_Skeletons_1.1_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Idle", "loop": true},
		"Jump_Land": {"file": "res://Assets/models/KayKit_Skeletons_1.1_FREE/Animations/fbx/Rig_Medium/Rig_Medium_MovementBasic.fbx", "source": "Jump_Land", "loop": false}
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
						var matched_tracks = 0
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
								
								if target_skeleton.find_bone(final_bone) != -1:
									matched_tracks += 1
								anim.track_set_path(i, target_skeleton_path + ":" + final_bone)
						
						anim.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
						lib.add_animation(target_name, anim)
						
						print("EnemyAnims: Loaded ", target_name, " (", matched_tracks, "/", anim.get_track_count(), " matched) for ", model_id, " at path: ", target_skeleton_path)
					else:
						print("EnemyAnims: Source NOT found: ", data.source, " in ", data.file)
				scene.queue_free()
	
	# Initial Idle starten
	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var result = _find_skeleton_recursive(c)
		if result: return result
	return null


func _respawn():
	show()
	$CollisionShape3D.disabled = false
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if mesh and mesh is MeshInstance3D and not is_geometric:
		if mesh.material_override:
			mesh.material_override.emission_enabled = true
	elif mesh and mesh is MeshInstance3D and is_geometric:
		var mat = mesh.material_override
		if mat: mat.set_shader_parameter("glow_intensity", 4.0)

func _die():
	# Einfacher Sterbe-Effekt
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if mesh and mesh is MeshInstance3D:
		if is_geometric:
			var mat = mesh.material_override
			if mat: mat.set_shader_parameter("glow_intensity", 0.0)
		else:
			var mat = mesh.material_override.duplicate()
			mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
			mat.emission_enabled = false 
			mesh.material_override = mat
	
	# Eventuell Collision ausschalten
	$CollisionShape3D.disabled = true
	# Nach einiger Zeit verstecken
	await get_tree().create_timer(3.0).timeout
	if hp <= 0:
		hide()

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Aura permanent anzeigen wenn ein Schild/Eisbarriere aktiv ist
	if casting_aura:
		# Wir prüfen ob Eisbarriere in debuffs/buffs ist (beim Mob ist es meist debuffs)
		var has_shield = false
		for d in debuffs:
			if d.get("type") == "Eisbarriere":
				has_shield = true
				break
		
		if has_shield:
			casting_aura.show()
		else:
			casting_aura.hide()

	if is_geometric and geo_mesh_instance and hp > 0:
		floating_time += delta
		geo_mesh_instance.position.y = 2.5 + sin(floating_time * 2.0) * 0.4
		geo_mesh_instance.rotation.y += delta * 0.5 # Langsame Eigenrotation

	if hp > 0:
		# 1. Schwerkraft anwenden
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			# Kleiner Anpressdruck nach unten, damit is_on_floor stabil bleibt
			velocity.y = -0.1
		
		# 2. Horizontale Bewegung zum Server-Ziel
		var target_pos_horizontal = Vector3(target_position.x, global_position.y, target_position.z)
		var diff = target_pos_horizontal - global_position
		
		if diff.length() > 0.2: # Deadzone gegen Zittern
			# Bewege dich mit konstanter Geschwindigkeit zum Ziel (limitiert durch Distanz)
			var move_dir = diff.normalized()
			var desired_vel = move_dir * 4.0 # Standard-Laufgeschwindigkeit
			
			# Sanftes Anfahren/Bremsen
			velocity.x = lerp(velocity.x, desired_vel.x, delta * 5.0)
			velocity.z = lerp(velocity.z, desired_vel.z, delta * 5.0)
		else:
			# Stoppe sofort wenn nah genug
			velocity.x = move_toward(velocity.x, 0, delta * 10.0)
			velocity.z = move_toward(velocity.z, 0, delta * 10.0)
		
		# 3. Physik ausführen (beachtet Kollisionen und Gefälle)
		move_and_slide()
		
		# 4. Rotation interpolieren
		# Korrektur um 180 Grad (+ PI), damit sie nicht rückwärts laufen
		rotation.y = lerp_angle(rotation.y, target_rotation + PI, delta * 10.0)
		
		# 5. Animationen updaten (falls FBX Modell)
		if not is_geometric and anim_player:
			if not is_on_floor():
				if anim_player.has_animation("Jump_Idle") and anim_player.current_animation != "Jump_Idle":
					anim_player.play("Jump_Idle")
			else:
				var cur_speed = Vector2(velocity.x, velocity.z).length()
				if cur_speed > 0.2:
					if anim_player.current_animation != "Walking":
						anim_player.play("Walking", 0.2)
				else:
					if anim_player.current_animation != "Idle":
						anim_player.play("Idle", 0.3)
