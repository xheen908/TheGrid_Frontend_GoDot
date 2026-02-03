extends CharacterBody3D

@onready var name_label = $NameLabel

var mob_id = ""
var target_position = Vector3.ZERO
var target_rotation = 0.0
var hp = 100
var max_hp = 100
var is_frozen = false
var is_chilled = false
var debuffs = []
var target_name = null # Name vom Server

var casting_aura_scene = preload("res://Assets/Effects/CastingAura.tscn")
var casting_aura = null
var neon_shader = preload("res://Assets/Shaders/neon_wireframe.gdshader")

var is_geometric = false
var geo_mesh_instance: MeshInstance3D = null
var floating_time = 0.0
var geo_base_color = Color(0, 1, 1)

func _ready():
	add_to_group("mobs")
	add_to_group("targetable")
	
	casting_aura = casting_aura_scene.instantiate()
	add_child(casting_aura)
	casting_aura.hide()

func setup(data: Dictionary):
	mob_id = data.id
	_check_geometric_mesh(data.get("name", ""))
	update_data(data)
	global_position = target_position

func update_data(data: Dictionary):
	hp = data.hp
	max_hp = data.maxHp
	var lvl = data.get("level", 1)
	name_label.text = "[L" + str(lvl) + "] " + data.get("name", "Unknown")
	
	var trans = data.transform
	target_position = Vector3(trans.x, trans.y, trans.z)
	target_rotation = trans.get("rot", 0.0)
	target_name = data.get("target_name")
	
	# Debuffs prüfen
	debuffs = data.get("debuffs", [])
	is_frozen = false
	is_chilled = false
	for d in debuffs:
		if d.type == "Frozen": is_frozen = true
		if d.type == "Chill": is_chilled = true
			
	_update_visuals()
	
	if hp <= 0:
		if visible and (not $CollisionShape3D.disabled or (geo_mesh_instance and is_geometric)):
			_die()
	else:
		if not visible or $CollisionShape3D.disabled:
			_respawn()

func _check_geometric_mesh(enemy_name: String):
	var lower_name = enemy_name.to_lower()
	var mesh: Mesh = null
	var color = Color(0, 1, 1) # Cyan default
	
	if "würfel" in lower_name or "cube" in lower_name:
		mesh = BoxMesh.new()
		color = Color(0, 1, 0) # Green
	elif "kegel" in lower_name or "cone" in lower_name:
		mesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		color = Color(1, 0, 1) # Magenta
	elif "pyramide" in lower_name or "pyramid" in lower_name:
		mesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.27 # Gizeh-Proportion: Höhe zu Basis (ca. 0.63 * Breite)
		mesh.radial_segments = 4
		mesh.rings = 1
		color = Color(1, 0.5, 0) # Orange
	elif "sphäre" in lower_name or "sphere" in lower_name:
		mesh = SphereMesh.new()
		color = Color(1, 1, 0) # Yellow
	elif "torus" in lower_name or "ring" in lower_name:
		mesh = TorusMesh.new()
		mesh.inner_radius = 0.5
		mesh.outer_radius = 1.0
		color = Color(0, 0.5, 1) # Azure
	elif "kapsel" in lower_name or "capsule" in lower_name:
		mesh = CapsuleMesh.new()
		color = Color(0.5, 1, 0.5) # Pale Green
		
	if mesh:
		is_geometric = true
		# Originalmesh verstecken
		if has_node("MeshInstance3D"):
			$MeshInstance3D.hide()
			
		# Neues Mesh erstellen
		geo_mesh_instance = MeshInstance3D.new()
		geo_mesh_instance.mesh = mesh
		geo_mesh_instance.position.y = 2.5 # Höher schweben (Basis 2.5m)
		geo_mesh_instance.scale = Vector3(1.5, 1.5, 1.5) # Insgesamt ca. 50% größer (1.3 * 1.2 ≈ 1.5)
		add_child(geo_mesh_instance)
		
		# Shader Material anwenden
		geo_base_color = color
		var mat = ShaderMaterial.new()
		mat.shader = neon_shader
		mat.set_shader_parameter("line_color", color)
		mat.set_shader_parameter("line_thickness", 0.12)
		mat.set_shader_parameter("glow_intensity", 2.5)
		mat.set_shader_parameter("frequency", 4.0)
		geo_mesh_instance.material_override = mat

func _update_visuals():
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if not mesh: return
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

func _respawn():
	show()
	$CollisionShape3D.disabled = false
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if mesh and not is_geometric:
		if mesh.material_override:
			mesh.material_override.emission_enabled = true
	elif mesh and is_geometric:
		var mat = mesh.material_override
		if mat: mat.set_shader_parameter("glow_intensity", 4.0)

func _die():
	# Einfacher Sterbe-Effekt
	var mesh = geo_mesh_instance if is_geometric else $MeshInstance3D
	if mesh:
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
		
		# 2. Horizontale Bewegung zum Server-Ziel (Interpolation)
		# Wir ignorieren die Y-Position vom Server, damit der Gegner nicht "fliegt"
		var target_pos_horizontal = Vector3(target_position.x, global_position.y, target_position.z)
		var next_step = global_position.lerp(target_pos_horizontal, delta * 10.0)
		
		var horizontal_vel = (next_step - global_position) / delta
		velocity.x = horizontal_vel.x
		velocity.z = horizontal_vel.z
		
		# 3. Physik ausführen (beachtet Kollisionen und Gefälle)
		move_and_slide()
		
		# 4. Rotation interpolieren
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
