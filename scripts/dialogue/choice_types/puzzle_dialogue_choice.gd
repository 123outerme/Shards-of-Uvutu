extends DialogueChoice
class_name PuzzleDialogueChoice

## If true, selecting this option agrees to complete the puzzle (in case items would be used, etc.)
@export var acceptsSolve: bool = false

func _init(
	i_choiceBtn = '',
	i_storyRequirements = null,
	i_leadsTo = null,
	i_repeatsItem = false,
	i_btnDims = Vector2(80, 40),
	i_turnsInQuest: String = '',
	i_isDeclineChoice = false,
	i_acceptsSolve = false,
):
	choiceBtn = i_choiceBtn
	storyRequirements = i_storyRequirements
	leadsTo = i_leadsTo
	repeatsItem = i_repeatsItem
	buttonDims = i_btnDims
	turnsInQuest = i_turnsInQuest
	isDeclineChoice = i_isDeclineChoice
	acceptsSolve = i_acceptsSolve
