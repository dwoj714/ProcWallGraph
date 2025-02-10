@tool

extends Node2D

# builds a collision polygon that connect/envelops ProcwallNodes

class_name ProcWall

# which node to start from when generating the wall
@export var root_node: ProcwallNode

# Indicated by an orange line pointing out of the root node when drawing the graph.
# Can affect the order that the graph connects nodes.
# Basically, if there's a closed loop of nodes in your graph, you'll probably want to change this value to make sure the orange line is on the outside of that loop
@export var root_sweep_start_angle: float = 0

# Curves will have a vertex placed every [angular_resolution]-th DEGREE around the curve.
# E.G. If there is a 90 degree arc, and angular_resolution is 10, there will be 9 vertices in the arc.
# tl;dr: smaller value = more vertices = smoother curves
@export var angular_resolution: float = 7

# Curves will have a vertex placed based on their physical distance, rather than the angle between them in the curve.
# This means that the radius of the node affects how many vertices make up the curves, where angular_resolution will give the same number of vertices no matter how large the node is
# E.G. Nodes with large radii will look jagged if the angular resolution is low. Using linear_resolution can compensate for that.
@export var linear_resolution: float = 15

# use whichever above option results in a smoother curve (more vertices, therefore a more complex/demanding shape)
@export var use_higher_resolution: bool = false

@export var redraw: bool : set = set_redraw
@export var redraw_frequency: int = 10
@export var set_collision_polygon_on_draw: bool = false

# how many editor ticks to wait before redraw
# increase to save resources if the graph is complex, or not being edited
# there's probably a less hacky way to handle it, but this works well enough
var redraw_ticks: int = 0

var polygon: Polygon2D
var shape: CollisionPolygon2D

func _ready():
	shape = $CollisionPolygon2D
	if shape == null:
		shape = CollisionPolygon2D.new()
		add_child(shape)
	
	polygon = $Polygon2D
	if polygon == null:
		polygon = Polygon2D.new()
		add_child(polygon)
	
	if !Engine.is_editor_hint() && root_node != null:
		build()
	
# generates a list of procwall nodes starting from the root node, branching out to its connections (and the connections' connections)
# order is determined by the physical placement of the nodes, rather than their order in the connections list
# starts with the first node with the smallest clockwise angle to root_sweep_start_angle
# once a node is chosen, it recursively does the same "angular sweep" check to determine which connection to use first,
# starting its sweep angle from the direction of the node that was used to point to it
func generate_traversal() -> Array[ProcwallNode]:
	var traversal: Array[ProcwallNode]
	
	# keeps track of which nodes (if any) have connected to root during generation
	var nodes_to_root: Array[ProcwallNode]
	var root_connections: Array[ProcwallNode] = root_node.get_ordered_connections(Vector2.RIGHT.rotated(root_sweep_start_angle), true)
	
	var iterations = 0
	var max_iterations = 500
	
	var prev_node = root_node
	var first = true
	
	for connection in root_connections:
		# this connection may have been part of a branch that looped back to root
		if nodes_to_root.has(connection) || connection == null:
			continue
		
		var prev = root_node
		var current = connection
		
		traversal.append(root_node)
		#prints("TRAVERSAL L1 APPEND %s" % prev.name)
		
		iterations = 0
		
		# poor man's do-while
		var loop: bool = false
		while true:
			traversal.append(current)
			#prints("TRAVERSAL L2 APPEND %s" % current.name)
			
			# vector that points from current to prev
			var dir_to_prev: Vector2 = prev.position - current.position
			var next_connections: Array[ProcwallNode] = current.get_ordered_connections(dir_to_prev)
			
			prev = current
			current = next_connections[0]
			
			loop = current != root_node || current.connections.is_empty() && iterations < max_iterations
			if !loop: break
			
			iterations += 1
			
			#incorrectly connected nodes may cause an infinite loop
			if iterations >= max_iterations:
				prints("MAX ITERATIONS HIT!!! Check that nodes are properly connected!")
				break
		
		# don't connect root to last node if it was just connected to root
		if current == root_node:
			nodes_to_root.append(prev)

	# (probably) always want to end with the root node
	traversal.append(root_node)
	#prints("TRAVESAL FINAL APPEND %s" % root_node.name)
	
	return traversal

# Generates a Vector2 array of vertices that "wraps" around the ordered list of nodes produced by generate_traversal()
func generate_polygon() -> PackedVector2Array:
	var arr = PackedVector2Array()
	var prev_node: ProcwallNode = null
	
	var traversal = generate_traversal()

	var prev = null
	var node = traversal[0]
	var next = traversal[1]
	
	var tangents = node.get_external_tangents_to(next)
	
	var prevA = tangents[2]
	var prevB = tangents[3]
	arr.append(prevA)
	arr.append(prevB)

	for i in range(1, traversal.size() - 1):
		prev = node
		node = traversal[i]
		next = traversal[i + 1]
		
		# get the first tangent line that "wraps" the 2 nodes when rotated clockwise
		tangents = node.get_external_tangents_to(next)
		var nextA = tangents[2]
		var nextB = tangents[3]
		
		# generate curve points if the next point doesn't overlap the last point (edge case)
		if nextA != prevB:
			var point = line_intersection(prevA, prevB, nextA, nextB)
			# intersection point is Vector2(INF, INF) if lines don't intersect
			if point.is_finite():
				# append concave curve points that wrap around a circle tangent to the lines making up the interior angle between the nodes
				arr.remove_at(arr.size() - 1)
				arr.append_array(generate_concave_curve_points(node, point, prevA, prevB, nextA, nextB, true))
				arr.append(nextB)
			else:
				# append convex curve points from prevB to nextA (a curve wrapping around the exterior of the node)
				arr.append_array(generate_arc_points(node.position, node.joint_radius, prevB, nextA))
				arr.append(nextA)
				arr.append(nextB)
		else:
			arr.append(nextB)
		
		prevA = arr[-2]
		prevB = tangents[-1]
	
	#prints("LAST 2 points: %s -> %s (nextB = %s)" % [arr[-1], arr[0]])
	
	# generate a final curve linking the first and last points if they don't overlap (same edge case as above)
	if arr[0] != arr[-1]:
		# inteserction check for first and last line segments
		var final_intersect = line_intersection(arr[0], arr[1], arr[-2], arr[-1])
		if final_intersect.is_finite():
			var final_curve = generate_concave_curve_points(next, final_intersect, arr[-2], arr[-1], arr[0], arr[1], true)
			arr.remove_at(0)
			arr.remove_at(arr.size() - 1)
			arr.append_array(final_curve)
		else:
			#prints("generating curve on %s for %s -> %s" % [next.name, arr[-1], arr[0]])
			arr.append_array(generate_arc_points(next.position, next.joint_radius, arr[-1], arr[0]))
		
	return arr

# outputs an arc of points around the given circle, rotating from p1 to p2
func generate_arc_points(center: Vector2, radius: float, p1: Vector2, p2: Vector2, clockwise: bool = true) -> PackedVector2Array:
	var arr = PackedVector2Array()
	var a = p1 - center
	var b = p2 - center
	var angle = a.angle_to(b)
	if angle <= 0: angle += TAU
	
	var linear_vert_count: int = ceil(radius * angle / linear_resolution) 
	var angular_vert_count: int = ceil(angle / deg_to_rad(angular_resolution))
	
	var vert_count = max(linear_vert_count, angular_vert_count) if use_higher_resolution else min(linear_vert_count, angular_vert_count)
	
	for i: float in range(1, vert_count):
		# progress through the arc (0 to 1)
		var prog = i / vert_count if clockwise else 1 - (i / vert_count)
		var vert_angle = angle * prog + a.angle()
		var vert = Vector2(cos(vert_angle) * radius, sin(vert_angle) * radius)
		arr.append(vert + center)
	
	#if !clockwise: arr.reverse()
	
	return arr

# return intersection point of 2 line segments
func line_intersection(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, ignore_length: bool = false) -> Vector2:
	var s1_x = p1.x - p0.x
	var s1_y = p1.y - p0.y
	var s2_x = p3.x - p2.x
	var s2_y = p3.y - p2.y

	var denom = (-s2_x * s1_y + s1_x * s2_y)

	if denom == 0:
		return Vector2(INF, INF)  # Lines are parallel

	var s = (-s1_y * (p0.x - p2.x) + s1_x * (p0.y - p2.y)) / denom
	var t = ( s2_x * (p0.y - p2.y) - s2_y * (p0.x - p2.x)) / denom

	if ignore_length or (s >= 0 and s <= 1 and t >= 0 and t <= 1):
		# Intersection detected
		var intersection_x = p0.x + (t * s1_x)
		var intersection_y = p0.y + (t * s1_y)
		return Vector2(intersection_x, intersection_y)
	else:
		return Vector2(INF, INF)  # No intersection

# outputs the centerpoint of a circle that is tangent to the input line segments, and the tangent points
func find_tangent_circle_points(line1A: Vector2, line1B: Vector2, line2A: Vector2, line2B: Vector2, radius: float) -> Array[Vector2]:
	# direction from lines' start points to their end points
	var line1_dir = (line1B - line1A).normalized()
	var line2_dir = (line2B - line2A).normalized()
	
	# get vectors to offset the lines a distance equal to the desired circle's radius
	var line1_offset = line1_dir.rotated(PI / 2) * radius
	var line2_offset = line2_dir.rotated(-PI / 2) * radius

	# get a set of points for 2 new lines, offset in the direction of their corresponding perpendicular vector
	# the intersection point of these lines will be the center of the tangent circle
	var rad_line_1A = line1_offset + line1A
	var rad_line_1B = line1_offset + line1B
	var rad_line_2A = line2_offset + line2A
	var rad_line_2B = line2_offset + line2B
	
	# get the intersection point
	var circle_center = line_intersection(rad_line_1A, rad_line_1B, rad_line_2A, rad_line_2B, true)
	
	# subtracting the lines' offsets from the circle center results in the tangent points
	var tangent1 = circle_center - line1_offset
	var tangent2 = circle_center - line2_offset
	
	return [circle_center, tangent1, tangent2]

# generates an arc of points for a circle that is tangent to both of the given lines
func generate_concave_curve_points(node: ProcwallNode, intersection_point: Vector2, line1A: Vector2, line1B: Vector2, line2A: Vector2, line2B: Vector2, print: bool = false) -> PackedVector2Array:
	# get the point on the opposite side of the intersection from the node's center
	# could also have rotated node_to_point 180 degrees
	var arc_center: Vector2
	var arc_start: Vector2
	var arc_end: Vector2
	var arc_radius: float
	
	if node.inner_curve_radius_override != 0:
		arc_radius = node.inner_curve_radius_override
		
		# get curve point data for a circle that's tangent to the lines preceding and following this joint, with the given radius
		var tangent_info = find_tangent_circle_points(line1B, line1A, line2A, line2B, arc_radius)
		
		arc_center = tangent_info[0]
		arc_start = tangent_info[1]
		arc_end = tangent_info[2]
	else:
		# mirror the node's circle across the intersection point, and generate the arc around that circle
		# prob don't need this, and can use the above process with the joint radius
		# this might be faster though? Figure that out. Or don't
		var node_to_point = intersection_point - node.position
		arc_center = node.position + node_to_point * 2
	
		var tan1_to_point = intersection_point - line1B
		var tan2_to_point = intersection_point - line2A
	
		arc_start = line1B + tan1_to_point * 2
		arc_end = line2A + tan2_to_point * 2
		arc_radius = node.joint_radius
	
	var points = PackedVector2Array()
	points.append(arc_start)
	points.append_array(generate_arc_points(arc_center, arc_radius, arc_end, arc_start, false))
	points.append(arc_end)
	return points

func build():
	var points = generate_polygon()
	polygon.polygon = points
	shape.polygon = points

func _process(delta):
	if Engine.is_editor_hint() && redraw:
		
		if redraw_ticks >= redraw_frequency:
			queue_redraw()
			redraw_ticks = 0
		redraw_ticks += 1
		pass

func _draw():
	if !redraw || !Engine.is_editor_hint(): return
	var points = generate_polygon()
	
	if set_collision_polygon_on_draw:
		shape.polygon = points
	else:
		shape.polygon = PackedVector2Array()
	
	points.append(points[0]) #close the loop
	draw_polyline(points, Color.GOLD, 2)
	#shape.polygon = points
	
	var traversal_path = PackedVector2Array()
	var traversal = generate_traversal()
	
	for node in traversal:
		traversal_path.append(node.position)
	draw_polyline(traversal_path, Color.CYAN)
	
	draw_line(root_node.position, root_node.position + Vector2.RIGHT.rotated(root_sweep_start_angle) * root_node.joint_radius * 2, Color.CORAL, 2)

func set_redraw(value):
	redraw = value
	redraw_ticks = 0
	queue_redraw()
