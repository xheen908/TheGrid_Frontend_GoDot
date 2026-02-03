extends Node3D

# Dieses Script generiert automatisch Trimesh-Collision für alle Meshes unter diesem Node.
# Nützlich für importierte GLTF-Gebäude.

func _ready():
	generate_collision(self)

func generate_collision(node):
	if node is MeshInstance3D:
		# Erstellt einen StaticBody3D mit einem TrimeshCollisionShape als Kind des Meshes
		node.create_trimesh_collision()
		
	for child in node.get_children():
		generate_collision(child)
