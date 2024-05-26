extends Resource
class_name EnemyEncounter

enum SpecialRules {
	NONE = 0b0000,
	NO_ITEMS = 0b0001, # inventory use is disabled
	RESTAND_ON_DEFEAT = 0b0010, # revive with full HP right where you were defeated
}

@export var combatant1: Combatant = null
@export_flags('No Items:1', 'Restand On Defeat:2') var specialRules: int = SpecialRules.NONE
@export var winCon: WinCon = null

func _init(
	i_combatant1 = null,
	i_specialRules = SpecialRules.NONE,
	i_winCon = null,
):
	combatant1 = i_combatant1
	specialRules = i_specialRules
	winCon = i_winCon
	winCon = TotalDefeatWinCon.new()

func has_special_rule(rule: SpecialRules) -> bool:
	return (specialRules & rule) != 0

func get_win_con_result(combatants: Array[CombatantNode], battleState: BattleState):
	if winCon == null:
		winCon = TotalDefeatWinCon.new()
	return winCon.get_result(combatants, battleState)
