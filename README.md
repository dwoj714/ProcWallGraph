# ProcWallGraph
 Godot asset for creating smooth procedural 2D collision shapes

How to use:
There are 2 scripts needed for the asset to function - proc_wall_graph.gd and proc_wall_node.gd

The ProcWallGraph generates a concave 2D collision polygon as defined by the placement of several child ProcWallNodes in 2D space.

One child ProcWallNode is assigned as the "root" in the ProcWallGraph node.
It largely doesn't matter which node is the root; it just needs to be assigned manually.

Every node has a "connections" array, which contains the nodes that it is connected to.
The ProcWallGraph starts from the root node, and recursively links its connected nodes to it, and the connections' connections, etc.

ProcWallGraph's properties:
- Root Node: The start point when generating the polygon
- Root Sweep Start Angle: Used to determine which of the Root Node's connections should be used first when generating the polygon. Based on the node's relative angle from the root node in 2D space.
- Angular Resolution: When generating curves around nodes, have 1 vertex every n-th degree. Smaller resolution = more vertices in the curve.
- Linear Resolution: When generating curves around nodes, the vertex count is determined by the physical distance between vertices rather than the angle around the curve. Useful for smoothing out curves around joints with large radii
- Use Higher Resolution: If true, arcs will be generated using whichever resolution (liner or angular) would generate more vertices.
- Redraw: Should the editor actively redraw the ProcWallGraph.
- Redraw Frequency: How often (how many editor ticks) should the ProcWallGraph be redrawn.
- Set Collision Polygon on Draw: In addition to drawing the graph, also generate the collision polygon in editor.

ProcWallNode's properties:
- Joint Radius: How far away vertices should be placed from the node
- Inner Curve Radius Override: How small or wide of a curve to use for interior angles between nodes. If left as zero, joint_radius is used instead.
- Connections: The list of ProcWallNodes that this node is connected to. For best results, both connected nodes should mutually contain each other in their lists, but there are cases where only one node having the connection will work.
- Editor Add Connection: Click this in editor, like a button, to automatically create a node connected to this one, added to each others' connections array. Note that the 'Undo' function does not work properly to remove the created node. Use with caution.
- Redraw: If true, draw a circle representing this node's joint_radius, and tangent lines to other connected nodes.