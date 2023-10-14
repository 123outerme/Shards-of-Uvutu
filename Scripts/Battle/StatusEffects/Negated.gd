extends StatusEffect
class_name Negated

var statChangesDict: Dictionary = {
	Potency.NONE: StatChanges.new(1, 0.8, 1, 1, 1),
	Potency.WEAK: StatChanges.new(1, 0.7, 1, 1, 1),
	Potency.STRONG: StatChanges.new(1, 0.6, 1, 1, 1),
	Potency.OVERWHELMING: StatChanges.new(1, 0.5, 1, 1, 1),
}

var reverseStatChangesDict: Dictionary = {
	Potency.NONE: StatChanges.new(1, 1.2, 1, 1, 1),
	Potency.WEAK: StatChanges.new(1, 1.3, 1, 1, 1),
	Potency.STRONG: StatChanges.new(1, 1.4, 1, 1, 1),
	Potency.OVERWHELMING: StatChanges.new(1, 1.5, 1, 1, 1),
}

func _init(
	i_potency = Potency.NONE,
	i_turnsLeft = 0
):
	super(Type.NEGATED, i_potency, i_turnsLeft)

func apply_status(combatant: Combatant, timing: ApplyTiming):
	if timing == ApplyTiming.BEFORE_DMG_CALC:
		combatant.statChanges.stack(statChangesDict[potency])
	if timing == ApplyTiming.AFTER_DMG_CALC:
		combatant.statChanges.stack(reverseStatChangesDict[potency])
	
func get_status_effect_str(combatant: Combatant, timing: ApplyTiming) -> String:
	return ''

func copy() -> StatusEffect:
	return Negated.new(
		potency,
		turnsLeft
	)
