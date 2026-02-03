@tool
extends MeshInstance3D

@export var terrain_size: float = 400.0:
	set(v):
		terrain_size = v
		if Engine.is_editor_hint(): _generate_terrain()
@export var subdivisions: int = 200:
	set(v):
		subdivisions = v
		if Engine.is_editor_hint(): _generate_terrain()
@export var max_height: float = 25.0:
	set(v):
		max_height = v
		if Engine.is_editor_hint(): _generate_terrain()
@export var noise_freq: float = 0.012:
	set(v):
		noise_freq = v
		if Engine.is_editor_hint(): _generate_terrain()

func _ready():
	_generate_terrain()

func _generate_terrain():
	# 1. Generiere ein hochauflösendes PlaneMesh
	var plane := PlaneMesh.new()
	plane.size = Vector2(terrain_size, terrain_size)
	plane.subdivide_depth = subdivisions
	plane.subdivide_width = subdivisions
	
	# 2. Nutze den SurfaceTool um die Vertices zu manipulieren
	var st := SurfaceTool.new()
	st.create_from(plane, 0)
	var array_mesh := st.commit()
	
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)
	
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = noise_freq
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# 3. Vertices basierend auf Noise verschieben
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i)
		# Wir berechnen die Höhe basierend auf der Weltposition
		# Damit der Default-Spawn (0,0) sicher ist, senken wir den Wert dort leicht ab
		var h = noise.get_noise_2d(v.x, v.z) * max_height
		
		# Sanfter Krater in der Mitte (Spawn-Bereich)
		var dist_from_center = Vector2(v.x, v.z).length()
		if dist_from_center < 10.0:
			h = lerp(0.0, h, dist_from_center / 10.0)
			
		v.y = h
		mdt.set_vertex(i, v)
	
	# 4. Mesh aktualisieren und Normalen neu berechnen
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.create_from(array_mesh, 0)
	st.generate_normals()
	self.mesh = st.commit()
	
	# 5. ECHTE Physikalische Collision generieren (Trimesh)
	# Im Editor löschen wir alte Collision-Nodes zuerst
	for child in get_children():
		if child is StaticBody3D:
			child.free()
			
	if not Engine.is_editor_hint():
		create_trimesh_collision()
	elif Engine.is_editor_hint():
		# Im Editor erzeugen wir eine Vorschau-Collision, falls gewollt, 
		# aber create_trimesh_collision() reicht für das Spiel
		pass
	
	print("ProceduralTerrain: Gelände generiert (", terrain_size, "m)")
