extends Node3D

var speed = 25.0
var target_node = null
var target_pos = Vector3.ZERO

func setup(p_target):
	target_node = p_target
	if target_node:
		target_pos = target_node.global_position + Vector3(0, 1.0, 0)
	
	# Initial schau auf Ziel
	look_at(target_pos)

func _process(delta):
	# Update target pos if node is valid
	if is_instance_valid(target_node):
		target_pos = target_node.global_position + Vector3(0, 1.0, 0)
	
	var dir = global_position.direction_to(target_pos)
	if global_position.distance_to(target_pos) < 0.5:
		_impact()
		return
	
	# Bewege zum Ziel
	global_position += dir * speed * delta
	
	# Schau zum Ziel (sanft)
	if dir != Vector3.ZERO:
		# Wir schauen in Richtung 'dir', aber Godot look_at schaut nach -Z.
		# Da unser Mesh durch die Kapsel-Rotation (X-Achse 90) nun entlang Z liegt,
		# nutzen wir eine korrigierte Basis.
		var target_pos_eye = global_position + dir
		look_at(target_pos_eye)

func _impact():
	# Später: Partikel Effekt
	queue_free()
