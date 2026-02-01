@tool
extends Area3D

@export var editor_placeholder: bool = false
@export var target_map: String = "WorldMap0"
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_rotation_y: float = 0.0
@export var portal_color: Color = Color.CYAN:
	set(value):
		portal_color = value
		if Engine.is_editor_hint():
			update_visuals()

var is_active = true

func setup_dynamic(data: Dictionary):
	print("Portal setup_dynamic: ", data)
	editor_placeholder = false 
	if "target_map" in data: target_map = data.target_map
	if "spawn_pos" in data:
		var sp = data.spawn_pos
		spawn_position = Vector3(sp.x, sp.y, sp.z)
	if "spawn_rot_y" in data: spawn_rotation_y = data.spawn_rot_y
	if "color" in data: portal_color = Color(data.color)
	update_visuals()

func _ready():
	if editor_placeholder and not Engine.is_editor_hint():
		print("Entferne statisches Placeholder-Portal.")
		queue_free()
		return
		
	body_entered.connect(_on_body_entered)
	update_visuals()

func update_visuals():
	# Ring Material
	var ring_mesh = get_node_or_null("Ring")
	if ring_mesh:
		var mat = ring_mesh.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = Color(0.2, 0.2, 0.2) # Metallisch
			mat.emission_enabled = true
			mat.emission = portal_color
			mat.emission_energy_multiplier = 2.0
			ring_mesh.material_override = mat
		
	# Event Horizon Material (Shader)
	var horizon_mesh = get_node_or_null("EventHorizon")
	if horizon_mesh:
		var mat = horizon_mesh.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			if mat is ShaderMaterial:
				mat.set_shader_parameter("portal_color", portal_color)
			horizon_mesh.material_override = mat

func _on_body_entered(body):
	if is_active and body.is_in_group("player"):
		print("Portal betreten! Ziel: ", target_map)
		is_active = false
		if NetworkManager:
			NetworkManager.request_map_change(target_map, spawn_position, spawn_rotation_y)
		
		# Cooldown damit man nicht sofort wieder zurück geportet wird
		await get_tree().create_timer(3.0).timeout
		is_active = true
		print("Portal wieder bereit.")
