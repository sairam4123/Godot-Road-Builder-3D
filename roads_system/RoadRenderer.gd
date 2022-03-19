extends Spatial

onready var road_net = get_parent()

#func _ready():
#	road_net.connect("graph_changed", self, "_on_RoadNetwork_graph_changed")

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_KP_7 and event.pressed:
			update(road_net) # debug only
		if event.scancode == KEY_KP_8 and event.pressed:
			$SegmentRenderer/ImmediateGeometry.visible = !$SegmentRenderer/ImmediateGeometry.visible

func update(_road_net):
#	pass
	$IntersectionRenderer.update(_road_net)
	$SegmentRenderer.update(_road_net)

func _on_RoadNetwork_graph_changed(_road_net: RoadNetwork):
	if is_inside_tree():
		yield(get_tree(), "idle_frame")
		update(_road_net)
