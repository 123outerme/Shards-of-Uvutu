extends Node2D
class_name QuestsMenu

signal back_pressed
signal turn_in_step_to(saveName: String)
signal level_up(newLevels: int)
signal act_changed

@export_category("Quests Panel - Filters")
@export var selectedFilter: QuestTracker.Status = QuestTracker.Status.ALL
@export var turnInTargetName: String = ''
@export var lockFilters: bool = false

var rewardNewLvs: int = 0

var lastFocused: Control = null
var lastInteractedTracker: QuestTracker = null

@onready var questsTitle: RichTextLabel = get_node("QuestsPanel/Panel/QuestsTitle")
@onready var actTitle: RichTextLabel = get_node("QuestsPanel/Panel/ActTitle")
@onready var inProgressButton: Button = get_node("QuestsPanel/Panel/HBoxContainer/InProgressButton")
@onready var readyToTurnInButton: Button = get_node("QuestsPanel/Panel/HBoxContainer/ReadyToTurnInButton")
@onready var completedButton: Button = get_node("QuestsPanel/Panel/HBoxContainer/CompletedButton")
@onready var notCompletedButton: Button = get_node("QuestsPanel/Panel/HBoxContainer/NotCompletedButton")
@onready var failedButton: Button = get_node("QuestsPanel/Panel/HBoxContainer/FailedButton")
@onready var vboxViewport: VBoxContainer = get_node("QuestsPanel/Panel/ScrollContainer/VBoxContainer")
@onready var backButton: Button = get_node("QuestsPanel/Panel/BackButton")
@onready var questDetailsPanel: QuestDetailsPanel = get_node("QuestDetailsPanel")
@onready var questRewardPanel: QuestRewardPanel = get_node("QuestRewardPanel")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _unhandled_input(event):
	if visible and event.is_action_pressed('game_decline'):
		get_viewport().set_input_as_handled()
		toggle()

func toggle():
	visible = not visible
	if visible:
		load_quests_panel(true)
		initial_focus()
	else:
		if questDetailsPanel.visible:
			questDetailsPanel.hide_panel()
		backButton.disabled = false
		back_pressed.emit()

func initial_focus():
	var centerMostFilter = get_centermost_filter()
	if centerMostFilter != null:
		centerMostFilter.grab_focus()
		return
	
	backButton.grab_focus()

func get_centermost_filter() -> Button:
	if not completedButton.disabled:
		return completedButton
		
	if not readyToTurnInButton.disabled:
		return readyToTurnInButton
		
	if not inProgressButton.disabled:
		return inProgressButton
		
	if not failedButton.disabled:
		return failedButton
		
	return null

func restore_previous_focus(controlProperty: String):
	get_last_focused_panel()
	if lastFocused == null:
		initial_focus()
	else:
		lastFocused[controlProperty].grab_focus()

func get_last_focused_panel():
	lastFocused = null
	for panel in get_tree().get_nodes_in_group("QuestSlotPanel"):
		if panel.questTracker == lastInteractedTracker:
			lastFocused = panel

func load_quests_panel(fromToggle: bool = false):
	PlayerResources.questInventory.auto_update_quests() # update collect quests
	update_filter_buttons()
	backButton.focus_neighbor_top = backButton.get_path_to(get_centermost_filter())
	if fromToggle:
		# lock all filter buttons to be unlocked when creating quest slot panels
		inProgressButton.disabled = true
		inProgressButton.focus_neighbor_bottom = inProgressButton.get_path_to(backButton)
		inProgressButton.focus_neighbor_top = inProgressButton.get_path_to(backButton)
		
		readyToTurnInButton.disabled = true
		readyToTurnInButton.focus_neighbor_bottom = readyToTurnInButton.get_path_to(backButton)
		readyToTurnInButton.focus_neighbor_top = readyToTurnInButton.get_path_to(backButton)
		
		completedButton.disabled = true
		completedButton.focus_neighbor_bottom = inProgressButton.get_path_to(backButton)
		completedButton.focus_neighbor_top = inProgressButton.get_path_to(backButton)
		
		notCompletedButton.disabled = true
		notCompletedButton.focus_neighbor_bottom = notCompletedButton.get_path_to(backButton)
		notCompletedButton.focus_neighbor_top = notCompletedButton.get_path_to(backButton)
		
		failedButton.disabled = true
		failedButton.focus_neighbor_bottom = failedButton.get_path_to(backButton)
		failedButton.focus_neighbor_top = failedButton.get_path_to(backButton)
		
		for panel in get_tree().get_nodes_in_group("QuestSlotPanel"):
			panel.queue_free()
	
		var firstPanel: QuestSlotPanel = null
		var questSlotPanel = load("res://prefabs/ui/quests/quest_slot_panel.tscn")
		for questTracker in PlayerResources.questInventory.get_sorted_trackers():
			var trackerStatus: QuestTracker.Status = questTracker.get_current_status()
			if selectedFilter == QuestTracker.Status.ALL or selectedFilter == trackerStatus \
					or (selectedFilter == QuestTracker.Status.INCOMPLETE and trackerStatus != QuestTracker.Status.COMPLETED and trackerStatus != QuestTracker.Status.FAILED):
				var instantiatedPanel: QuestSlotPanel = questSlotPanel.instantiate()
				instantiatedPanel.questTracker = questTracker
				instantiatedPanel.turnInName = turnInTargetName
				instantiatedPanel.questsMenu = self
				vboxViewport.add_child(instantiatedPanel)
				if firstPanel == null:
					firstPanel = instantiatedPanel
				if turnInTargetName in questTracker.get_current_step().turnInNames and fromToggle:
					instantiatedPanel.turnInButton.call_deferred('grab_focus')
				backButton.focus_neighbor_top = backButton.get_path_to(instantiatedPanel.detailsButton) # last panel keeps the focus neighbor of the back button
			if trackerStatus == QuestTracker.Status.IN_PROGRESS:
				inProgressButton.disabled = lockFilters
			if trackerStatus == QuestTracker.Status.READY_TO_TURN_IN_STEP:
				readyToTurnInButton.disabled = lockFilters
			if trackerStatus == QuestTracker.Status.COMPLETED:
				completedButton.disabled = lockFilters
			else: # if not completed
				notCompletedButton.disabled = lockFilters
			if trackerStatus == QuestTracker.Status.FAILED:
				failedButton.disabled = lockFilters
		if firstPanel != null:
			inProgressButton.focus_neighbor_bottom = inProgressButton.get_path_to(firstPanel.detailsButton)
			readyToTurnInButton.focus_neighbor_bottom = readyToTurnInButton.get_path_to(firstPanel.detailsButton)
			completedButton.focus_neighbor_bottom = completedButton.get_path_to(firstPanel.detailsButton)
			notCompletedButton.focus_neighbor_bottom = notCompletedButton.get_path_to(firstPanel.detailsButton)
			failedButton.focus_neighbor_bottom = failedButton.get_path_to(firstPanel.detailsButton)
			firstPanel.detailsButton.focus_neighbor_top = firstPanel.detailsButton.get_path_to(get_centermost_filter())
			firstPanel.turnInButton.focus_neighbor_top = firstPanel.turnInButton.get_path_to(get_centermost_filter())
			firstPanel.pinButton.focus_neighbor_top = firstPanel.pinButton.get_path_to(get_centermost_filter())
		if get_centermost_filter() != null:
			backButton.focus_neighbor_bottom = backButton.get_path_to(get_centermost_filter())
		else:
			backButton.focus_neighbor_bottom = backButton.get_path_to(completedButton)
	else:
		for panel: QuestSlotPanel in get_tree().get_nodes_in_group("QuestSlotPanel"):
			panel.load_quest_slot_panel()
		
	if turnInTargetName != '':
		questsTitle.text = '[center]Turn In Quests[/center]'
	else:
		questsTitle.text = '[center]Quests[/center]'
			
	actTitle.text = 'Act ' + String.num(PlayerResources.questInventory.currentAct) + ': ' + PlayerResources.questInventory.actNames[PlayerResources.questInventory.currentAct]

func update_filter_buttons():
	inProgressButton.button_pressed = selectedFilter == QuestTracker.Status.IN_PROGRESS
	readyToTurnInButton.button_pressed = selectedFilter == QuestTracker.Status.READY_TO_TURN_IN_STEP
	completedButton.button_pressed = selectedFilter == QuestTracker.Status.COMPLETED
	notCompletedButton.button_pressed = selectedFilter == QuestTracker.Status.INCOMPLETE

func filter_by(type: QuestTracker.Status = QuestTracker.Status.ALL):
	selectedFilter = type
	load_quests_panel(true)

func pin_button_pressed(questTracker: QuestTracker):
	lastInteractedTracker = questTracker
	load_quests_panel(true)
	restore_previous_focus('pinButton')

func turn_in(questTracker: QuestTracker):
	lastInteractedTracker = questTracker
	questRewardPanel.reward = questTracker.get_current_step().reward
	var curAct: int = PlayerResources.questInventory.currentAct
	rewardNewLvs = PlayerResources.questInventory.turn_in_cur_step(questTracker)
	if curAct != PlayerResources.questInventory.currentAct:
		act_changed.emit()
	turn_in_step_to.emit(turnInTargetName)
	load_quests_panel() # not from the toggle function, but will focus any other quests that can be turned in
	questRewardPanel.load_quest_reward_panel()
	backButton.disabled = true
	
func show_details(questTracker: QuestTracker):
	lastInteractedTracker = questTracker
	backButton.disabled = true
	questDetailsPanel.questTracker = questTracker
	questDetailsPanel.visible = true
	questDetailsPanel.load_quest_details()

func _on_in_progress_button_toggled(button_pressed):
	if button_pressed:
		filter_by(QuestTracker.Status.IN_PROGRESS)
	elif selectedFilter == QuestTracker.Status.IN_PROGRESS:
		filter_by()

func _on_ready_to_turn_in_button_toggled(button_pressed):
	if button_pressed:
		filter_by(QuestTracker.Status.READY_TO_TURN_IN_STEP)
	elif selectedFilter == QuestTracker.Status.READY_TO_TURN_IN_STEP:
		filter_by()

func _on_completed_button_toggled(button_pressed):
	if button_pressed:
		filter_by(QuestTracker.Status.COMPLETED)
	elif selectedFilter == QuestTracker.Status.COMPLETED:
		filter_by()

func _on_not_completed_button_toggled(button_pressed):
	if button_pressed:
		filter_by(QuestTracker.Status.INCOMPLETE)
	elif selectedFilter == QuestTracker.Status.INCOMPLETE:
		filter_by()

func _on_failed_button_toggled(button_pressed):
	if button_pressed:
		filter_by(QuestTracker.Status.FAILED)
	elif selectedFilter == QuestTracker.Status.FAILED:
		filter_by()

func _on_back_button_pressed():
	toggle()

func _on_quest_reward_panel_ok_pressed():
	backButton.disabled = false
	if rewardNewLvs > 0:
		level_up.emit(rewardNewLvs)
	else:
		_on_back_button_pressed()

func _on_quest_details_panel_panel_hidden():
	backButton.disabled = false
	restore_previous_focus('detailsButton')
