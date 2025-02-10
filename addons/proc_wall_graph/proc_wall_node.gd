@tool

extends Node2D

class_name ProcwallNode

# How far away vertices should be placed from the node
@export var joint_radius: float = 20

# how tight of a curve to use for interior angles
# if left as zero, joint_radius is used instead
@export var inner_curve_radius_override: float = 0

# List of nodes that are linked to this one. 
# Both connected nodes should mutually contain each other in their lists, but there are cases where only one node having the connection will work
@export var connections: Array[ProcwallNode]

# Click this in editor (like a button) to automatically create a node connected to this one, added to each others' connections array
# Note that the 'Undo' function does not work properly to remove the created node. Use with caution
@export var editor_add_connection: bool : set = set_editor_add_connection

# if true, draw a circle representing this node's joint_radius, and tangent lines to other connected nodes
@export var redraw: bool : set = set_redraw

# imagine a laser rotating clockwise around this node starting at the sweep_start angle.
# as the laser hits connected nodes, those nodes are inserted into the list in the order that they were seen by the laser
func get_ordered_connections(sweep_start: Vector2, clockwise: bool = true) -> Array[ProcwallNode]:
	var connection_angles: Array[float]
	
	# elements will be removed from 'copy' as they're added to 'ordered'
	var copy = connections.duplicate()
	var ordered: Array[ProcwallNode]
	
	# remove empty refs to avoid errors while editing
	while copy.has(null):
		copy.erase(null)
	
	for connection in copy:
		var node_dir = connection.position - position
		var angle: float = sweep_start.angle_to(node_dir)
		
		# move angles from -180 -> 180 range from 0 -> 360 range
		# intentionally sets angles == 0 to 360, want them at the back of the output array
		if angle <= 0: angle += TAU
		connection_angles.append(angle)
	
	var max: float = 3600.0 * (1 if clockwise else -1)
	
	# add nodes to 'ordered' array in order of smallest angle from sweep_start
	while copy.size() > 0:
		
		var loop_min: float = max
		var i: int = 0
		var min_idx: int = -1
		
		# identify the index of the smallest angle (should line up with its corresponding procwallnode)
		for angle in connection_angles:
			if angle < loop_min:
				min_idx = i
				loop_min = angle
			i+=1
		
		# add the node with the smallest angle to the output array
		ordered.append(copy[min_idx])
		#prints("[%d] ordering for %s: %s angled at %f" % [ordered.size(), name, copy[min_idx].name, loop_min])
		
		# remove the node and angle from the arrays being processed
		copy.remove_at(min_idx)
		connection_angles.remove_at(min_idx)
	
	return ordered

# return the verts used to form the "joint" verts between nodes that connect to this node
# walls between nodes will start/end at the last/first entries. Any surface curving (e.g. nice rounded angles) will occur between them in the array
#func get_node_connecting_verts(from: ProcwallNode, to: ProcwallNode, clockwise: bool = true) -> PackedVector2Array:
	#var arr: PackedVector2Array
	#var tangents_from = get_external_tangents_to(from)
	#var tangents_to = get_external_tangents_to(to)
	#
	#if clockwise:
		#arr.append(tangents_from[2])
		#arr.append(tangents_to[0])
	#else:
		#arr.append(tangents_from[0])
		#arr.append(tangents_to[2])
	#
	#return arr

func _process(delta):
	if Engine.is_editor_hint() && redraw: 
		queue_redraw()

# returns tangent points for each circle, for the mutually tangential lines of the circles that don't cross between their centers
func get_external_tangents_to(other: ProcwallNode) -> Array:
	
	# data for the joints, represented by 2 circles A and B
	var posA = transform.origin
	var radA = joint_radius
	var posB = other.transform.origin
	var radB = other.joint_radius
	
	# Calculate the distance between the centers of the circles
	var distance = posA.distance_to(posB)

	# Calculate the angle between the centers of the circles
	var angle = atan2(posB.y - posA.y, posB.x - posA.x)

	# Calculate the angle between the centers and the tangent points
	var angle_offset = acos((radA - radB) / distance)

	# Calculate the tangent points
	var tangent1A = posA + Vector2(cos(angle + angle_offset), sin(angle + angle_offset)) * radA
	var tangent2A = posA + Vector2(cos(angle - angle_offset), sin(angle - angle_offset)) * radA
	var tangent1B = posB + Vector2(cos(angle + angle_offset), sin(angle + angle_offset)) * radB
	var tangent2B = posB + Vector2(cos(angle - angle_offset), sin(angle - angle_offset)) * radB

	return [tangent1A, tangent1B, tangent2A, tangent2B]

func _draw():
	if !redraw || !Engine.is_editor_hint(): return
	
	var colorA = Color.CHARTREUSE
	var colorB = Color.AZURE
	
	draw_set_transform(-transform.origin)
	
	draw_arc(transform.origin, joint_radius, 0, TAU, 32, colorA)
		
	for connection in connections:
		var ts = get_external_tangents_to(connection)
		
		var t1a = ts[0]
		var t1b = ts[1]
		var t2a = ts[2]
		var t2b = ts[3]
		
		draw_arc(connection.transform.origin, connection.joint_radius, 0, TAU, 32, colorB)
		
		draw_circle(t1a, 2, colorA)
		draw_circle(t1b, 2, colorB)
		draw_line(t1a, t1b, Color.RED)
		
		draw_circle(t2a, 2, colorA)
		draw_circle(t2b, 2, colorB)		
		draw_line(t2a, t2b, Color.BLUE)

func set_redraw(value):
	redraw = value
	queue_redraw()

# for use as an editor "button" to quickly add a new connected ProcwallNode
func set_editor_add_connection(value):
	add_connection(Vector2(joint_radius * 2, joint_radius * 2))

func add_connection(offset: Vector2) -> ProcwallNode:
	var new = ProcwallNode.new()
	new.joint_radius = joint_radius
	new.inner_curve_radius_override = inner_curve_radius_override
	new.transform = transform
	new.transform.origin += offset
	
	#create the new node as a sibling
	get_parent().add_child(new)
	new.owner = self.owner
	
	connections.append(new)
	new.connections.append(self)
	return new
