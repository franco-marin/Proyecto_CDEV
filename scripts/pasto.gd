class_name Pasto
extends Node3D
## Pasto corto que cubre todo el suelo, menos el río y su orilla de barro.
## Se arma con "parcelas" de 1 m² llenas de briznas finas. Las parcelas se agrupan por
## zonas y cada zona es un MultiMesh (dibuja todas sus parcelas de una vez). Las zonas
## lejanas no se dibujan: a esa distancia la niebla ya las tapa y el suelo verde alcanza.

const SHADER := preload("res://recursos/pasto.gdshader")
const BRIZNAS_POR_PARCELA := 70
## Variantes de parcela (se reparten al azar para que no se note la repetición).
const VARIANTES := 4
## Lado de cada zona, en metros.
const TAMANO_ZONA := 16.0
## Más lejos que esto, una zona no se dibuja.
const DISTANCIA_VISIBLE := 45.0


## Cubre de pasto el cuadrado de lado 2 × "mitad", salteando el río y su orilla.
func generar(mitad: float, rio: Rio) -> void:
	var fuera_del_rio := func(punto: Vector3) -> bool: return rio != null and rio.en_agua(punto, 1.8)
	generar_en(Rect2(-mitad, -mitad, mitad * 2.0, mitad * 2.0), fuera_del_rio)


## Cubre de pasto un rectángulo (en el plano x-z). "excluir" recibe un punto y devuelve
## true si ahí no va pasto (el río, un sendero...).
func generar_en(zona_total: Rect2, excluir: Callable) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var parcelas: Array[ArrayMesh] = []
	for variante in VARIANTES:
		parcelas.append(_parcela(variante, material))

	for zx in ceili(zona_total.size.x / TAMANO_ZONA):
		for zz in ceili(zona_total.size.y / TAMANO_ZONA):
			var esquina := zona_total.position + Vector2(zx, zz) * TAMANO_ZONA
			_zona(esquina, excluir, parcelas)


## Una zona: una parcela por metro cuadrado (salvo donde "excluir" diga que no).
func _zona(esquina: Vector2, excluir: Callable, parcelas: Array[ArrayMesh]) -> void:
	var por_variante := []
	for variante in VARIANTES:
		por_variante.append([])
	for x in int(TAMANO_ZONA):
		for z in int(TAMANO_ZONA):
			var punto := Vector3(esquina.x + x + 0.5, 0, esquina.y + z + 0.5)
			if excluir.call(punto):
				continue
			var giro := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(1, randf_range(0.8, 1.2), 1))
			por_variante[randi() % VARIANTES].append(Transform3D(giro, punto))
	for variante in VARIANTES:
		var lista: Array = por_variante[variante]
		if lista.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = parcelas[variante]
		multi.instance_count = lista.size()
		for i in lista.size():
			multi.set_instance_transform(i, lista[i])
		var instancia := MultiMeshInstance3D.new()
		instancia.multimesh = multi
		instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instancia.visibility_range_end = DISTANCIA_VISIBLE
		add_child(instancia)


## Parcela de 1 × 1 m con briznas al azar: cada brizna es un triángulo angosto y un
## poco inclinado (UV.y va de 0 en la base a 1 en la punta, para el shader).
func _parcela(semilla: int, material: Material) -> ArrayMesh:
	var azar := RandomNumberGenerator.new()
	azar.seed = 500 + semilla
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BRIZNAS_POR_PARCELA:
		var base := Vector3(azar.randf_range(-0.5, 0.5), 0, azar.randf_range(-0.5, 0.5))
		var giro := azar.randf() * TAU
		var ancho := Vector3(cos(giro), 0, sin(giro)) * azar.randf_range(0.015, 0.03)
		var punta := base + Vector3(azar.randf_range(-0.07, 0.07), azar.randf_range(0.12, 0.3), azar.randf_range(-0.07, 0.07))
		for vertice in [[base - ancho, Vector2(0, 0)], [base + ancho, Vector2(1, 0)], [punta, Vector2(0.5, 1)]]:
			superficie.set_normal(Vector3.UP)  # luz como la del suelo: el pasto se funde con él
			superficie.set_uv(vertice[1])
			superficie.add_vertex(vertice[0])
	var malla := superficie.commit()
	malla.surface_set_material(0, material)
	return malla
