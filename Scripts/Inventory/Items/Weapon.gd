extends Item
class_name Weapon

@export var statChanges: StatChanges = StatChanges.new()
@export var timing: BattleCommand.ApplyTiming = BattleCommand.ApplyTiming.BEFORE_ROUND

func _init(
	i_sprite = null,
	i_name = "",
	i_type = Type.WEAPON,
	i_itemDescription = "",
	i_cost = 0,
	i_maxCount = 1,
	i_usable = false,
	i_battleUsable = false,
	i_consumable = false,
	i_equippable = true,
	i_targets = BattleCommand.Targets.NONE,
	i_statChanges = StatChanges.new(),
	i_timing = BattleCommand.ApplyTiming.BEFORE_ROUND,
):
	super._init(i_sprite, i_name, i_type, i_itemDescription, i_cost, i_maxCount, i_usable, i_battleUsable, i_consumable, i_equippable, i_targets)
	statChanges = i_statChanges
	timing = i_timing

func get_use_message(_target: Combatant) -> String:
	return ''

func apply_effects(target: Combatant, applyTiming: BattleCommand.ApplyTiming):
	if timing == applyTiming:
		target.statChanges.stack(statChanges)

func get_apply_text(target: Combatant, applyTiming: BattleCommand.ApplyTiming) -> String:
	if timing == applyTiming:
		var multipliers: Array[StatMultiplierText] = statChanges.get_multipliers_text()
		return target.disp_name() + ' gains ' + StatMultiplierText.multiplier_text_list_to_string(multipliers) + ' from wielding the ' + itemName + '.'
	return ''

func get_effect_text() -> String:
	var multipliers: Array[StatMultiplierText] = statChanges.get_multipliers_text()
	return 'While Equipped, ' + BattleCommand.apply_timing_to_string(timing) + ':\n' + StatMultiplierText.multiplier_text_list_to_string(multipliers)
