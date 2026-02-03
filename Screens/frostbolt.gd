extends Node3D

var speed = 25.0
var target_node = null
var target_pos = Vector3.ZERO

func setup(p_target):
	target_node = p_target
	if target_node:
		target_pos = target_node.global_position + Vector3(0, 1.0, 0)
	
	# Initial look at target
	if target_pos.distance_to(global_position) > 0.1:
		look_at(target_pos)

	# Start VFX if VFXController exists
	var vfx = get_node_or_null("VFX")
	if vfx and vfx.has_method("play"):
		vfx.play()

func _process(delta):
	# Update target pos if node is valid
	if is_instance_valid(target_node):
		target_pos = target_node.global_position + Vector3(0, 1.0, 0)
	
	var dir = global_position.direction_to(target_pos)
	if global_position.distance_to(target_pos) < 0.5:
		_impact()
		return
	
	# Move to target
	global_position += dir * speed * delta
	
	# Smoothly look at target
	if dir != Vector3.ZERO:
		var target_pos_eye = global_position + dir
		look_at(target_pos_eye)

func _impact():
	# For now, just remove the bolt. 
	# The VFX child could trigger a hit animation, but queue_free is safer for now.
	queue_free()
