extends Control

@onready var title_label = %QuestTitle
@onready var description_label = %QuestDescription
@onready var objective_list = %ObjectiveList
@onready var accept_button = %AcceptButton
@onready var reward_button = %RewardButton
@onready var close_button = %CloseButton

var current_quest_id = ""
var quest_status = "available"

func _ready():
	hide()
	accept_button.pressed.connect(_on_accept_pressed)
	reward_button.pressed.connect(_on_reward_pressed)
	close_button.pressed.connect(hide)
	
	if NetworkManager:
		NetworkManager.quest_info_received.connect(_on_quest_info_received)
		NetworkManager.quest_accepted.connect(_on_quest_accepted)
		NetworkManager.quest_rewarded.connect(_on_quest_rewarded)

func show_quest(data: Dictionary):
	current_quest_id = data.get("quest_id", "")
	title_label.text = data.get("title", "Quest")
	description_label.text = data.get("description", "")
	quest_status = data.get("status", "available")
	
	# Ziele anzeigen
	objective_list.clear()
	var objectives = data.get("objectives", {})
	var progress = data.get("progress", {})
	
	for target_id in objectives.keys():
		var total = objectives[target_id]
		var current = progress.get(target_id, 0)
		var item_text = "- " + str(target_id) + ": " + str(current) + "/" + str(total)
		objective_list.add_item(item_text)
		
	# Buttons steuern
	accept_button.visible = (quest_status == "available")
	reward_button.visible = (quest_status == "completed")
	
	show()

func _on_quest_info_received(data: Dictionary):
	show_quest(data)

func _on_accept_pressed():
	if current_quest_id != "":
		NetworkManager.send_quest_accept(current_quest_id)
		hide()

func _on_reward_pressed():
	if current_quest_id != "":
		NetworkManager.send_quest_reward(current_quest_id)
		hide()

func _on_quest_accepted(data: Dictionary):
	var qid = data.get("quest_id", "")
	if qid == current_quest_id:
		hide()

func _on_quest_rewarded(qid: String):
	if qid == current_quest_id:
		hide()
