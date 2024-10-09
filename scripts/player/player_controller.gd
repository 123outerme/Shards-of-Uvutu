extends CharacterBody2D
class_name PlayerController

const BASE_SPEED = 80
const RUN_SPEED = 120
# cooldowns calculated from animation framerate and "step" frame timings
const BASE_STEP_SFX_COOLDOWN: float = 0.5714
const RUN_STEP_SFX_COOLDOWN: float = 0.3636

@export var disableMovement: bool
@export var facingLeft: bool = false
@export var teleportSfx: AudioStream = null
@export var stepSfx: Array[AudioStream] = []

var speed = BASE_SPEED
var interactableDialogues: Array[InteractableDialogue] = []
var interactableDialogueIndex: int = 0
var inCutscene: bool = false
var cutsceneTexts: Array[CutsceneDialogue] = []
var cutsceneTextIndex: int = 0
var cutsceneLineIndex: int = 0
var holdCameraX: bool = false
var holdCameraY: bool = false
var holdingCameraAt: Vector2
var makingChoice: bool = false
var pickedChoice: DialogueChoice = null
var actChanged: bool = false
var pauseDisabled: bool = false
var cutscenePaused: bool = false
var startingBattle: bool = false
var enteredWarpZone: bool = false
var walkBackwards: bool = false ## flips the walking direction to face backwards from the direction of travel

@onready var collider: CollisionShape2D = get_node("ColliderShape")
@onready var sprite: AnimatedSprite2D = get_node("AnimatedPlayerSprite")
@onready var eventCollider: CollisionShape2D = get_node('PlayerEventCollider/EventColliderShape')
@onready var cam: PlayerCamera = get_node("Camera")
@onready var uiRoot: Node2D = get_node('UI')
@onready var overworldTouchControls: OverworldTouchControls = get_node('UI/OverworldTouchControls')
@onready var textBox: TextBox = get_node("UI/TextBoxRoot")
@onready var animatedBgPanel: AnimatedBgPanel = get_node('UI/AnimatedBgPanel')
@onready var inventoryPanel: InventoryMenu = get_node("UI/InventoryPanelNode")
@onready var questsPanel: QuestsMenu = get_node("UI/QuestsPanelNode")
@onready var statsPanel: StatsMenu = get_node("UI/StatsPanelNode")
@onready var pausePanel: PauseMenu = get_node("UI/PauseMenu")
@onready var overworldConsole: OverworldConsole = get_node('UI/OverworldConsole')

var talkNPC: NPCScript = null
var talkNPCcandidates: Array[NPCScript] = []
var interactables: Array[Interactable] = []
var running: bool = false
var interactable: Interactable = null
var useTeleportStone: TeleportStone = null
# play a step immediately when moving the next time
var stepSfxTimer: float = BASE_STEP_SFX_COOLDOWN
var lastStepIdx: int = -1

var sprite_modulate: Color:
	get:
		if sprite == null:
			return Color()
		return sprite.self_modulate
	set(c):
		if sprite != null:
			sprite.self_modulate = c

func _unhandled_input(event):
	if cam.fadedOrFadingOut:
		# if the game is faded out or is fading out, prevent any input
		return
	
	if event.is_action_pressed('game_decline') and SettingsHandler.gameSettings.toggleRun \
			and not (talkNPC != null or len(interactableDialogues) > 0 or len(cutsceneTexts) > 0) \
			and not pausePanel.isPaused and not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not overworldConsole.visible and not makingChoice and \
			not cutscenePaused and not inCutscene and SceneLoader.curMapEntry.isRecoverLocation \
			and (SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading):
		running = not running # toggle running when press decline and not in a menu/dialogue/cutscene and in a runnable place
	
	if (not pauseDisabled and event.is_action_pressed("game_pause")) or \
			(cutscenePaused and event.is_action_pressed('game_decline')) and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading):
		if inCutscene:
			# if awaiting player, don't even check if the pause panel can be opened, just stop here
			if not SceneLoader.cutscenePlayer.awaitingPlayer:
				SceneLoader.cutscenePlayer.toggle_pause_cutscene()
				cam.toggle_cutscene_paused_shade()
				cutscenePaused = cam.cutscenePaused
		elif not statsPanel.visible and not inventoryPanel.visible and not questsPanel.visible:
			animatedBgPanel.visible = true
			pausePanel.toggle_pause()
			overworldTouchControls.set_all_visible(not pausePanel.visible)
	
	if event.is_action_pressed("game_stats") and not inCutscene and not pausePanel.isPaused and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading) and \
			not inventoryPanel.inShardLearnTutorial and not overworldConsole.visible:
		statsPanel.stats = PlayerResources.playerInfo.combatant.stats
		statsPanel.curHp = PlayerResources.playerInfo.combatant.currentHp
		animatedBgPanel.visible = true
		statsPanel.toggle()
		if statsPanel.visible:
			SceneLoader.pause_autonomous_movers()
		if inventoryPanel.visible:
			inventoryPanel.toggle()
		if questsPanel.visible:
			questsPanel.toggle()
		overworldTouchControls.set_all_visible(not statsPanel.visible)
	
	var mobileNotInDialogue: bool = SettingsHandler.isMobile and not textBox.visible
	if (event.is_action_pressed("game_interact") or event.is_action_pressed("game_decline") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed() and not mobileNotInDialogue)) \
			and (len(interactables) > 0 or len(talkNPCcandidates) > 0 or len(cutsceneTexts) > 0) \
			and not pausePanel.isPaused and not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not overworldConsole.visible and not makingChoice and \
			not cutscenePaused and not startingBattle and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading):
		if len(interactables) > 0 and not textBox.visible and (event.is_action_pressed("game_interact") or event is InputEventMouseButton):
			# if the text box isn't open and there's at least one nearby interactable:
			# find the closest interactable (using squared distance bc faster; the distance only matters relative to other interactables)
			var closestInteractable: Interactable = null
			interactables = interactables.filter(_filter_out_null)
			interactables.sort_custom(_sort_interactables)
			for inter: Interactable in interactables:
				if (closestInteractable == null or \
						(inter.global_position - global_position).length_squared() < (closestInteractable.global_position - global_position).length_squared()):
					closestInteractable = inter
			if closestInteractable != null:
				closestInteractable.interact()
		elif textBox.is_textbox_complete():
			advance_dialogue(event.is_action_pressed("game_interact") or event is InputEventMouseButton)
		elif textBox.visible:
			textBox.show_text_instant()
	
	if event.is_action_pressed("game_inventory") and not inCutscene and not pausePanel.isPaused and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading) and \
			not inventoryPanel.inShardLearnTutorial and not overworldConsole.visible:
		inventoryPanel.inShop = false
		inventoryPanel.showPlayerInventory = false
		inventoryPanel.lockFilters = false
		animatedBgPanel.visible = true
		inventoryPanel.toggle()
		if inventoryPanel.visible:
			SceneLoader.pause_autonomous_movers()
		if statsPanel.visible:
			statsPanel.toggle()
		if questsPanel.visible:
			questsPanel.toggle()
		overworldTouchControls.set_all_visible(not inventoryPanel.visible)
		
	if event.is_action_pressed("game_quests") and not inCutscene and not pausePanel.isPaused and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading) and \
			not inventoryPanel.inShardLearnTutorial and not overworldConsole.visible:
		questsPanel.turnInTargetName = ''
		questsPanel.lockFilters = false
		animatedBgPanel.visible = true
		animatedBgPanel.visible = true
		questsPanel.toggle()
		if questsPanel.visible:
			SceneLoader.pause_autonomous_movers()
		if statsPanel.visible:
			statsPanel.toggle()
		if inventoryPanel.visible:
			inventoryPanel.toggle()
		overworldTouchControls.set_all_visible(not questsPanel.visible)
			
	if event.is_action_pressed('game_console') and not pausePanel.isPaused and \
			not inventoryPanel.inShardLearnTutorial and not textBox.visible and \
			(SceneLoader.mapLoader == null or not SceneLoader.mapLoader.loading) and \
			SceneLoader.debug:
		overworldConsole.load_overworld_console()
		SceneLoader.pause_autonomous_movers()
		if statsPanel.visible:
			statsPanel.toggle()
		if inventoryPanel.visible:
			inventoryPanel.toggle()
		if questsPanel.visible:
			questsPanel.toggle()
		overworldTouchControls.set_all_visible(false)
	
func _physics_process(_delta):
	if (Input.is_action_pressed("game_decline") or running) and (SceneLoader.mapLoader != null and SceneLoader.mapLoader.mapEntry.isRecoverLocation):
		if speed != RUN_SPEED:
			# play a step sound the next frame (for animation change when moving and switching run status)
			stepSfxTimer = RUN_STEP_SFX_COOLDOWN
			overworldTouchControls.set_running(true)
		speed = RUN_SPEED
	elif speed != BASE_SPEED:
		speed = BASE_SPEED
		# play a step sound the next frame (for animation change when moving and switching run status) 
		stepSfxTimer = BASE_STEP_SFX_COOLDOWN
		overworldTouchControls.set_running(false)
	
	# if movement isn't explictly disabled and the camera is faded out or fading out: movement is enabled
	if not disableMovement and not cam.fadedOrFadingOut:
		# omni-directional movement
		#velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized() * speed
		# eight-directional movement (smart - snap to nearest 45 deg line)
		velocity = eight_dir_movement(Input.get_vector("move_left", "move_right", "move_up", "move_down")) * speed
		if velocity.x < 0:
			facingLeft = true
		if velocity.x > 0:
			facingLeft = false
		sprite.flip_h = facingLeft
		if velocity.length() > 0:
			if speed == RUN_SPEED:
				play_animation('run')
			else:
				play_animation('walk')
		else:
			play_animation('stand')
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if inCutscene and false: # debug mode move camera in cutscene
		var vel = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized() * speed
		cam.position += vel * _delta
		
func _process(delta):
	if holdCameraX:
		cam.position.x = holdingCameraAt.x - position.x
		uiRoot.position.x = holdingCameraAt.x - position.x
	if holdCameraY:
		cam.position.y = holdingCameraAt.y - position.y
		uiRoot.position.y = holdingCameraAt.y - position.y
	# placed here instead of _physics_process because graphics are updated in sync with _process
	if velocity.length_squared() > 0:
		stepSfxTimer += delta
		if stepSfxTimer > (RUN_STEP_SFX_COOLDOWN if speed == RUN_SPEED else BASE_STEP_SFX_COOLDOWN):
			# don't choose the SFX we last picked
			var stepChoiceIdxs: Array = range(len(stepSfx))
			if lastStepIdx != -1:
				stepChoiceIdxs.remove_at(lastStepIdx)
			if len(stepChoiceIdxs) > 0:
				lastStepIdx = stepChoiceIdxs.pick_random() as int
			else:
				lastStepIdx = 0
			SceneLoader.audioHandler.play_sfx(stepSfx[lastStepIdx])
			stepSfxTimer = 0
	else:
		# play a step sound the next time the player moves
		stepSfxTimer = BASE_STEP_SFX_COOLDOWN

func eight_dir_movement(input: Vector2) -> Vector2:
	var output: Vector2 = Vector2.ZERO
	if input == output:
		return output
	
	var dirNum = ceili((input.angle() - PI / 8) / (PI / 4))
	# angle is [-180, -180] degrees
	# x - 22.5 degrees / 45 degrees => [-4, 4]
	if dirNum > -2 and dirNum < 2: # -1, 0, 1 => +x
		output.x = 1
	if abs(dirNum) == 3 or abs(dirNum) == 4 or dirNum == 3: # -3, -4, 4, 3 => -x
		output.x = -1
	if dirNum > 0 and dirNum < 4: # 1, 2, 3 => +y
		output.y = 1
	if dirNum < 0 and dirNum > -4: # -1, -2, -3 => -y
		output.y = -1
	
	return output.normalized()

func set_sprite_frames(spriteFrames: SpriteFrames):
	sprite.sprite_frames = spriteFrames

func disable_collision():
	collider.set_deferred('disabled', true)

func enable_collision():
	collider.set_deferred('disabled', false)

func is_collision_enabled():
	return not collider.disabled

func disable_event_collisions():
	eventCollider.disabled = true

func enable_event_collisions():
	eventCollider.disabled = false

func play_animation(animation: String):
	sprite.play(animation)

func face_horiz(xDirection: float):
	if xDirection > 0:
		# walking to the right:
		# flip = false if not walking backwards
		facingLeft = walkBackwards
		sprite.flip_h = walkBackwards
	if xDirection < 0:
		# walking to the left:
		# flip = true if not walking backwards
		facingLeft = not walkBackwards
		sprite.flip_h = not walkBackwards

func repeat_dialogue_item():
	if talkNPC == null:
		return
	talkNPC.repeat_dialogue_item()
	var dialogueText: String = talkNPC.get_cur_dialogue_string()
	textBox.advance_textbox(dialogueText, talkNPC.is_dialogue_item_last())

func advance_dialogue(canStart: bool = true):
	if len(talkNPCcandidates) > 0 and not inCutscene: # if in NPC conversation
		if talkNPC == null:
			var minDistance: float = -1.0
			for npc in talkNPCcandidates:
				if npc == null:
					continue
				npc.reset_dialogue()
				if (npc.position.distance_to(position) < minDistance or minDistance == -1.0) and \
						len(npc.data.dialogueItems) > 0 and npc.visible: # if the NPC has dialogue and is the closest visible NPC, speak to this one
					minDistance = npc.position.distance_to(position)
					talkNPC = npc
					PlayerResources.playerInfo.encounter = null # reset static encounter in case game crash
		play_animation('stand')
		if not canStart and not disableMovement or talkNPC == null: # if we are pressing game_decline, or there is no talk NPC, do not start conversation!
			talkNPC = null
			return
		var hasDialogue: bool = talkNPC.advance_dialogue()
		if not hasDialogue:
			talkNPC = null
			return
		
		var dialogueItem: DialogueItem = talkNPC.get_cur_dialogue_item()
		var dialogueText: String = talkNPC.get_cur_dialogue_string()
		if dialogueItem != null: # if there is NPC dialogue to display
			if talkNPC.data.dialogueIndex == 0: # if this is the beginning of the NPC dialogue
				SceneLoader.pause_autonomous_movers()
				#SceneLoader.unpauseExcludedMover = talkNPC
				textBox.set_textbox_text(dialogueText, talkNPC.displayName if dialogueItem.speakerOverride == '' else dialogueItem.speakerOverride, talkNPC.is_dialogue_item_last())
				face_horiz(talkNPC.talkArea.global_position.x - global_position.x)
				for npc in talkNPCcandidates:
					if npc != talkNPC:
						npc.talkAlertSprite.visible = false
			else: # this is continuing the NPC dialogue
				textBox.advance_textbox(dialogueText, talkNPC.is_dialogue_item_last())
		elif not inCutscene: # this is the end of NPC dialogue and it didn't start a cutscene
			textBox.hide_textbox()
			SceneLoader.unpause_autonomous_movers()
			for npc in talkNPCcandidates:
				if len(npc.data.dialogueItems) > 0:
					npc.talkAlertSprite.visible = true
			talkNPC = null
			if PlayerResources.playerInfo.encounter != null:
				start_battle()
			if actChanged:
				pause_movement()
				cam.play_new_act_animation(_new_act_callback)
		else:
			textBox.hide_textbox() # is this necessary??
			set_talk_npc(null, true) # is this necessary??
	elif len(interactableDialogues) > 0: # interactable dialogue
		put_interactable_text(true)
	if len(cutsceneTexts) > 0: # cutscene dialogue
		cutsceneLineIndex += 1
		if cutsceneLineIndex >= len(cutsceneTexts[cutsceneTextIndex].texts): # if this dialogue item is done, move to the next
			cutsceneLineIndex = 0
			cutsceneTextIndex += 1
			if cutsceneTextIndex >= len(cutsceneTexts): # if there are no more dialogue items, close the textbox
				cutsceneTextIndex = 0
				cutsceneTexts = []
				textBox.hide_textbox()
				if not inCutscene: # cutscene is over now (ended while text box was still open)
					unpause_movement()
					cam.show_letterbox(false) # disable letterbox
			else: # otherwise show the new dialogue item
				textBox.set_textbox_text(cutsceneTexts[cutsceneTextIndex].texts[cutsceneLineIndex], cutsceneTexts[cutsceneTextIndex].speaker, cutsceneLineIndex == len(cutsceneTexts[cutsceneTextIndex].texts) - 1 and cutsceneTextIndex == len(cutsceneTexts) - 1)
				SceneLoader.audioHandler.play_sfx(cutsceneTexts[cutsceneTextIndex].textboxSfx)
		else: # if it's not done, advance the textbox
			textBox.advance_textbox(cutsceneTexts[cutsceneTextIndex].texts[cutsceneLineIndex], cutsceneLineIndex == len(cutsceneTexts[cutsceneTextIndex].texts) - 1 and cutsceneTextIndex == len(cutsceneTexts) - 1)

func select_choice(choice: DialogueChoice):
	makingChoice = false
	
	if choice.turnsInQuest:
		makingChoice = true # leave choice buttons up for now
		pickedChoice = choice
		_on_turn_in_button_pressed()
		return

	if interactable != null:
		interactable.select_choice(choice)
		return
	
	if choice is NPCDialogueChoice:
		var npcChoice: NPCDialogueChoice = choice as NPCDialogueChoice
		if npcChoice.opensShop:
			makingChoice = true # leave choice buttons up for now
			pickedChoice = choice
			_on_shop_button_pressed()
			return
		
	if choice.repeatsItem:
		talkNPC.repeat_dialogue_item()
		var dialogueItem: DialogueItem = talkNPC.get_cur_dialogue_item()
		var dialogueText: String = talkNPC.get_cur_dialogue_string()
		textBox.set_textbox_text(dialogueText, talkNPC.displayName if dialogueItem.speakerOverride == '' else dialogueItem.speakerOverride, talkNPC.is_dialogue_item_last())
		return
	
	var leadsTo: DialogueEntry = null
	if choice.returnsToParentId != '':
		var parentIdx: int = -1
		for dialogueEntryIdx in range(len(talkNPC.data.dialogueItems)):
			var dialogueEntry: DialogueEntry = talkNPC.data.dialogueItems[dialogueEntryIdx]
			if dialogueEntry.entryId == choice.returnsToParentId:
				parentIdx = dialogueEntryIdx
				break
		if parentIdx > -1:
			var parentDialogueEntry: DialogueEntry = talkNPC.data.dialogueItems[parentIdx]
			var prevLen: int = len(talkNPC.data.dialogueItems)
			talkNPC.data.dialogueItems.erase(parentDialogueEntry)
			# if the dialogue entry was erased and it was before our current index, update the index of the current dialogue!
			if prevLen != len(talkNPC.data.dialogueItems) and parentIdx <= talkNPC.data.dialogueIndex:
				talkNPC.data.dialogueIndex -= 1
			
			leadsTo = parentDialogueEntry
	
	if leadsTo == null and choice.randomDialogues != null and len(choice.randomDialogues) > 0:
		var randomDialogues: Array[WeightedDialogueEntry] = []
		var sumWeights: float = 0
		for dialogue in choice.randomDialogues:
			if dialogue.dialogueEntry.can_use_dialogue():
				randomDialogues.append(dialogue)
				sumWeights += dialogue.weight
		
		var randomIdx: int = WeightedThing.pick_item(randomDialogues, sumWeights)
		if randomIdx > -1:
			leadsTo = choice.randomDialogues[randomIdx].dialogueEntry
	
	if leadsTo == null:
		leadsTo = choice.leadsTo
	
	if leadsTo != null:
		var reused = talkNPC.add_dialogue_entry_in_dialogue(leadsTo)
		# skip any remaining dialogue we might have here
		talkNPC.data.dialogueItemIdx = len(talkNPC.data.dialogueItems[talkNPC.data.dialogueIndex].items) - 1
		talkNPC.data.dialogueLine = len(talkNPC.data.dialogueItems[talkNPC.data.dialogueIndex].items[talkNPC.data.dialogueItemIdx].lines) - 1
		if reused:
			talkNPC.data.dialogueLine = 0
			var dialogueItem: DialogueItem = talkNPC.get_cur_dialogue_item()
			var dialogueText: String = talkNPC.get_cur_dialogue_string()
			textBox.set_textbox_text(dialogueText, talkNPC.displayName if dialogueItem.speakerOverride == '' else dialogueItem.speakerOverride, talkNPC.is_dialogue_item_last())
			return
	
	makingChoice = false
	advance_dialogue()

func is_in_dialogue() -> bool:
	return textBox.visible

func set_talk_npc(npc: NPCScript, remove: bool = false):
	if npc == null:
		for candidate in talkNPCcandidates:
			candidate.reset_dialogue()
		talkNPCcandidates = []
		talkNPC = null
		return
	
	if npc in talkNPCcandidates and remove:
			talkNPCcandidates.erase(npc)
			npc.reset_dialogue()
			if not inCutscene:
				textBox.hide_textbox()
				disableMovement = false
	if not npc in talkNPCcandidates and not remove:
		talkNPCcandidates.append(npc)
	update_interact_touch_ui()
	
func restore_dialogue(npc: NPCScript):
	var dialogueItem: DialogueItem = npc.get_cur_dialogue_item()
	var dialogueText: String = npc.get_cur_dialogue_string()
	if dialogueItem != null and talkNPC == null:
		if not npc in talkNPCcandidates:
			talkNPCcandidates.append(npc)
		talkNPC = npc
		talkNPC.face_player()
		talkNPC.talkAlertSprite.visible = true
		SceneLoader.pause_autonomous_movers()
		pause_movement()
		textBox.set_textbox_text(dialogueText, talkNPC.displayName if dialogueItem.speakerOverride == '' else dialogueItem.speakerOverride, talkNPC.is_dialogue_item_last())
		textBox.show_text_instant()

func show_all_talk_alert_sprites():
	for candidate in talkNPCcandidates:
		candidate.talkAlertSprite.visible = true

func restore_interactable_dialogue(dialogues: Array[InteractableDialogue]):
	await get_tree().process_frame # wait for nearby interactables to register with the player
	await get_tree().process_frame # wait for nearby interactables to register with the player
	interactableDialogues.append_array(dialogues)
	if len(interactableDialogues) > 0:
		interactable = null
		for inter: Interactable in interactables:
			if inter.saveName == PlayerResources.playerInfo.interactableName:
				interactable = inter
				break
		
		if interactable != null:
			face_horiz(interactable.global_position.x - global_position.x)
			SceneLoader.pause_autonomous_movers()
			put_interactable_text(false, true)
			textBox.show_text_instant()
		else:
			printerr('Restore Interactable Dialogue error: could not find interactable to restore for')
			interactableDialogues = []
			interactableDialogueIndex = 0

func pause_movement():
	disableMovement = true

func unpause_movement():
	disableMovement = textBox.visible or inCutscene
	
func hold_camera_at(pos: Vector2, holdX = true, holdY = true):
	if holdCameraX or holdCameraY:
		return
	if cam.position != Vector2(0, 0):
		return
	holdingCameraAt = pos
	holdCameraX = holdX
	holdCameraY = holdY

func snap_camera_back_to_player(duration: float = 0.5):
	if not holdCameraX and not holdCameraY:
		return # camera is already headed back to player
	holdCameraX = false
	holdCameraY = false
	if duration > 0:
		create_tween().tween_property(cam, 'position', Vector2(0, 0), duration)
		create_tween().tween_property(uiRoot, 'position', Vector2(0, 0), duration)
	else:
		cam.position = Vector2(0, 0)
		uiRoot.position = Vector2(0, 0)

func pick_up(groundItem: GroundItem):
	groundItem.show_pick_up_sprite(false)
	
	if PlayerResources.playerInfo.has_picked_up(groundItem.saveName):
		return
	
	interactableDialogues.append(groundItem.pickedUpItem)
	groundItem.pickedUpItem.wasPickedUp = PlayerResources.inventory.can_add_item(groundItem.pickedUpItem.item)
	if groundItem.pickedUpItem.wasPickedUp:
		#PlayerResources.playerInfo.pickedUpItems.append(groundItem.saveName)
		groundItem.visible = false
	
	groundItem.pickedUpItem.savedTextIdx = 0
	play_animation('stand')
	interactable = groundItem
	# don't advance, and if this is up next, play the animation
	put_interactable_text(false, interactableDialogues[interactableDialogueIndex] == groundItem.pickedUpItem)

func interact_interactable(inter: Interactable, dialogue: InteractableDialogue = null):
	var interDialogue: InteractableDialogue = dialogue
	if interDialogue == null:
		interDialogue = inter.dialogue
	if interDialogue != null:
		interactable = inter
		interactableDialogues.append(interDialogue)
		# if this one is up next, play the animation
		put_interactable_text(false, interactableDialogues[interactableDialogueIndex] == interDialogue)
		play_animation('stand')

func put_interactable_text(advance: bool = false, playDialogueAnim: bool = false):
	var hasNextDialogue: bool = true
	
	var interactableDialogue: InteractableDialogue = null
	if interactableDialogueIndex < len(interactableDialogues):
		interactableDialogue = interactableDialogues[interactableDialogueIndex]
	
	# if we're advancing, check if this needs to be played (DialogueItem is advancing)
	# if not advancing, only play the dialogue if selected
	var playDialogueItemAnim: bool = not advance and playDialogueAnim
	if advance:
		interactableDialogue.savedTextIdx += 1
		# if this current DialogueItem is done: advance the item
		if interactableDialogue.savedTextIdx >= len(interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].lines):
			interactableDialogue.savedTextIdx = 0
			interactableDialogue.savedItemIdx += 1
			playDialogueItemAnim = true
			# if this current DialogueEntry is done: first process the entry options, then advance the entry
			if interactableDialogue.savedItemIdx >= len(interactableDialogue.dialogueEntry.items):
				interactableDialogue.savedItemIdx = 0
				if interactable.saveName != '' and interactableDialogue.dialogueEntry.entryId != '':
					PlayerResources.playerInfo.set_dialogue_seen(interactable.saveName, interactableDialogue.dialogueEntry.entryId)
				var startingCutscene: bool = false
				if interactableDialogue.dialogueEntry.startsCutscene != null:
					SceneLoader.cutscenePlayer.start_cutscene(interactableDialogue.dialogueEntry.startsCutscene)
					startingCutscene = true
				if interactableDialogue.dialogueEntry.closesDialogue or startingCutscene:
					interactableDialogueIndex = len(interactableDialogues) # set to the last entry
				if interactableDialogue.dialogueEntry.entryId != '' and interactable.saveName != '':
					# attempt to progress Talk quest(s) that require this NPC and dialogue item
					PlayerResources.questInventory.progress_quest(interactable.saveName + '#' + interactableDialogue.dialogueEntry.entryId, QuestStep.Type.TALK)
				if interactableDialogue.dialogueEntry.givesItem:
					PlayerResources.inventory.add_item(interactableDialogue.dialogueEntry.givesItem)
					cam.show_alert('Got Item:\n' + interactableDialogue.dialogueEntry.givesItem.itemName, interactableDialogue.dialogueEntry.givesItem.itemSprite)
				if interactableDialogue.dialogueEntry.fullHealsPlayer:
					PlayerResources.playerInfo.combatant.currentHp = PlayerResources.playerInfo.combatant.stats.maxHp
					cam.show_alert('Fully Healed!')
				if interactableDialogue.dialogueEntry.startsStaticEncounter != null: # if it starts a static encounter (auto-closes dialogue)
					PlayerResources.playerInfo.encounter = interactableDialogue.dialogueEntry.startsStaticEncounter
					interactableDialogueIndex = len(interactableDialogues) # set to the last entry
				
				interactableDialogueIndex += 1
				while interactableDialogueIndex < len(interactableDialogues) and not interactableDialogues[interactableDialogueIndex].dialogueEntry.can_use_dialogue():
					interactableDialogueIndex += 1 # skip dialogues that cannot be used
				# update what the interactable dialogue is pointing to
				if interactableDialogueIndex >= len(interactableDialogues):
					hasNextDialogue = false
					interactableDialogue = null
				else:
					interactableDialogue = interactableDialogues[interactableDialogueIndex]
	if interactableDialogue != null:
		if playDialogueItemAnim and interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].animation != '':
			interactable.play_animation(interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].animation)
		if interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].actorAnimation != '':
			if interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].animateActorIsPlayer:
				play_animation(interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].actorAnimation)
			else:
				var node: Node = SceneLoader.cutscenePlayer.fetch_actor_node(interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].animateActorTreePath, false)
				if node != null:
					if node.has_method('play_animation'):
						node.play_animation(interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx].actorAnimation)
					else:
						print('Actor ' , node.name, ' was asked to play an animation but it doesn\'t implement play_animation()')
	
	# if not null, check and then show the dialogue
	if interactableDialogue != null and interactableDialogue.dialogueEntry != null:
		var speaker: String = interactableDialogue.speaker
		if interactableDialogue is PickedUpItem:
			var pickedUpItem: PickedUpItem = interactableDialogue as PickedUpItem
			speaker = 'Picked Up ' + pickedUpItem.item.itemName
			if not pickedUpItem.wasPickedUp:
				# if the dialogue was advanced at all, the "too full" message was closed
				if pickedUpItem.savedTextIdx > 0:
					hasNextDialogue = false
				else:
					textBox.dialogueItem = null
					textBox.set_textbox_text('Your inventory is too full for this ' + pickedUpItem.item.itemName + '!', 'Inventory Full')
				return

		textBox.dialogueItem = interactableDialogue.dialogueEntry.items[interactableDialogue.savedItemIdx]
		textBox.set_textbox_text(textBox.dialogueItem.lines[interactableDialogue.savedTextIdx], speaker if textBox.dialogueItem.speakerOverride == '' else textBox.dialogueItem.speakerOverride, interactableDialogue.savedItemIdx == len(interactableDialogue.dialogueEntry.items) - 1 and interactableDialogue.savedTextIdx >= len(textBox.dialogueItem.lines) - 1)
	else:
		hasNextDialogue = false
	
	if not hasNextDialogue:
		textBox.hide_textbox()
		SceneLoader.unpause_autonomous_movers()
		if interactable != null:
			interactable.finished_dialogue()
		interactableDialogue = null
		interactableDialogues = []
		interactableDialogueIndex = 0
		interactable = null
	else:
		SceneLoader.pause_autonomous_movers()

func update_interact_touch_ui():
	if len(interactables) > 0 or len(talkNPCcandidates) > 0:
		var oneHasDialogue: bool = false
		for inter: Interactable in interactables:
			if inter == null:
				continue
			if inter.has_dialogue():
				oneHasDialogue = true
				break
		if not oneHasDialogue:
			for npc: NPCScript in talkNPCcandidates:
				if npc == null:
					continue
				if len(npc.data.dialogueItems) > 0:
					oneHasDialogue = true
					break
		
		if oneHasDialogue:
			overworldTouchControls.set_interact_available(true)
			return
	overworldTouchControls.set_interact_available(false)

func queue_cutscene_texts(cutsceneDialogue: CutsceneDialogue):
	cutsceneTexts.append(cutsceneDialogue)
	if not textBox.visible:
		cutsceneTextIndex = len(cutsceneTexts) - 1
		cutsceneLineIndex = 0
		textBox.set_textbox_text(cutsceneTexts[cutsceneTextIndex].texts[cutsceneLineIndex], cutsceneTexts[cutsceneTextIndex].speaker, cutsceneLineIndex == len(cutsceneTexts[cutsceneTextIndex].texts) - 1 and cutsceneTextIndex == len(cutsceneTexts) - 1)
		SceneLoader.audioHandler.play_sfx(cutsceneTexts[cutsceneTextIndex].textboxSfx)

func fade_in_unlock_cutscene(cutscene: Cutscene): # for use when faded-out cutscene must end after loading back in
	inCutscene = false
	cam.connect_to_fade_in(_fade_in_force_unlock_cutscene.bind(cutscene.saveName))

func get_collider(): # for use before full player initialization in MapLoader
	return get_node('ColliderShape')

func menu_closed():
	if not inventoryPanel.visible and not questsPanel.visible and \
			not statsPanel.visible and not pausePanel.visible:
		animatedBgPanel.visible = false
		if not textBox.visible:
			SceneLoader.unpause_autonomous_movers()
			overworldTouchControls.set_all_visible()
			if useTeleportStone != null:
				play_animation('teleport')
				SceneLoader.audioHandler.play_sfx(teleportSfx)
				disableMovement = true
				await get_tree().create_timer(0.5).timeout
				if not SceneLoader.mapLoader.loading:
					SceneLoader.mapLoader.entered_warp(useTeleportStone.targetMap, useTeleportStone.targetPos, position)

func start_battle():
	if startingBattle:
		return
	startingBattle = true
	# save to auto-save
	cam.fade_out(_after_start_battle_fade_out)
	PlayerResources.battleSaveFolder = ''
	var playingBattleMusic = SceneLoader.mapLoader.mapEntry.battleMusic.pick_random()
	if PlayerResources.playerInfo.encounter is StaticEncounter and (PlayerResources.playerInfo.encounter as StaticEncounter).battleMusic != null:
		playingBattleMusic = (PlayerResources.playerInfo.encounter as StaticEncounter).battleMusic
	SceneLoader.audioHandler.play_music(playingBattleMusic, -1)

func _on_shop_button_pressed():
	#get_viewport().gui_release_focus()
	inventoryPanel.inShop = true
	inventoryPanel.showPlayerInventory = false
	inventoryPanel.shopInventory = talkNPC.inventory
	inventoryPanel.toggle()
	animatedBgPanel.visible = true

func _on_turn_in_button_pressed():
	var turnInTarget: String = ''
	
	if talkNPC != null:
		turnInTarget = talkNPC.saveName
	
	if interactable != null:
		turnInTarget = interactable.saveName
	
	questsPanel.turnInTargetName = turnInTarget
	get_viewport().gui_release_focus()
	questsPanel.toggle()
	disableMovement = true

func _on_inventory_panel_node_back_pressed():
	menu_closed()
	if textBox.visible and not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not pausePanel.visible:
		textBox.refocus_choice(pickedChoice)
		if pickedChoice != null and pickedChoice.opensShop:
			pickedChoice = null

func _on_quests_panel_node_back_pressed():
	menu_closed()
	if textBox.visible and not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not pausePanel.visible:
		textBox.refocus_choice(pickedChoice)
		if pickedChoice != null and pickedChoice.turnsInQuest != '':
			var questName = pickedChoice.turnsInQuest.split('#')[0]
			var stepName = pickedChoice.turnsInQuest.split('#')[1]
			var questTracker: QuestTracker = PlayerResources.questInventory.get_quest_tracker_by_name(questName)
			if questTracker != null:
				var step: QuestStep = questTracker.get_step_by_name(stepName)
				var status: QuestTracker.Status = questTracker.get_step_status(step)
				if status == QuestTracker.Status.COMPLETED:
					if pickedChoice.leadsTo != null:
						if talkNPC != null:
							talkNPC.add_dialogue_entry_in_dialogue(pickedChoice.leadsTo)
						elif interactable != null:
							var interDialogue: InteractableDialogue = InteractableDialogue.new()
							interDialogue.dialogueEntry = pickedChoice.leadsTo
							interDialogue.speaker = interactableDialogues[interactableDialogueIndex].speaker
							interactableDialogues.append(interDialogue)
					advance_dialogue()

func _on_stats_panel_node_attempt_equip_weapon_to(stats: Stats):
	inventoryPanel.selectedFilter = Item.Type.WEAPON
	equip_to_combatant_helper(stats)

func _on_stats_panel_node_attempt_equip_armor_to(stats: Stats):
	inventoryPanel.selectedFilter = Item.Type.ARMOR
	equip_to_combatant_helper(stats)

func equip_to_combatant_helper(stats: Stats):
	inventoryPanel.lockFilters = true
	inventoryPanel.equipContextStats = stats
	inventoryPanel.inShop = false
	inventoryPanel.shopInventory = null
	statsPanel.visible = false
	statsPanel.reset_panel_to_player()
	inventoryPanel.toggle()
	menu_closed()

func level_up(newLevels: int):
	if newLevels == 0:
		return
	
	PlayerResources.playerInfo.combatant.currentHp = PlayerResources.playerInfo.combatant.stats.maxHp
	if inventoryPanel.visible and inventoryPanel.itemUsePanel.visible:
		await inventoryPanel.item_use_panel_closed # open the level up panel after the use panel is closed
	
	statsPanel.levelUp = true
	statsPanel.newLvs = newLevels
	statsPanel.stats = PlayerResources.playerInfo.combatant.stats
	statsPanel.curHp = PlayerResources.playerInfo.combatant.currentHp
	statsPanel.isPlayer = true
	SceneLoader.pause_autonomous_movers() # make sure autonomous movers are paused
	inventoryPanel.visible = false
	questsPanel.visible = false
	statsPanel.visible = false # show stats panel for sure
	statsPanel.toggle()

func _on_stats_panel_node_back_pressed():
	if statsPanel.levelUp and questsPanel.visible:
		questsPanel.toggle()
	statsPanel.levelUp = false
	statsPanel.newLvs = 0
	menu_closed()
	if textBox.visible and not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not pausePanel.visible:
		if pickedChoice != null and pickedChoice.turnsInQuest != '':
			if pickedChoice.leadsTo != null:
				talkNPC.add_dialogue_entry_in_dialogue(pickedChoice.leadsTo)
			advance_dialogue()
		else:
			textBox.refocus_choice(pickedChoice)

func _on_quests_panel_node_turn_in_step_to(saveName):
	if saveName == talkNPC.saveName:
		talkNPC.fetch_quest_dialogue_info()

func _on_quests_panel_node_level_up(newLevels: int):
	level_up(newLevels)

func _fade_in_force_unlock_cutscene(cutsceneSaveName: String):
	overworldTouchControls.set_in_cutscene(inCutscene)
	PlayerResources.playerInfo.set_cutscene_seen(cutsceneSaveName)
	PlayerResources.questInventory.auto_update_quests() # complete any quest steps that end on this cutscene
	if not inCutscene:
		cam.show_letterbox(false)
		unpause_movement()
		SceneLoader.cutscenePlayer.complete_cutscene()

func _on_quests_panel_node_act_changed():
	actChanged = true

func _new_act_callback():
	actChanged = false
	unpause_movement()

func _after_start_battle_fade_out():
	SceneLoader.load_battle()

func _on_pause_menu_resume_game():
	if not inventoryPanel.visible and not questsPanel.visible \
			and not statsPanel.visible and not pausePanel.visible:
		animatedBgPanel.visible = false
		if textBox.visible:
			textBox.refocus_choice(pickedChoice)
	overworldTouchControls.set_all_visible()

func _filter_out_null(value):
	return value != null

func _sort_interactables(a: Interactable, b: Interactable):
	if a.interactPriority > b.interactPriority:
		return true
	elif a.interactPriority < b.interactPriority:
		return false
	
	if (a.global_position - global_position).length_squared() <= (b.global_position - global_position).length_squared():
		return true
	return false

func _on_overworld_console_console_closed():
	SceneLoader.unpause_autonomous_movers() # make sure autonomous movers are unpaused
	overworldTouchControls.set_all_visible()

func _on_overworld_touch_controls_run_toggled():
	running = not running

func _on_overworld_touch_controls_pause_pressed():
	if inCutscene:
		# if awaiting player, don't even check if the pause panel can be opened, just stop here
		if not SceneLoader.cutscenePlayer.awaitingPlayer:
			SceneLoader.cutscenePlayer.toggle_pause_cutscene()
			cam.toggle_cutscene_paused_shade()
			cutscenePaused = cam.cutscenePaused
	else:
		animatedBgPanel.visible = true
		pausePanel.toggle_pause()
		overworldTouchControls.set_all_visible(false)

func _on_overworld_touch_controls_inventory_pressed():
	inventoryPanel.inShop = false
	inventoryPanel.showPlayerInventory = false
	inventoryPanel.lockFilters = false
	animatedBgPanel.visible = true
	inventoryPanel.toggle()
	overworldTouchControls.set_all_visible(false)
	SceneLoader.pause_autonomous_movers()

func _on_overworld_touch_controls_quests_pressed():
	questsPanel.turnInTargetName = ''
	questsPanel.lockFilters = false
	animatedBgPanel.visible = true
	questsPanel.toggle()
	overworldTouchControls.set_all_visible(false)
	SceneLoader.pause_autonomous_movers()

func _on_overworld_touch_controls_stats_pressed():
	statsPanel.stats = PlayerResources.playerInfo.combatant.stats
	statsPanel.curHp = PlayerResources.playerInfo.combatant.currentHp
	animatedBgPanel.visible = true
	statsPanel.toggle()
	overworldTouchControls.set_all_visible(false)
	SceneLoader.pause_autonomous_movers()

func _on_overworld_touch_controls_console_pressed() -> void:
	overworldConsole.show()
	overworldTouchControls.set_all_visible(false)
	SceneLoader.pause_autonomous_movers()
