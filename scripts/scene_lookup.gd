extends RefCounted

static func mesh_node(root, node_name):
    return root.find_child(node_name, true, false)
