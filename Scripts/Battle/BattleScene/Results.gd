extends Control
class_name Results

var battleUI: BattleUI = null

@onready var textBoxText: RichTextLabel = get_node("TextBoxText")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func show_text(newText: String):
	textBoxText.text = newText
