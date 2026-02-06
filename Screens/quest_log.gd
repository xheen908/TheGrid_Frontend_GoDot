extends Control

@onready var quest_list = %QuestList
@onready var detail_title = %DetailTitle
@onready var detail_description = %DetailDescription
@onready var detail_objectives = %DetailObjectives
@onready var abandoned_button = %AbandonButton # Optional

var active_quests = [] # List of quest data from sync
var selected_quest_id = ""

func _ready():
	hide()
	if NetworkManager:
		NetworkManager.quest_sync_received.connect(_on_quest_sync)
		NetworkManager.quest_progress_updated.connect(_on_quest_progress)
		NetworkManager.quest_completed.connect(_on_quest_completed)
		NetworkManager.quest_rewarded.connect(_on_quest_rewarded)
		NetworkManager.quest_accepted.connect(_on_quest_accepted)
	
	quest_list.item_selected.connect(_on_quest_selected)

func _on_quest_sync(quests: Array):
	active_quests = quests
	_update_list()

func _on_quest_progress(qid: String, progress: Dictionary):
	for q in active_quests:
		if q.get("quest_id", "") == qid:
			q["progress"] = progress
			break
	if selected_quest_id == qid:
		_show_details(qid)
	_update_list()

func _on_quest_completed(qid: String):
	for q in active_quests:
		if q.get("quest_id", "") == qid:
			q["status"] = "completed"
			break
	if selected_quest_id == qid:
		_show_details(qid)
	_update_list()

func _on_quest_rewarded(qid: String):
	var to_remove = -1
	for i in range(active_quests.size()):
		if active_quests[i].get("quest_id", "") == qid:
			to_remove = i
			break
	if to_remove != -1:
		active_quests.remove_at(to_remove)
	
	if selected_quest_id == qid:
		selected_quest_id = ""
		detail_title.text = "Quest Titel"
		detail_description.text = ""
		detail_objectives.text = ""
	
	_update_list()

func _on_quest_accepted(data: Dictionary):
	var qid = data.get("quest_id", "")
	if qid == "": return
	
	for q in active_quests:
		if q.get("quest_id", "") == qid: return
		
	var new_q = {
		"quest_id": qid,
		"title": data.get("title", "Quest"),
		"description": data.get("description", ""),
		"objectives": data.get("objectives", {}),
		"objective_names": data.get("objective_names", {}),
		"status": "active",
		"progress": {}
	}
	active_quests.append(new_q)
	_update_list()

func _update_list():
	quest_list.clear()
	for i in range(active_quests.size()):
		var q = active_quests[i]
		var status_text = ""
		if q.get("status", "") == "completed":
			status_text = " (Bereit!)"
		var q_title = q.get("title", "Unbekannt")
		var q_id = q.get("quest_id", "")
		quest_list.add_item(q_title + status_text)
		quest_list.set_item_metadata(i, q_id)

func _on_quest_selected(index: int):
	if index < 0 or index >= quest_list.item_count:
		return
	var qid = quest_list.get_item_metadata(index)
	if qid == null:
		return
	selected_quest_id = qid
	_show_details(qid)

func _show_details(qid: String):
	if qid == null or qid == "": return
	
	var quest = null
	for q in active_quests:
		if q.get("quest_id", "") == qid:
			quest = q
			break
	
	if not quest: return
	
	detail_title.text = quest.get("title", "Quest")
	detail_description.text = quest.get("description", "")
	
	var obj_text = "Ziele:\n"
	var objectives = quest.get("objectives", {})
	var progress = quest.get("progress", {})
	var names = quest.get("objective_names", {})
	
	for target_id in objectives.keys():
		var total = int(objectives[target_id])
		var current = int(progress.get(target_id, 0))
		current = min(current, total)
		var display_name = names.get(target_id, str(target_id))
		obj_text += "- " + display_name + ": " + str(current) + "/" + str(total) + "\n"
	
	detail_objectives.text = obj_text

func toggle():
	if visible:
		hide()
	else:
		show()
		if active_quests.size() > 0 and selected_quest_id == "" and quest_list.item_count > 0:
			quest_list.select(0)
			_on_quest_selected(0)
