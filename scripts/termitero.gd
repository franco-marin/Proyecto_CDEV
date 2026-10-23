extends Node3D
## Termitero: montículo de tierra donde come el oso hormiguero. No se agota.


func _ready() -> void:
	var tierra := StandardMaterial3D.new()
	tierra.albedo_color = Color(0.5, 0.33, 0.21)
	tierra.roughness = 1.0
	var alto := randf_range(1.0, 1.6)
	_parte(Vector3(0, alto * 0.25, 0), Vector3(0.9, alto * 0.3, 0.9), tierra)
	_parte(Vector3(0.1, alto * 0.55, 0.05), Vector3(0.6, alto * 0.3, 0.6), tierra)
	_parte(Vector3(0.15, alto * 0.85, 0.1), Vector3(0.3, alto * 0.25, 0.3), tierra)


func puede_ser_objetivo() -> bool:
	return true


## El oso hormiguero "come": el termitero no desaparece.
func comer() -> bool:
	return true


func _parte(posicion: Vector3, escala: Vector3, material: Material) -> void:
	var malla := SphereMesh.new()
	malla.radial_segments = 8
	malla.rings = 5
	malla.material = material
	var parte := MeshInstance3D.new()
	parte.mesh = malla
	parte.position = posicion
	parte.scale = escala
	add_child(parte)
