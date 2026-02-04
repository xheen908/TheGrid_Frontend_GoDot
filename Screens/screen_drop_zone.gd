extends Control

signal item_dropped_on_screen(item_data: Dictionary)

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("from_slot")

func _drop_data(_at_position, data):
	item_dropped_on_screen.emit(data)
