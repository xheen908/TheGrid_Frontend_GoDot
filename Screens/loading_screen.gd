extends Control

@onready var background_texture = %BackgroundTexture
@onready var progress_bar = %ProgressBar
@onready var status_label = %StatusLabel
@onready var map_name_label = %MapNameLabel

var show_time: float = 0.0
var min_display_time: float = 0.5  # Minimum 500ms display

var map_artworks = {
	"WorldMap0": "res://Assets/Loadingscreens/WorldMap0.png",
	"Arena": "res://Assets/Loadingscreens/Arena.jpg",
	"Arena1": "res://Assets/Loadingscreens/Arena1.jpg",
	"Arena2": "res://Assets/Loadingscreens/Arena1.jpg", # Use Lila for Arena2 too
	"testmap0": "res://Assets/Loadingscreens/Arena.jpg" # Fallback for testmap
}

func _ready():
	hide()

func show_loading(map_name: String):
	print("[LOADING] show_loading for map: ", map_name)
	show_time = Time.get_ticks_msec() / 1000.0
	map_name_label.text = "Loading " + map_name + "..."
	status_label.text = "Initializing..."
	progress_bar.value = 0
	
	# Set artwork (Case-insensitive lookup)
	var path = "res://Assets/bg.png"
	for key in map_artworks:
		if key.to_lower() == map_name.to_lower():
			path = map_artworks[key]
			break
	
	print("[LOADING] Selected artwork path: ", path)
	if ResourceLoader.exists(path):
		background_texture.texture = load(path)
	else:
		print("[ERROR] Artwork path does not exist: ", path)
	
	show()

func update_progress(current: int, total: int):
	# print("[DEBUG] LoadingScreen: update_progress ", current, "/", total)
	if total > 0:
		progress_bar.value = (float(current) / float(total)) * 100.0
		status_label.text = "Loading entities... %d/%d" % [current, total]
	else:
		progress_bar.value = 100
		status_label.text = "Ready!"

func hide_loading():
	# Ensure minimum display time
	var elapsed = (Time.get_ticks_msec() / 1000.0) - show_time
	if elapsed < min_display_time:
		await get_tree().create_timer(min_display_time - elapsed).timeout
	
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	hide()
	modulate.a = 1.0  # Reset for next use
