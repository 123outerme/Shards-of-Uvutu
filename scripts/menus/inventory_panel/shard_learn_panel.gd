extends Control
class_name ShardLearnPanel

signal learned_move(move: Move)
signal back_pressed

@export var shard: Shard = null

var combatant: Combatant = null

@onready var shardSprite: Sprite2D = get_node("Panel/ShardSpriteControl/ShardSprite")
@onready var learnPanelTitle: RichTextLabel = get_node("Panel/LearnPanelTitle")
@onready var movePoolPanel: MovePoolPanel = get_node("Panel/MovePoolPanel")
@onready var moveDetailsPanel: MoveDetailsPanel = get_node("MoveDetailsPanel")
@onready var backButton: Button = get_node("Panel/BackButton")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func load_shard_learn_panel():
	if shard == null:
		visible = false
		return
	
	backButton.grab_focus()
	combatant = Combatant.load_combatant_resource(shard.combatantSaveName)
	combatant.stats.level = PlayerResources.playerInfo.stats.level
	shardSprite.texture = shard.itemSprite
	learnPanelTitle.text = '[center]Learn a Move From ' + combatant.disp_name() + '[/center]'
	movePoolPanel.moves = combatant.stats.moves
	movePoolPanel.movepool = combatant.stats.movepool
	movePoolPanel.level = PlayerResources.playerInfo.stats.level
	movePoolPanel.load_move_pool_panel()
	movePoolPanel.show_learn_buttons(true)
	visible = true

func credit_back_shard():
	PlayerResources.inventory.add_item(shard as Item) # add the shard back to the inventory after using it up

func _on_back_button_pressed():
	visible = false
	credit_back_shard()
	back_pressed.emit()

func _on_move_pool_panel_learn_button_clicked(move: Move):
	PlayerResources.playerInfo.stats.movepool.append(move)
	visible = false
	learned_move.emit(move)

func _on_move_pool_panel_details_button_clicked(move):
	moveDetailsPanel.move = move
	moveDetailsPanel.load_move_details_panel()

func _on_move_details_panel_back_pressed():
	var focusGrabbed: bool = movePoolPanel.focus_move_details(moveDetailsPanel.move)
	if not focusGrabbed:
		backButton.grab_focus()
