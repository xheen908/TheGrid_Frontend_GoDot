extends CharacterBody3D

@onready var visuals = $Visuals
@onready var name_label = $NameLabel
@onready var quest_indicator = %QuestIndicator

var quest_id = ""
var game_object_id = 0
var npc_name = ""
var model_name = "Knight"

var indicator_time = 0.0

var models = {
	"Barbarian": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Barbarian.fbx"),
	"Knight": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Knight.fbx"),
	"Mage": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Mage.fbx"),
	"Ranger": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Ranger.fbx"),
	"Rogue": preload("res://Assets/models/KayKit_Adventurers_2.0_FREE/Characters/fbx/Rogue.fbx")
}

func setup_dynamic(data: Dictionary):
	npc_name = data.get("name", "Questgeber")
	quest_id = data.get("quest_id", "")
	model_name = data.get("model", "Knight")
	
	name_label.text = npc_name + "\n[Questgeber]"
	name_label.modulate = Color(1, 1, 0) # Gelb für Quests
	
	_update_model()
	update_indicator()

func _ready():
	add_to_group("targetable")
	add_to_group("quest_giver")
	
	if NetworkManager:
		NetworkManager.quest_sync_received.connect(func(_q): update_indicator())
		NetworkManager.quest_accepted.connect(func(_d): update_indicator())
		NetworkManager.quest_completed.connect(func(_q): update_indicator())
		NetworkManager.quest_rewarded.connect(func(_q): update_indicator())
		NetworkManager.quest_progress_updated.connect(func(_qid, _prog): update_indicator())
	
	update_indicator()
	
	# Einfache Idle Animation falls vorhanden
	var anim_player = get_node_or_null("Visuals/AnimationPlayer")
	if anim_player:
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle")

func _process(delta):
	if quest_indicator and quest_indicator.visible:
		indicator_time += delta
		# Leichtes Schweben und Pulsieren (Premium Feeling)
		quest_indicator.position.y = 3.5 + sin(indicator_time * 3.0) * 0.2
		var s = 1.0 + sin(indicator_time * 5.0) * 0.05
		quest_indicator.scale = Vector3(s, s, s)

func update_indicator():
	if quest_indicator and quest_indicator.has_method("set_billboard_mode"):
		quest_indicator.set_billboard_mode(1) # Billboard Mode: Enabled
		
	if quest_id == "" or not is_inside_tree(): 
		if quest_indicator: quest_indicator.hide()
		return
	
	var status = "available"
	var has_quest = false
	var quest_data = {}
	
	# Hole Quest-Liste aus dem NetworkManager
	if NetworkManager.current_player_data and NetworkManager.current_player_data.has("quests"):
		for q in NetworkManager.current_player_data["quests"]:
			if str(q.get("quest_id", "")) == str(quest_id):
				status = q.get("status", "active")
				quest_data = q
				has_quest = true
				break
	
	# Fallback: Wenn Quest aktiv ist, aber laut Progress schon "fertig" aussieht
	if status == "active" and quest_data.has("progress") and quest_data.has("objectives"):
		var all_done = true
		var objectives = quest_data.get("objectives", {})
		var progress = quest_data.get("progress", {})
		for obj_id in objectives.keys():
			if progress.get(obj_id, 0) < objectives[obj_id]:
				all_done = false
				break
		if all_done and objectives.size() > 0:
			status = "completed"
	
	print("[NPC] ", npc_name, " check (", quest_id, ") -> Final Status: ", status)
			
	match status:
		"available":
			quest_indicator.text = "!"
			quest_indicator.modulate = Color(1, 1, 0) # Gelb
			quest_indicator.show()
		"completed":
			quest_indicator.text = "?"
			quest_indicator.modulate = Color(1, 1, 0) # Gelb
			quest_indicator.show()
		_:
			quest_indicator.hide()

func _update_model():
	# Entferne altes Modell falls vorhanden
	for child in visuals.get_children():
		child.queue_free()
		
	var model_key = model_name
	if not models.has(model_key):
		# Case-insensitive check
		for key in models.keys():
			if key.to_lower() == model_name.to_lower():
				model_key = key
				break
				
	if models.has(model_key):
		var scene = models[model_key].instantiate()
		visuals.add_child(scene)
		# Ausrichtung korrigieren (Standard KayKit ist oft um 180 Grad gedreht)
		scene.rotation.y = PI
	else:
		var scene = models["Knight"].instantiate()
		visuals.add_child(scene)
		scene.rotation.y = PI
