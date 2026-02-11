extends OmniLight3D

func _ready():
	add_to_group("street_lights")
	# Initial state based on a global time if possible, or just wait for update
	pass

func toggle_light(is_on: bool):
	visible = is_on
