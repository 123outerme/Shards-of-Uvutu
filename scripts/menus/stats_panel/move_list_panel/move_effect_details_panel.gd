extends Panel
class_name MoveEffectDetailsPanel

signal tooltip_panel_ok_pressed

@export var moveEffect: MoveEffect = null
@export var isSurgeEffect: bool = false

@onready var detailsTitleLabel: RichTextLabel = get_node('DetailsTitle')
@onready var moveTargets: RichTextLabel = get_node("BaseEffectPanel/MoveTargets")
@onready var movePower: RichTextLabel = get_node("BaseEffectPanel/MovePower")
@onready var moveRole: RichTextLabel = get_node("BaseEffectPanel/MoveRole")

@onready var userBoostsRow: HBoxContainer = get_node('BaseEffectPanel/VBoxContainer/UserBoostsRow')
@onready var userStatChanges: RichTextLabel = get_node("BaseEffectPanel/VBoxContainer/UserBoostsRow/UserStatChanges")

@onready var targetBoostsRow: HBoxContainer = get_node('BaseEffectPanel/VBoxContainer/TargetBoostsRow')
@onready var targetStatChanges: RichTextLabel = get_node("BaseEffectPanel/VBoxContainer/TargetBoostsRow/TargetStatChanges")

@onready var statusEffectRow: HBoxContainer = get_node('BaseEffectPanel/VBoxContainer/StatusEffectRow')
@onready var statusLabel: RichTextLabel = get_node('BaseEffectPanel/VBoxContainer/StatusEffectRow/StatusLabel')
@onready var moveStatusEffect: RichTextLabel = get_node("BaseEffectPanel/VBoxContainer/StatusEffectRow/MoveStatusEffect")
@onready var statusHelpButton: Button = get_node('BaseEffectPanel/VBoxContainer/StatusEffectRow/StatusHelpSection/StatusHelpButton')
# the statusHelpButton is fetched to to connect focus to the back button in the parent panel

@onready var surgePanel: Panel = get_node('SurgePanel')
@onready var surgeVBox: VBoxContainer = get_node('SurgePanel/VBoxContainer')

@onready var tooltipPanel: TooltipPanel = get_node('TooltipPanel')

var surgeChangesRowScene: PackedScene = preload('res://prefabs/ui/stats/surge_changes_row.tscn')

var helpButtonPressed: Button = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func load_move_effect_details_panel():
	if moveEffect == null:
		visible = false
		return
	
	for node in get_tree().get_nodes_in_group('SurgeChangesRow'):
		node.queue_free()
	
	if Combatant.useSurgeReqs == null or Combatant.useSurgeReqs.is_valid():
		detailsTitleLabel.text = '[center]' + ('Surge Effect' if isSurgeEffect else 'Charge Effect') + ' ('
		if moveEffect.orbChange > 0:
			detailsTitleLabel.text += '+'
		detailsTitleLabel.text += String.num(moveEffect.orbChange) + ' Orb'
		if abs(moveEffect.orbChange) > 1 or moveEffect.orbChange == 0:
			detailsTitleLabel.text += 's'
		if moveEffect.orbChange < 0:
			detailsTitleLabel.text += ' Min.'
		detailsTitleLabel.text += ')[/center]'
		visible = true
	else:
		if isSurgeEffect:
			visible = false
			return
		else:
			detailsTitleLabel.text = '[center]Move Effect[/center]'
	
	if moveEffect.power >= 0:
		movePower.text = str(moveEffect.power) + ' Power'
	else:
		movePower.text = str(moveEffect.power * -1) + ' Heal Power'
	moveTargets.text = '[center]Targets ' + BattleCommand.targets_to_string(moveEffect.targets) + '[/center]'
	moveRole.text = '[right]' + MoveEffect.role_to_string(moveEffect.role) + '[/right]'

	if moveEffect.selfStatChanges != null and moveEffect.selfStatChanges.has_stat_changes():
		var multipliers = moveEffect.selfStatChanges.get_multipliers_text()
		userStatChanges.text = '[center]' + StatMultiplierText.multiplier_text_list_to_string(multipliers) + '\n [/center]'
		userBoostsRow.visible = true
	else:
		userBoostsRow.visible = false
		
	if moveEffect.targetStatChanges != null and moveEffect.targetStatChanges.has_stat_changes():
		var multipliers = moveEffect.targetStatChanges.get_multipliers_text()
		targetStatChanges.text = '[center]' + StatMultiplierText.multiplier_text_list_to_string(multipliers) + '\n [/center]'
		targetBoostsRow.visible = true
	else:
		targetBoostsRow.visible = false
		
	if moveEffect.statusEffect != null:
		if moveEffect.selfGetsStatus:
			statusLabel.text = 'Status (Self):'
		else:
			statusLabel.text = 'Status (Target):'
		moveStatusEffect.text = '[center]' + StatusEffect.potency_to_string(moveEffect.statusEffect.potency) \
				+ ' ' + StatusEffect.status_type_to_string(moveEffect.statusEffect.type) \
				+ ' (' + String.num(roundi(moveEffect.statusChance * 100)) + '% Chance)[/center]'
		statusEffectRow.visible = true
	else:
		statusEffectRow.visible = false
	
	if isSurgeEffect and moveEffect.surgeChanges != null:
		var changes: Array[SurgeChanges.SurgeChangeDescRow] = moveEffect.surgeChanges.get_description()
		for change: SurgeChanges.SurgeChangeDescRow in changes:
			var row: SurgeChangesRow = surgeChangesRowScene.instantiate()
			row.changeHeader = change.title
			row.changeDetails = change.description
			surgeVBox.add_child(row)
		surgePanel.visible = true
	else:
		surgePanel.visible = false

func _on_status_help_button_pressed():
	if moveEffect.statusEffect == null:
		return
	helpButtonPressed = statusHelpButton
	tooltipPanel.title = StatusEffect.status_type_to_string(moveEffect.statusEffect.type)
	tooltipPanel.details = moveEffect.statusEffect.get_status_effect_tooltip()
	tooltipPanel.load_tooltip_panel()

func _on_tooltip_panel_ok_pressed():
	helpButtonPressed.grab_focus()
	tooltip_panel_ok_pressed.emit()
