extends Node3D

@export_range(0, 24) var time_of_day: float = 12.0 # 12.0 is noon
@export var day_length_seconds: float = 300.0 # 5 minutes for a full day

@export var sun_path: NodePath
@export var moon_path: NodePath
@export var world_env_path: NodePath

@onready var sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var moon: DirectionalLight3D = get_node_or_null(moon_path)
@onready var world_env: WorldEnvironment = get_node_or_null(world_env_path)

@export_group("Weather")
@export var rain_particles: GPUParticles3D
@export var snow_particles: GPUParticles3D

enum Weather { CLEAR, RAIN, SNOW }
var current_weather: Weather = Weather.CLEAR

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			set_weather(Weather.CLEAR)
		elif event.keycode == KEY_F6:
			set_weather(Weather.RAIN)
		elif event.keycode == KEY_F7:
			set_weather(Weather.SNOW)
		elif event.keycode == KEY_F4:
			day_length_seconds = 10.0 if day_length_seconds > 10.0 else 300.0
			print("Day length changed to: ", day_length_seconds)

func _ready() -> void:
	if world_env and world_env.environment:
		world_env.environment = world_env.environment.duplicate()
		if world_env.environment.sky:
			world_env.environment.sky = world_env.environment.sky.duplicate()
			if world_env.environment.sky.sky_material:
				world_env.environment.sky.sky_material = world_env.environment.sky.sky_material.duplicate()
	print("EnvironmentManager ready. Time: ", time_of_day)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		time_of_day += (delta / day_length_seconds) * 24.0
		if time_of_day >= 24.0:
			time_of_day -= 24.0
	
	# Follow camera for weather effects
	var camera = get_viewport().get_camera_3d()
	if camera:
		var cam_pos = camera.global_position
		if rain_particles:
			rain_particles.global_position = cam_pos + Vector3(0, 20, 0)
		if snow_particles:
			snow_particles.global_position = cam_pos + Vector3(0, 20, 0)
	
	update_environment()

var debug_timer: float = 0.0
func update_environment() -> void:
	var time_percent = time_of_day / 24.0
	# 6:00 (0.25) -> Sunrise (0 deg)
	# 12:00 (0.5) -> Noon (-90 deg)
	# 18:00 (0.75) -> Sunset (-180 deg)
	# 0:00 (0.0) -> Midnight (90 deg)
	var sun_rotation = (time_percent * -360.0) + 90.0
	var moon_rotation = sun_rotation + 180.0
	
	if sun:
		sun.rotation_degrees.x = sun_rotation
		sun.visible = sun_rotation < 0.0 and sun_rotation > -180.0
		
	if moon:
		moon.rotation_degrees.x = moon_rotation
		moon.visible = not sun.visible

	if world_env and world_env.environment:
		var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			var day_factor = clampf(sin(PI * (time_percent - 0.25) * 2.0), -1.0, 1.0)
			var day_intensity = clampf(day_factor, 0.0, 1.0)
			
			# Modulate Energy
			world_env.environment.ambient_light_energy = lerp(0.05, 1.0, day_intensity)
			world_env.environment.background_energy_multiplier = lerp(0.02, 1.0, day_intensity)
			
			# Modulate Colors
			# Night values: very dark blue/black
			# Day values: the original colors from the material
			var night_color = Color(0.02, 0.02, 0.05)
			var sunset_color = Color(0.8, 0.4, 0.2)
			var day_sky_top = Color(0.1, 0.2, 0.45)
			var day_sky_horizon = Color(0.5, 0.6, 0.7)
			
			sky_mat.sky_top_color = night_color.lerp(day_sky_top, day_intensity)
			
			if day_factor > -0.2 and day_factor < 0.2:
				# Transition to/from sunset
				var sunset_factor = 1.0 - (abs(day_factor) / 0.2)
				sky_mat.sky_horizon_color = day_sky_horizon.lerp(sunset_color, sunset_factor)
			else:
				sky_mat.sky_horizon_color = night_color.lerp(day_sky_horizon, day_intensity)
			
			sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
			
			# Modulate Fog and Ambient Light Color
			world_env.environment.fog_light_color = night_color.lerp(day_sky_horizon, day_intensity)
			world_env.environment.ambient_light_color = night_color.lerp(Color(0.5, 0.5, 0.5), day_intensity)

			update_street_lights(day_intensity)

			debug_timer += get_process_delta_time()
			if debug_timer > 2.0:
				debug_timer = 0.0
				print("Time: %.2f, Intensity: %.2f, SkyTop: %s" % [time_of_day, day_intensity, sky_mat.sky_top_color])
		else:
			print_once("ERROR: sky_material is not ProceduralSkyMaterial!")

var _printed_once = {}
func print_once(msg: String):
	if not _printed_once.has(msg):
		print(msg)
		_printed_once[msg] = true

func set_weather(weather: Weather) -> void:
	current_weather = weather
	if rain_particles:
		rain_particles.emitting = (weather == Weather.RAIN)
	if snow_particles:
		snow_particles.emitting = (weather == Weather.SNOW)
	
	if world_env and world_env.environment:
		var tween = create_tween()
		match weather:
			Weather.CLEAR:
				tween.tween_property(world_env.environment, "fog_density", 0.001, 2.0)
			Weather.RAIN:
				tween.tween_property(world_env.environment, "fog_density", 0.03, 2.0)
			Weather.SNOW:
				tween.tween_property(world_env.environment, "fog_density", 0.05, 2.0)

var street_lights_on: bool = false
func update_street_lights(day_intensity: float):
	var should_be_on = day_intensity < 0.2
	if should_be_on != street_lights_on:
		street_lights_on = should_be_on
		get_tree().call_group("street_lights", "toggle_light", street_lights_on)
