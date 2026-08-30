extends Node
## Pooled-ish placeholder VFX. All effects are procedural (particles, lights,
## tweened meshes) so the prototype is playable with zero binary assets.

var _container: Node3D


func _ready() -> void:
	_container = Node3D.new()
	_container.name = "VFXContainer"
	_container.top_level = true
	add_child(_container)


func spawn_impact(pos: Vector3, color: Color, scale: float = 1.0) -> void:
	_spawn_burst(pos, color, 16, 4.5, scale, 0.65)
	_spawn_flash(pos, color, 2.4 * scale, 0.18)


func spawn_spark(pos: Vector3, color: Color, count: int = 10) -> void:
	_spawn_burst(pos, color, count, 5.0, 1.0, 0.4)


func spawn_dash_trail(pos: Vector3, color: Color, scale: float = 1.0) -> void:
	_spawn_burst(pos, color, 14, 3.5, scale, 0.45)


func spawn_heal(pos: Vector3) -> void:
	_spawn_burst(pos, Color(0.55, 1.0, 0.62), 24, 2.8, 1.4, 1.0)


func spawn_poof(pos: Vector3, color: Color = Color(0.75, 0.78, 0.85)) -> void:
	_spawn_burst(pos, color, 18, 2.2, 1.2, 1.0)


func spawn_beam(pos: Vector3, dir: Vector3, color: Color, length: float = 8.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = length
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.look_at(pos + dir)
	_container.add_child(inst)
	_spawn_flash(pos, color, 1.5, 0.25)
	var tw := create_tween()
	tw.tween_property(inst, "scale", Vector3.ZERO, 0.35)
	tw.tween_callback(inst.queue_free)


func spawn_burst_ring(pos: Vector3, color: Color, radius: float = 6.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.92
	mesh.outer_radius = radius
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = Vector3(90, 0, 0)
	_container.add_child(inst)
	_spawn_flash(pos, color, 4.0, 0.3)
	var tw := create_tween()
	var fade_color := Color(color.r, color.g, color.b, 0.0)
	tw.tween_property(inst, "scale", Vector3(1.1, 0.2, 1.1), 0.4)
	tw.parallel().tween_property(mat, "albedo_color", fade_color, 0.45)
	tw.tween_callback(inst.queue_free)


func spawn_arena_transform(pos: Vector3) -> void:
	spawn_burst_ring(pos, Color(0.8, 0.3, 0.8), 10.0)
	_spawn_burst(pos, Color(0.9, 0.4, 1.0), 60, 8.0, 2.5, 1.5)
	_spawn_flash(pos, Color(0.8, 0.4, 1.0), 14.0, 0.7)


func _spawn_burst(
	pos: Vector3, color: Color, amount: int, spread: float, scale: float, life: float
) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = false
	p.explosiveness = 1.0
	p.emitting = true
	p.position = pos
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.08 * scale
	particle_mesh.height = 0.16 * scale
	p.draw_pass_1 = particle_mesh
	_container.add_child(p)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 75.0
	mat.initial_velocity_min = spread * 0.4
	mat.initial_velocity_max = spread
	mat.gravity = Vector3(0, -3.0, 0)
	mat.scale_min = 0.04 * scale
	mat.scale_max = 0.16 * scale
	mat.color = color
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	p.process_material = mat

	var tw := create_tween()
	tw.tween_interval(life + 0.4)
	tw.tween_callback(p.queue_free)


func _spawn_flash(pos: Vector3, color: Color, energy: float, life: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = energy * 2.2
	light.position = pos
	_holder().add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, life)
	tw.tween_callback(light.queue_free)


func _holder() -> Node3D:
	if _container == null:
		_rebuild()
	return _container


func _rebuild() -> void:
	_container = Node3D.new()
	_container.name = "VFXContainer"
	_container.top_level = true
	add_child(_container)
