extends Area3D

@export var target_map: String = "WorldMap0"
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_rotation_y: float = 0.0
@export var portal_color: Color = Color.CYAN

var is_active = true

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Ring Material
	var ring_mesh = $Ring
	if ring_mesh:
		var mat = ring_mesh.get_active_material(0).duplicate()
		mat.albedo_color = Color(0.2, 0.2, 0.2) # Metallisch
		mat.emission_enabled = true
		mat.emission = portal_color
		mat.emission_energy_multiplier = 2.0
		ring_mesh.material_override = mat
		
	# Event Horizon Material (Shader)
	var horizon_mesh = $EventHorizon
	if horizon_mesh:
		var mat = horizon_mesh.get_active_material(0).duplicate()
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
