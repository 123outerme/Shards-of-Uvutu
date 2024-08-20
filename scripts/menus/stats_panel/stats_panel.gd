extends Node2D
class_name StatsMenu

signal attempt_equip_weapon_to(stats: Stats)
signal attempt_equip_armor_to(stats: Stats)
signal back_pressed

enum TabbedViewTab {
	STATS = 0,
	EQUIPMENT = 1,
	MOVES = 2,
	MINIONS = 3,
}

@export_category("StatsPanel - Data")
## the stats to view in this panel
@export var stats: Stats = null
## the current HP from the combatant being viewed
@export var curHp: int = -1
## if true, show the level up text and newly learned move icons
@export var levelUp: bool = false
## if levelling up, how many new levels gained by the level up event
@export var newLvs: int = 0
## if true, cannot change stats, equipment, moves, etc.
@export var readOnly: bool = false
## if true, viewing the player's stats (not a minion)
@export var isPlayer: bool = false

@export_category("StatsPanel - Audio")
## when leveling up, plays this music
@export var levelUpMusic: AudioStream = null

@export_category("StatsPanel - Tab Icons")
@export var unspentStatPtsIndicator: Texture2D = null
@export var newMoveIndicator: Texture2D = null

var isTabbedView: bool = true

var isMinionStats: bool = false
var minion: Combatant = null
var savedStats: Stats = null
var savedCurHp: int = -1
var savedIsPlayer: bool = false
var changingCombatant: bool = false

var previousControl: Control = null
var previousMoveListSlot: int = -1

var statlinePanel: StatLinePanel = null
var moveListPanel: MoveListPanel = null
var equipmentPanel: EquipmentPanel = null
var minionsPanel: MinionsPanel = null

@onready var statsTitle: RichTextLabel = get_node("StatsPanel/Panel/StatsTitle")
@onready var levelUpLabel: RichTextLabel = get_node("StatsPanel/Panel/LevelUpLabel")

# --- Single-Page View ---
@onready var singleViewPanel: Panel = get_node('StatsPanel/Panel/SinglePageView')
@onready var singleViewCombatantSprite: AnimatedSprite2D = get_node("StatsPanel/Panel/SinglePageView/AnimatedCombatantSprite")
@onready var singleViewStatlinePanel: StatLinePanel = get_node("StatsPanel/Panel/SinglePageView/StatLinePanel")
@onready var singleViewMoveListPanel: MoveListPanel = get_node("StatsPanel/Panel/SinglePageView/MoveListPanel")
@onready var singleViewEquipmentPanel: EquipmentPanel = get_node("StatsPanel/Panel/SinglePageView/EquipmentPanel")
@onready var singleViewMinionsPanel: MinionsPanel = get_node("StatsPanel/Panel/SinglePageView/MinionsPanel")
@onready var singleViewBackButton: Button = get_node("StatsPanel/Panel/SinglePageView/BackButton")

# --- Tabbed View ---
@onready var tabbedViewPanel: Panel = get_node('StatsPanel/Panel/TabbedView')
@onready var tabbedViewContainer: TabContainer = get_node('StatsPanel/Panel/TabbedView/TabContainer')
@onready var tabbedViewCombatantSprite: AnimatedSprite2D = get_node('StatsPanel/Panel/TabbedView/AnimatedCombatantSprite')
@onready var tabbedViewStatlinePanel: StatLinePanel = get_node('StatsPanel/Panel/TabbedView/TabContainer/Stats/StatLinePanel')
@onready var tabbedViewMoveListPanel: MoveListPanel = get_node('StatsPanel/Panel/TabbedView/TabContainer/Moves/MoveListPanel')
@onready var tabbedViewEquipmentPanel: EquipmentPanel = get_node('StatsPanel/Panel/TabbedView/TabContainer/Equipment/EquipmentPanel')
@onready var tabbedViewMinionsPanel: MinionsPanel = get_node('StatsPanel/Panel/TabbedView/TabContainer/Minions/MinionsPanel')
@onready var tabbedViewBackButton: Button = get_node("StatsPanel/Panel/TabbedView/BackButton")

@onready var editMovesPanel: EditMovesPanel = get_node("StatsPanel/Panel/EditMovesPanel")

func _unhandled_input(event):
	if visible and event.is_action_pressed('game_decline'):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()

func toggle():
	visible = not visible
	if visible:
		load_stats_panel(true)
		initial_focus()
	else:
		close_panel()

func close_panel():
	visible = false
	equipmentPanel.itemDetailsPanel.visible = false
	moveListPanel.moveDetailsPanel.visible = false
	editMovesPanel.reset_menu_state(false)
	editMovesPanel.visible = false
	minionsPanel.end_edit_name(false)
	minionsPanel.reset_reorder_state()
	singleViewBackButton.disabled = false
	tabbedViewBackButton.disabled = false
	if isTabbedView:
		tabbedViewContainer.current_tab = TabbedViewTab.STATS
	savedStats = null
	minion = null
	back_pressed.emit()

func initial_focus():
	if isTabbedView:
		tabbedViewContainer.get_tab_bar().grab_focus()
	else:
		singleViewBackButton.grab_focus()

func restore_previous_focus():
	if previousControl == null:
		if previousMoveListSlot == -1:
			initial_focus()
		else:
			moveListPanel.get_move_list_item(previousMoveListSlot).detailsButton.grab_focus()
			previousMoveListSlot = -1
	else:
		previousControl.grab_focus()

func load_stats_panel(fromToggle: bool = false):
	if stats == null:
		return
	
	singleViewPanel.visible = not isTabbedView
	tabbedViewPanel.visible = isTabbedView
	if isTabbedView:
		statlinePanel = tabbedViewStatlinePanel
		moveListPanel = tabbedViewMoveListPanel
		equipmentPanel = tabbedViewEquipmentPanel
		minionsPanel = tabbedViewMinionsPanel
	else:
		statlinePanel = singleViewStatlinePanel
		moveListPanel = singleViewMoveListPanel
		equipmentPanel = singleViewEquipmentPanel
		minionsPanel = singleViewMinionsPanel
	
	
	if fromToggle and levelUp and \
			not SceneLoader.audioHandler.is_music_already_playing(levelUpMusic):
		SceneLoader.audioHandler.play_music(levelUpMusic, -1)
	
	var dispName: String = stats.displayName
	if minion != null:
		dispName = minion.disp_name()
	
	var spriteFrames: SpriteFrames = PlayerResources.playerInfo.combatant.get_sprite_frames()
	if minion != null:
		spriteFrames = minion.get_sprite_frames()
	
	var animatedCombatantSprite: AnimatedSprite2D = tabbedViewCombatantSprite if isTabbedView else singleViewCombatantSprite
	animatedCombatantSprite.sprite_frames = spriteFrames
	animatedCombatantSprite.play('walk')
	
	statsTitle.text = '[center]' + dispName + ' - Stats[/center]'
	levelUpLabel.visible = levelUp
	statlinePanel.stats = stats
	statlinePanel.curHp = curHp
	statlinePanel.readOnly = readOnly
	statlinePanel.levelUp = levelUp
	statlinePanel.newLvs = newLvs
	statlinePanel.load_statline_panel(changingCombatant or fromToggle)
	update_stats_tab_icon()
	moveListPanel.moves = stats.moves
	moveListPanel.movepool = stats.movepool.pool
	moveListPanel.readOnly = readOnly
	moveListPanel.level = stats.level
	moveListPanel.levelUp = levelUp
	moveListPanel.showNewMoveIndicator = levelUp and minion.stats.movepool.has_moves_at_level(minion.stats.level) \
			if minion != null else false
	moveListPanel.load_move_list_panel()
	if isTabbedView and moveListPanel.showNewMoveIndicator:
		tabbedViewContainer.set_tab_icon(TabbedViewTab.MOVES, newMoveIndicator)
	equipmentPanel.weapon = stats.equippedWeapon
	equipmentPanel.armor = stats.equippedArmor
	equipmentPanel.statsPanel = self
	equipmentPanel.load_equipment_panel()
	minionsPanel.minion = minion
	minionsPanel.readOnly = readOnly
	minionsPanel.levelUp = levelUp
	minionsPanel.load_minions_panel()
	
	if not isTabbedView:
		minionsPanel.call_deferred('connect_to_top_control', singleViewBackButton)
	else:
		var minionsControl: Control = tabbedViewContainer.get_tab_control(TabbedViewTab.MINIONS)
		if minion != null:
			minionsControl.name = minion.disp_name()
		else:
			minionsControl.name = 'Minions'
		#minionsPanel.call_deferred('connect_to_bottom_control', tabbedViewBackButton)
	changingCombatant = false

func restore_previous_stats_panel():
	stats = savedStats
	minion = null
	curHp = savedCurHp
	isPlayer = savedIsPlayer
	isMinionStats = false
	changingCombatant = true
	load_stats_panel()
	if isTabbedView:
		tabbedViewContainer.current_tab = TabbedViewTab.STATS
	restore_previous_focus()

func update_stats_tab_icon():
	if isTabbedView:
		var statsIcon: Texture2D = unspentStatPtsIndicator
		if stats.statPts == 0:
			statsIcon = null
		tabbedViewContainer.set_tab_icon(TabbedViewTab.STATS, statsIcon)

func reset_panel_to_player():
	if isMinionStats:
		restore_previous_stats_panel()

func _on_back_button_pressed():
	if not isMinionStats or savedStats == null:
		toggle()
		if SceneLoader.audioHandler.is_music_already_playing(levelUpMusic):
			if SceneLoader.mapLoader != null and SceneLoader.mapLoader.mapEntry != null:
				SceneLoader.audioHandler.cross_fade(SceneLoader.mapLoader.mapEntry.overworldTheme, -1)
			else:
				SceneLoader.audioHandler.cross_fade(null) # fade out the track
	else:
		restore_previous_stats_panel()

func _on_stat_line_panel_stats_saved() -> void:
	update_stats_tab_icon()

func _on_move_list_panel_move_details_visiblity_changed(newVisible: bool, move: Move):
	singleViewBackButton.disabled = newVisible
	tabbedViewBackButton.disabled = newVisible
	if newVisible:
		previousMoveListSlot = moveListPanel.get_index_of_move(move)
		previousControl = null
	else:
		restore_previous_focus()

func _on_minions_panel_stats_clicked(combatant: Combatant):
	previousControl = minionsPanel.get_stats_button_for(combatant)
	savedStats = stats
	savedCurHp = curHp
	savedIsPlayer = isPlayer
	if combatant != null and combatant.stats != null:
		minion = combatant
		stats = combatant.stats
		curHp = -1
		isPlayer = false
		isMinionStats = true
		changingCombatant = true
		load_stats_panel()
		if isTabbedView:
			tabbedViewContainer.current_tab = TabbedViewTab.STATS
		initial_focus()

func _on_minions_panel_minion_renamed() -> void:
	if isTabbedView:
		var minionsControl: Control = tabbedViewContainer.get_tab_control(TabbedViewTab.MINIONS)
		minionsControl.name = minion.disp_name()

func _on_minions_panel_minion_auto_alloc_changed(combatant: Combatant) -> void:
	# the minion changed should never not be the minion being inspected, but just in case, do nothing
	# same is true with the stats copy being empty
	if minion != combatant or statlinePanel.statsCopy == null:
		return
	if statlinePanel.statsCopy.statPts > 0 and combatant.should_auto_alloc_stat_pts():
		var statAllocStrategy: StatAllocationStrategy = combatant.get_stat_allocation_strategy()
		if statAllocStrategy != null:
			# allocate to the statlinePanel's stats copy
			statAllocStrategy.allocate_stats(statlinePanel.statsCopy)
			# reload the statline panel with it appearing as modified (not auto-confirming it just in case the player doesn't want it)
			statlinePanel.modified = true
			statlinePanel.load_statline_panel()
		else:
			printerr('Minion ', combatant.save_name(), ' has no defined stat allocation strategy and is being auto-allocated after setting was switched')

func _on_move_list_panel_edit_moves():
	previousControl = moveListPanel.editMovesButton
	editMovesPanel.moves = stats.moves
	editMovesPanel.movepool = stats.movepool.pool
	editMovesPanel.level = stats.level
	editMovesPanel.levelUp = levelUp
	editMovesPanel.load_edit_moves_panel()
	singleViewBackButton.disabled = true
	tabbedViewBackButton.disabled = true

func _on_edit_moves_panel_back_pressed():
	singleViewBackButton.disabled = false
	tabbedViewBackButton.disabled = false
	restore_previous_focus()

func _on_edit_moves_panel_replace_move(slot: int, newMove: Move):
	if slot >= len(stats.moves):
		for i in range(4):
			if slot == i:
				stats.moves.append(newMove)
			elif i >= len(stats.moves):
				stats.moves.append(null)
	else:
		stats.moves[slot] = newMove
	editMovesPanel.movePoolPanel.moves = stats.moves
	editMovesPanel.load_edit_moves_panel(true, false)
	load_stats_panel()

func _on_equipment_panel_attempt_equip_weapon():
	if not readOnly:
		pass #attempt_equip_weapon_to.emit(stats)

func _on_equipment_panel_attempt_equip_armor():
	if not readOnly:
		pass #attempt_equip_armor_to.emit(stats)

func _on_inventory_panel_node_open_stats(combatant: Combatant):
	stats = combatant.stats
	if combatant == PlayerResources.playerInfo.combatant:
		isPlayer = true
		isMinionStats = false
	else:
		isPlayer = false
		isMinionStats = true
		minion = combatant
	curHp = combatant.currentHp
	toggle()
