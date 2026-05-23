extends Node2D

@onready var line: Line2D = $Line2D

var start_node: Node2D
var end_node: Node2D


func setup(start: Node2D, end: Node2D) -> void:
	start_node = start
	end_node = end


func _process(_delta: float) -> void:
	if start_node == null or end_node == null:
		queue_free()
		return

	line.clear_points()
	line.add_point(start_node.global_position)
	line.add_point(end_node.global_position)
