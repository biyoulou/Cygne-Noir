class_name TerrainBuilder
extends Resource
## Procedural but deterministic helpers for Mondholm. Everything is generated
## from simple primitive meshes so the prototype has zero binary assets while
## still reading as a real environment.

const FLOOR_TOP := 1.2
const WATER_LEVEL := 0.05


func build_terrain(size: int, seed_number: int) -> Node3D:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number

	var half := size * 0.5
	for z in range(size):
		for x in range(size):
			var px := float(x) - half
			var pz := float(z) - half
			var py := height_at(px, pz)
			verts.append(Vector3(px, py, pz))
			normals.append(Vector3.UP)
			uvs.append(Vector2(px * 0.16, pz * 0.16))
			var idx := z * size + x
			if x < size - 1 and z < size - 1:
				var a := idx
				var b := idx + 1
				var c := idx + size
				var d := idx + size + 1
				indices.append_array([a, b, c, b, d, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var node := Node3D.new()
	node.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := _terrain_material()
	mi.material_override = mat
	node.add_child(mi)

	var body := StaticBody3D.new()
	body.add_to_group("world_static")
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var triangle_faces := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		triangle_faces.append(verts[indices[i]])
		triangle_faces.append(verts[indices[i + 1]])
		triangle_faces.append(verts[indices[i + 2]])
	shape.set_faces(triangle_faces)
	cs.shape = shape
	body.add_child(cs)
	node.add_child(body)
	return node


func build_path(
	width: float, points: Array, y: float = FLOOR_TOP + 0.02, mat: Material = null
) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := width * 0.5
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(0, i - 1)]
		var next: Vector3 = points[mini(points.size() - 1, i + 1)]
		var dir := (next - prev).normalized()
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		verts.append(Vector3(p.x + side.x * half, y, p.z + side.z * half))
		verts.append(Vector3(p.x - side.x * half, y, p.z - side.z * half))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0, i * 0.5))
		uvs.append(Vector2(1, i * 0.5))
		var base := i * 2
		if i < points.size() - 1:
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat else _path_material()
	return mi


func build_water(size: float, center: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Water"
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.45, 0.65, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	mat.roughness = 0.15
	mi.material_override = mat
	mi.position = center
	mi.rotation_degrees = Vector3(-90, 0, 0)
	node.add_child(mi)
	return node


func build_river(size: float, center: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "River"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 0.12, size * 0.24)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.42, 0.64, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.5
	mat.roughness = 0.25
	mi.material_override = mat
	mi.position = center
	node.add_child(mi)
	return node


func build_bridge(width: float, length: float, center: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Bridge"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.18, length)
	mi.mesh = box
	mi.position = center
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.24, 0.16)
	mat.roughness = 0.9
	mi.material_override = mat
	node.add_child(mi)

	for x_delta in [-width * 0.42, width * 0.42]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.11
		cyl.height = 1.0
		post.mesh = cyl
		post.position = center + Vector3(x_delta, 0.55, 0)
		node.add_child(post)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.12, length)
	cs.shape = shape
	cs.position = center
	body.add_child(cs)
	node.add_child(body)
	return node


func build_building(pos: Vector3, scale: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Building"
	node.position = pos
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2 * scale.x, 2.6 * scale.y, 3.4 * scale.z)
	mi.mesh = box
	mi.position = Vector3(0, 1.3 * scale.y, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.34, 0.26)
	mat.roughness = 0.85
	mi.material_override = mat
	node.add_child(mi)

	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(3.6 * scale.x, 0.35 * scale.y, 3.8 * scale.z)
	roof.mesh = roof_box
	roof.position = Vector3(0, 2.8 * scale.y, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.32, 0.22)
	rmat.roughness = 0.8
	roof.material_override = rmat
	node.add_child(roof)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2 * scale.x, 2.6 * scale.y, 3.4 * scale.z)
	cs.shape = shape
	cs.position = Vector3(0, 1.3 * scale.y, 0)
	body.add_child(cs)
	node.add_child(body)
	return node


func build_tree(pos: Vector3, scale: float, corrupted: bool = false) -> Node3D:
	var node := Node3D.new()
	node.name = "Tree"
	node.position = pos
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12 * scale
	cyl.bottom_radius = 0.2 * scale
	cyl.height = 2.0 * scale
	trunk.mesh = cyl
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.30, 0.20, 0.13)
	trunk.material_override = tmat
	trunk.position = Vector3(0, 1.0 * scale, 0)
	node.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.85 * scale
	sphere.height = 1.5 * scale
	leaves.mesh = sphere
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.18, 0.45, 0.22) if not corrupted else Color(0.3, 0.2, 0.4)
	lmat.roughness = 0.85
	if corrupted:
		lmat.emission_enabled = true
		lmat.emission = Color(0.45, 0.2, 0.8)
	leaves.material_override = lmat
	leaves.position = Vector3(0, 2.5 * scale, 0)
	node.add_child(leaves)
	return node


func build_rock(pos: Vector3, scale: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Rock"
	node.position = pos
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = scale
	sphere.height = scale * 1.4
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.44, 0.40)
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = Vector3(0, scale * 0.5, 0)
	mi.scale = Vector3(1.1, 0.72, 1.0)
	node.add_child(mi)
	return node


func build_totem(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "CorruptedTotem"
	node.position = pos
	var spine := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.5
	cyl.height = 3.2
	spine.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.16, 0.3)
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.2, 1.0)
	mat.emission_energy_multiplier = 2.0
	spine.material_override = mat
	spine.position = Vector3(0, 1.6, 0)
	node.add_child(spine)

	for i in range(3):
		var float_ring := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7 + i * 0.1
		ring.outer_radius = 0.78 + i * 0.1
		float_ring.mesh = ring
		float_ring.material_override = mat
		float_ring.position = Vector3(0, 0.6 + i * 0.9, 0)
		float_ring.rotation_degrees = Vector3(90, 0, 0)
		node.add_child(float_ring)
	return node


func build_grass(_z_pos: float, seed_number: int, count: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Grass"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(count):
		var x := rng.randf_range(-32, 32)
		var y := rng.randf_range(-32, 32)
		var base := Vector3(x, height_at(x, y) + 0.02, y)
		var h := rng.randf_range(0.25, 0.7)
		verts.append(base)
		verts.append(base + Vector3(0.08, h, 0))
		verts.append(base + Vector3(0.02, h * 0.9, 0.08))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		var idx := i * 3
		indices.append_array([idx, idx + 1, idx + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.52, 0.22)
	mat.roughness = 0.9
	mat.shaded = false
	mi.material_override = mat
	node.add_child(mi)
	return node


func height_at(px: float, pz: float) -> float:
	var base := 0.55 * sin(px * 0.11) + 0.4 * sin(pz * 0.13) + 0.22 * sin((px + pz) * 0.07)
	var hill := maxf(0.0, 1.0 - Vector2(px + 16, pz - 8).length() * 0.06) * 2.5
	var noise := 0.05 * sin(px * 0.61 + pz * 0.37) + 0.04 * cos(pz * 0.93 - px * 0.2)
	return FLOOR_TOP + base + hill + noise


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.34, 0.20)
	mat.roughness = 0.95
	return mat


func _path_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.47, 0.33)
	mat.roughness = 0.9
	return mat
