extends RefCounted

static func mesh_node(root, node_name):
    return root.get_node_or_null(node_name)
