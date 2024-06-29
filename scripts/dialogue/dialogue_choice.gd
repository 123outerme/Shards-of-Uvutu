extends Resource
class_name DialogueChoice

@export var choiceBtn: String = ''
@export var storyRequirements: StoryRequirements = null
@export var leadsTo: DialogueEntry = null
@export var randomDialogues: Array[WeightedDialogueEntry] = []
@export var repeatsItem: bool = false
@export var buttonDims: Vector2 = Vector2(80, 40)
@export var turnsInQuest: String = ''
@export var isDeclineChoice: bool = false

func _init(
	i_choiceBtn = '',
	i_storyRequirements = null,
	i_leadsTo = null,
	i_randomDialogues: Array[WeightedDialogueEntry] = [],
	i_repeatsItem = false,
	i_btnDims = Vector2(80, 40),
	i_turnsInQuest: String = '',
	i_isDeclineChoice = false,
):
	choiceBtn = i_choiceBtn
	storyRequirements = i_storyRequirements
	leadsTo = i_leadsTo
	randomDialogues = i_randomDialogues
	repeatsItem = i_repeatsItem
	buttonDims = i_btnDims
	turnsInQuest = i_turnsInQuest
	isDeclineChoice = i_isDeclineChoice

func is_valid():
	if storyRequirements == null:
		return true
	return storyRequirements.is_valid()
