extends Node2D

@export var bob_speed: float = 2.0
@export var bob_height: float = 10.0

var start_y: float
var time: float = 0.0

func _ready():
	start_y = position.y

func _process(delta):
	time += delta
	position.y = start_y + sin(time * bob_speed) * bob_height
