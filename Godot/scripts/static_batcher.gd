class_name HomesteadStaticBatcher
extends RefCounted

# Merge matte, untextured prop surfaces by material within each place. Animated
# foliage stays under its original pivot; water shaders and character rigs stay
# separate. Place roots/colliders remain independent for selection and fading.
static func consolidate(root: Node3D, animated: Array[Node3D]) -> int:
 var groups={}
 var nested: Array[Node3D]=[]
 collect(root,root,animated,groups,nested)
 var saved=0
 for pivot in nested: saved+=consolidate(pivot,animated)
 for group in groups.values():
  if group.size()<3: continue
  var vertices=PackedVector3Array()
  var normals=PackedVector3Array()
  var indices=PackedInt32Array()
  var colors=PackedColorArray()
  for node in group:
   var arrays=node.mesh.surface_get_arrays(0)
   var source: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var source_normals=arrays[Mesh.ARRAY_NORMAL]
   var source_indices=arrays[Mesh.ARRAY_INDEX]
   var source_colors=arrays[Mesh.ARRAY_COLOR]
   var transform=root.global_transform.affine_inverse()*node.global_transform
   var normal_basis=transform.basis.inverse().transposed()
   var offset=vertices.size()
   for i in source.size():
    vertices.append(transform*source[i])
    colors.append(source_colors[i] if source_colors is PackedColorArray and source_colors.size()==source.size() else Color.WHITE)
    normals.append((normal_basis*source_normals[i]).normalized() if source_normals is PackedVector3Array and source_normals.size()==source.size() else Vector3.UP)
   if source_indices is PackedInt32Array and source_indices.size()>0:
    for index in source_indices: indices.append(offset+index)
   else:
    for index in source.size(): indices.append(offset+index)
  var arrays=[]
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_NORMAL]=normals
  arrays[Mesh.ARRAY_INDEX]=indices
  arrays[Mesh.ARRAY_COLOR]=colors
  var mesh=ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var merged=MeshInstance3D.new()
  merged.mesh=mesh
  merged.material_override=group[0].material_override
  root.add_child(merged)
  for node in group:
   node.get_parent().remove_child(node)
   node.queue_free()
  saved+=group.size()-1
 return saved

static func collect(node: Node3D,root: Node3D,animated: Array[Node3D],groups: Dictionary,nested: Array[Node3D]):
 if node!=root and node in animated:
  nested.append(node)
  return
 if node is MeshInstance3D and node.mesh!=null and node.mesh.get_surface_count()==1 and node.material_override is StandardMaterial3D:
  var arrays=node.mesh.surface_get_arrays(0)
  if arrays.size()==Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
   var key=node.material_override.get_instance_id()
   if not groups.has(key): groups[key]=[]
   groups[key].append(node)
 for child in node.get_children():
  if child is Node3D: collect(child,root,animated,groups,nested)
