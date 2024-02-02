extends Panel
class_name AlertPanel

const TWEEN_ONSCREEN_TIME = 1.25
const TWEEN_OFFSCREEN_TIME = 1.25

@export var message: String = ''
@export var lifetime: float = 2
@export var alertSfx: AudioStream = null

var panelTween: Tween = null
var pauseTimer: bool = false
var lifetimeAccum: float = 0

@onready var messageLabel: RichTextLabel = get_node('MessageLabel')

# Called when the node enters the scene tree for the first time.
func _ready():
	panelTween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	position = Vector2(0, -150)
	messageLabel.text = '[center]' + message + '[/center]'
	panelTween.tween_property(self, 'position', Vector2(0, 0), TWEEN_ONSCREEN_TIME)
	panelTween.finished.connect(_show_finished)
	SceneLoader.audioHandler.play_sfx(alertSfx)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not pauseTimer and position == Vector2(0, 0) and panelTween == null:
		lifetimeAccum += delta
		if lifetimeAccum > lifetime:
			panelTween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
			panelTween.tween_property(self, 'position', Vector2(0, -150), TWEEN_OFFSCREEN_TIME)
			panelTween.finished.connect(_hide_finished)

func pause_timer():
	pauseTimer = true

func resume_timer():
	pauseTimer = false

func _show_finished():
	panelTween = null

func _hide_finished():
	queue_free()
