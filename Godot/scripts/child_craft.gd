class_name HomesteadChildCraft
extends RefCounted
# Joint-local original Blender surfaces. Cache geometry, never an orphan rig.
static var parts: Dictionary={}
static func collect(node: Node3D,transform: Transform3D,entries: Array):
 var local=transform*node.transform
 if node is MeshInstance3D:
  var material=node.mesh.surface_get_material(0)
  var color=material.resource_name.get_slice("_",1)
  entries.append({"mesh":node.mesh,"transform":local,"color":color})
 for child in node.get_children():
  if child is Node3D: collect(child,local,entries)
static func attach(parent: Node3D,part: String) -> Node3D:
 if parts.is_empty():
  var source=load("res://assets/child/cozy_child_parts.glb").instantiate()
  for group in source.get_children():
   var entries=[]
   for child in group.get_children():
    if child is Node3D: collect(child,Transform3D.IDENTITY,entries)
   parts[group.name]=entries
  source.free()
 var root=Node3D.new()
 root.name=part
 parent.add_child(root)
 for entry in parts[part]:
  var surface=MeshInstance3D.new()
  surface.mesh=entry.mesh
  surface.transform=entry.transform
  surface.set_meta("original_color",entry.color)
  surface.set_meta("authored_surface",true)
  var material=HomesteadMesh.material(entry.color).duplicate()
  material.vertex_color_use_as_albedo=true
  surface.material_override=material
  root.add_child(surface)
 return root
