extends Spatial

export(NodePath) var world_road_network_node
onready var world_road_network: RoadNetwork = get_node(world_road_network_node) as RoadNetwork

const RoadIntersection = RoadNetwork.RoadIntersection
const RoadSegment = RoadNetwork.RoadSegment
const RoadNetworkInfo = RoadNetwork.RoadNetworkInfo

var _snapped: RoadIntersection
var _snapped_segment: RoadSegment

var _start_segment: RoadSegment
var _end_segment: RoadSegment

var _drag_start: RoadIntersection
var _drag_middle: RoadIntersection
var _drag_current: RoadIntersection
var _drag_end: RoadIntersection

var is_curve_tool_on: bool = false
var _is_dragging = false

var continue_dragging = true

var current_info: RoadNetworkInfo = RoadNetworkInfo.new("test_id", "Test Road", 1, 0.5, 1)

var disable_tool

var buildable = false

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_T:
			disable_tool = true
			reset()
			$RoadNetwork.clear()
			hide()
		if event.scancode == KEY_Y:
			disable_tool = false
			_is_dragging = false
			show()
		
		if event.scancode == KEY_G:
			disable_tool = true
			reset()
			$RoadNetwork.clear()
			hide()
		if event.scancode == KEY_H:
			disable_tool = false
			show()
		
		if event.scancode == KEY_1:
			current_info = RoadNetworkInfo.new("test_id", "Test Road", 1, 0.5, 1)
		if event.scancode == KEY_2:
			current_info = RoadNetworkInfo.new("test_id_2", "Test Road 2", 1, 1, 1)
		if event.scancode == KEY_3:
			current_info = RoadNetworkInfo.new("test_id_3", "Test Road 3", 1, 1.5, 1)
		if event.scancode == KEY_4:
			current_info = RoadNetworkInfo.new("test_id_4", "Test Road 4", 2, 1, 1)
		if event.scancode == KEY_5:
			current_info = RoadNetworkInfo.new("test_id_4", "Test Road 4", 1, 1, 1.5)
		
	if disable_tool:
		return

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			if !_is_dragging: # start a new road
				if _snapped:
					_drag_start = create_new_intersection(_snapped.position)
					$RoadNetwork.add_intersection(_drag_start)
				elif _snapped_segment:
					_start_segment = _snapped_segment
					_drag_start = create_new_intersection(_start_segment.project_point(_cast_ray_to(event.position)))
					$RoadNetwork.add_intersection(_drag_start)
				else:
					var new_intersection = create_new_intersection(_cast_ray_to(event.position))
					_drag_start = new_intersection
					$RoadNetwork.add_intersection(_drag_start)
				_is_dragging = true
				_snapped = null
				_snapped_segment = null

			elif _is_dragging: # end the dragging, and create new road in world
				if !is_curve_tool_on:
					if !_drag_middle and is_curve_tool_on:
						return
					if !buildable:
						return
					if _snapped:
						_drag_end = create_new_intersection(_snapped.position)
						$RoadNetwork.add_intersection(_drag_end)
					elif _snapped_segment:
						_end_segment = _snapped_segment
						_drag_end = create_new_intersection(_end_segment.project_point(_cast_ray_to(event.position)))
						$RoadNetwork.add_intersection(_drag_end)
					else:
						var new_intersection = create_new_intersection(_cast_ray_to(event.position))
						new_intersection = snap_to_length_and_angle(_drag_start, new_intersection)
						_drag_end = new_intersection
						$RoadNetwork.add_intersection(_drag_end)
						$RoadNetwork.connect_intersections(_drag_start, _drag_end, current_info)
					var start_intersection = world_road_network.get_closest_node(_drag_start.position)
					var end_intersection = world_road_network.get_closest_node(_drag_end.position)
					if !start_intersection:
						start_intersection = create_new_intersection(_drag_start.position)
					if !end_intersection:
						end_intersection = create_new_intersection(_drag_end.position)
					
					# add to world
					if !world_road_network.has_intersection(start_intersection):
						world_road_network.add_intersection(start_intersection)
					if !world_road_network.has_intersection(end_intersection):
						world_road_network.add_intersection(end_intersection)
					
					if _start_segment:
						world_road_network.split_at_postion(_start_segment, start_intersection, _start_segment.road_network_info)
					if _end_segment:
						world_road_network.split_at_postion(_end_segment, end_intersection, _end_segment.road_network_info)
					
					if start_intersection.position != end_intersection.position:
						var connection = world_road_network.connect_intersections(start_intersection, end_intersection, current_info)
						print(connection.get_bounds())
					
	#				world_road_network.draw()
					$RoadNetwork.clear()
					_is_dragging = continue_dragging
					if continue_dragging:
						print(start_intersection, end_intersection)
						_drag_start = create_new_intersection(_drag_end.position)
						$RoadNetwork.add_intersection(_drag_start)
					reset(false, continue_dragging)
					if !continue_dragging:
						_drag_start = null
				else:
					var new_intersection = create_new_intersection(_cast_ray_to(event.position))
					new_intersection = snap_to_length_and_angle(_drag_start, new_intersection)
					_drag_middle = new_intersection
					$RoadNetwork.add_intersection(_drag_middle)
					
					
					

		if event.button_index == BUTTON_RIGHT and event.pressed:
			if _is_dragging:
				reset()
				$RoadNetwork.clear()

	if event is InputEventMouseMotion:
		_snapped = null
		if _drag_current:
			$RoadNetwork.remove_intersection(_drag_current)
			_drag_current = null
	
		var new_intersection = create_new_intersection(_cast_ray_to(event.position))
		_drag_current = new_intersection
		$RoadNetwork.add_intersection(_drag_current)
		if _is_dragging and !is_curve_tool_on:
			$RoadNetwork.connect_intersections(_drag_start, _drag_current, current_info)
		_snapped_segment = null
		_snapped = null
		
		# snap the length and angle
		if _is_dragging:
			_drag_current = snap_to_length_and_angle(_drag_start, _drag_current)
		
		# snap to intersection
		var closest_segment = world_road_network.get_closest_segment(new_intersection.position, 0.5)
		if closest_segment:
			_drag_current.position = closest_segment.project_point(new_intersection.position)
			_snapped_segment = closest_segment
		
		# snap to edge
		var closest_node = world_road_network.get_closest_node(new_intersection.position)
		if closest_node:
			_snapped = closest_node
			_drag_current.position = _snapped.position
		
		if _is_dragging:
			if _drag_start.distance_to(_drag_current) < 1:
				$RoadNetwork/RoadRenderer.material_override.albedo_color = Color(1, 0, 0, 0.5)
				buildable = false
			else:
				$RoadNetwork/RoadRenderer.material_override.albedo_color = Color(0, 1, 1, 0.5)
				buildable = true
		else:
			$RoadNetwork/RoadRenderer.material_override.albedo_color = Color(0, 1, 1, 0.5)
		
		
		$RoadNetwork.draw()
		$RoadNetwork/RoadRenderer.update()

# if !_is_dragging:
##					prints(_drag_current.position == closest_point, dist < 1)
#				_drag_current.position = closest_point
#				_snapped_segment = segment
##					prints(_drag_start, _drag_end, _drag_current, _start_segment, _end_segment, _snapped_segment, closest_point, dist)
#			elif _is_dragging and is_instance_valid(_drag_start) and is_instance_valid(_drag_current) and _drag_start.position != closest_point:
#				_drag_current.position = closest_point
#				_snapped_segment = segment

func _set_snapped(new_intersection: RoadIntersection):
	_snapped = world_road_network.get_closest_node(new_intersection.position)
	if _drag_start and _snapped and _snapped.position == _drag_start.position:
		return
	if _snapped and _drag_current:
		_drag_current.position = _snapped.position

func reset(reset_start = true, _dragging = false):
	_drag_current = null
	if reset_start:
		_drag_start = null
	_drag_middle = null
	_drag_end = null
	_start_segment = null
	_end_segment = null
	_snapped_segment = null
	if !_dragging:
		_is_dragging = false
	_snapped = null

func _cast_ray_to(postion: Vector2):
	var camera = get_viewport().get_camera()
	var from = camera.project_ray_origin(postion)
	var to = from + camera.project_ray_normal(postion) * camera.far
	return get_world().direct_space_state.intersect_ray(from, to).get("position", Vector3(NAN, NAN, NAN))

func create_new_intersection(position) -> RoadIntersection:
	return current_info.create_intersection(position)

func snap_to_length_and_angle(from, to):
	var length = from.distance_to(to)
	var direction = from.direction_to(to)
	var angle = rad2deg(atan2(direction.z, direction.x))
	var new_length = round(length / 2.5) * 2.5
	var new_angle = round(angle / 45.0) * 45.0
	if abs(angle - new_angle) < 10:
		angle = new_angle
		direction = Vector3(cos(deg2rad(angle)), 0, sin(deg2rad(angle)))
		to.position = from.position + direction * length
	if abs(length - new_length) < 0.25 and new_length != 0:
		length = new_length
		to.position = from.position + direction * length
	return to
