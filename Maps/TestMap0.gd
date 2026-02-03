extends Node3D

func _ready():
	# Wir warten einen Moment, damit Terrain3D die Collision in Ruhe berechnen kann
	# bevor die Physik-Engine den Spieler nach unten zieht.
	get_tree().create_timer(0.5).timeout.connect(_on_ready_timeout)

func _on_ready_timeout():
	print("TestMap0: Boden sollte jetzt bereit sein.")
