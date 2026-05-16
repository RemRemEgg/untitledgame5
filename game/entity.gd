class_name Entity
extends CharacterBody3D

static func movement_update_flat(ent: Entity, dir: Vector2, delta: float) -> void:
	var vel := Vector2(ent.velocity.x, ent.velocity.z)
	var target := (dir * maxf(ent.speed, vel.dot(dir))) - vel # this is where the magic happens
	target = target.limit_length(delta * ent.accel) # prevent jittering
	ent.velocity += Vector3(target.x, 0.0, target.y)
static func movement_update_full(ent: Entity, dir: Vector3, delta: float) -> void:
	var target := (dir * maxf(ent.speed, ent.velocity.dot(dir))) - ent.velocity # this is where the magic happens (again)
	target = target.limit_length(delta * ent.accel) # prevent jittering
	ent.velocity += target


#var target: Entity

#var coll: CollisionShape2D
#var mesh: MeshInstance3D
#var rotlerp: Vector2
#var hurt_text: TextPopup

#var atk_data: Array[float]
#var curr_atk: ProcEntity.AtkExecutor
#var move_dir: Vector2
#var update_timer: float

#var guns: Array[Gun]

var health: float = 100.0
var max_health: float = 100.0
#var hurt_time: float = 0.0


#static func create() -> Entity:
	#var ent := Global.SCN_ENTITY.instantiate() as Entity
	#ent.coll = ent.get_child(0) as CollisionShape2D
	#ent.mesh = ent.get_child(1) as MeshInstance3D
	#ent.remove_child(ent.mesh)
	#return ent
#func add_to_world() -> Entity:
	#mesh.owner = null
	#Global.Game.render.add_child(mesh)
	#Global.Game.entities.add_child(self)
	#return self


#func _process(delta: float) -> void:
	#proc.process(self, delta)
	#queue_redraw()
#
#func _draw() -> void:
	#if !Global.DEBUG: return
	#draw_line(Vector2.ZERO, global_transform.basis_xform_inv(velocity*0.2), Color.RED, 2.0)
	#draw_line(Vector2.ZERO, global_transform.basis_xform_inv(move_dir*50.0), Color.GREEN, 2.0)
#
#func popup_update(damage: float) -> void:
	#if hurt_text && is_instance_valid(hurt_text) && hurt_text.time < 1.0 && hurt_text.global_position.distance_squared_to(global_position) < 256**2:
		#damage += int(hurt_text.text)
		#hurt_text.queue_free()
	#var apos: Vector2 = self.global_position + Vector2(0.0, -8)
	#hurt_text = TextPopup.instant(str(int(damage)), Vector2(apos.x, apos.y)) as TextPopup
