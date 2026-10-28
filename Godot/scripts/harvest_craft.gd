class_name HomesteadHarvestCraft
extends RefCounted
# Reusable original harvest surfaces; no scene instances remain in the cache.
static var parts: Dictionary={}
static var apple_materials: Dictionary={}
static func collect(node: Node3D,transform: Transform3D,entries: Array):
 var local=transform*node.transform
 if node is MeshInstance3D:
  var material=node.mesh.surface_get_material(0)
  material.vertex_color_use_as_albedo=true
  entries.append({"mesh":node.mesh,"transform":local,"material":material})
 for child in node.get_children():
  if child is Node3D: collect(child,local,entries)
static func attach(parent: Node3D,part: String,position=Vector3.ZERO,size=Vector3.ONE,apple_tint="") -> Node3D:
 if parts.is_empty():
  var source=preload("res://assets/harvest/cozy_harvest.glb").instantiate()
  for group in source.get_children():
   var entries=[]
   for child in group.get_children():
    if child is Node3D: collect(child,Transform3D.IDENTITY,entries)
   parts[group.name]=entries
  source.free()
 var root=Node3D.new()
 root.name=part
 parent.add_child(root)
 root.position=position
 root.scale=size
 for entry in parts[part]:
  var surface=MeshInstance3D.new()
  surface.mesh=entry.mesh
  surface.transform=entry.transform
  var material=entry.material
  if apple_tint!="" and material.resource_name=="AppleSkin":
   if not apple_materials.has(apple_tint):
    var copy=material.duplicate()
    copy.albedo_color=Color(apple_tint)
    apple_materials[apple_tint]=copy
   material=apple_materials[apple_tint]
  surface.material_override=material
  root.add_child(surface)
 return root
