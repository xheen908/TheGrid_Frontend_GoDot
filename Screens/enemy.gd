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

func _ready():
	add_to_group("mobs")
	add_to_group("targetable")

func setup(data: Dictionary):
	mob_id = data.id
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
		if visible and not $CollisionShape3D.disabled:
			_die()
	else:
		if not visible or $CollisionShape3D.disabled:
			_respawn()

func _update_visuals():
	var mesh = $MeshInstance3D
	if not mesh: return
	var mat = mesh.material_override
	if not mat: return
	
	if is_frozen:
		# Schockgefrostet (Cyan/Weiß)
		mat.albedo_color = Color(0.3, 0.9, 1.0)
		mat.emission = Color(0.3, 0.9, 1.0)
		mat.emission_energy_multiplier = 4.0
	elif is_chilled:
		# Verlangsamt (Dunkelblau)
		mat.albedo_color = Color(0, 0.3, 0.8)
		mat.emission = Color(0, 0.3, 0.8)
		mat.emission_energy_multiplier = 2.0
	else:
		# Normales Rot
		mat.albedo_color = Color(1.0, 0, 0)
		mat.emission = Color(1.0, 0, 0)
		mat.emission_energy_multiplier = 2.0

func _respawn():
	show()
	$CollisionShape3D.disabled = false
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.emission_enabled = true

func _die():
	# Einfacher Sterbe-Effekt
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		var mat = mesh.material_override.duplicate()
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
		mat.emission_enabled = false # Leuchten ausschalten beim Sterben
		mesh.material_override = mat
	
	# Eventuell Collision ausschalten
	$CollisionShape3D.disabled = true
	# Nach einiger Zeit verstecken
	await get_tree().create_timer(3.0).timeout
	if hp <= 0:
		hide()

func _physics_process(delta):
	if hp > 0:
		global_position = global_position.lerp(target_position, delta * 10.0)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
