extends Node2D

var mapInstance = null

# Called when the node enters the scene tree for the first time.
func _ready():
	load_map("TestMap1")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func entered_warp(newMapName, newMapPos, isUnderground):
	load_map(newMapName)
	var player = get_node("/root/Overworld/Player")
	player.position = newMapPos
	pass

func load_map(mapName):
	if mapInstance != null:
		mapInstance.queue_free()
	var mapScene = load("res://Prefabs/Maps/" + mapName + ".tscn")
	mapInstance = mapScene.instantiate()
	add_child.call_deferred(mapInstance)
	pass
