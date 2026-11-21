class_name Pasillo
extends Node3D
## Nivel 4: un pasillo lineal por la selva. Un sendero de tierra transitado corre por el
## medio, de punta a punta; a los costados hay paredes que alternan un cañón de piedra,
## selva cerrada de árboles grandes y arbustos, y rocas grandes con árboles detrás.
## Barreras invisibles impiden salir del pasillo.
##
## El pasillo corre a lo largo del eje Z. El yaguareté empieza cerca de la ENTRADA (z alto),
## mirando hacia ella: por ahí llegan los cazadores. Para escapar corre hacia el FONDO (z bajo).

## Mitad del ancho por donde se puede caminar.
const MEDIO_ANCHO := 7.0
## Donde terminan las barreras invisibles en cada punta.
const Z_ENTRADA := 128.0
const Z_FONDO := -138.0
## Para Mundo.limite: mitad del largo total.
const MEDIO_LARGO := 140.0
## Tramos de pared, cada uno de este largo y de un tipo distinto.
const LARGO_TRAMO := 38.0

enum Tramo { CANON, SELVA, ROCAS }

const ESCENA_ARBOL := preload("res://escenas/arbol.tscn")
const ESCENA_ARBUSTO := preload("res://escenas/arbusto.tscn")


## Dónde empieza el yaguareté y dónde aparece el primer cazador.
func inicio_jugador() -> Vector3:
	return punto_en_sendero(Z_ENTRADA - 22.0)


## Punto del centro del sendero a la altura "z". El sendero serpentea un poco.
func punto_en_sendero(z: float) -> Vector3:
	return Vector3(1.6 * sin(z * 0.045) + 0.7 * sin(z * 0.13 + 1.0), 0, z)


func en_sendero(punto: Vector3, margen := 0.0) -> bool:
	return absf(punto.x - punto_en_sendero(punto.z).x) < 1.4 + margen


## Arma todo el pasillo. Las barreras van dentro de "navegacion" para que la malla de
## navegación las tenga en cuenta; la decoración, en este nodo.
func generar(navegacion: NavigationRegion3D, sotobosque: Node3D, cantidad_sotobosque: int) -> void:
	_sendero()
	_barreras(navegacion)
	var z := Z_FONDO - 12.0
	var tipo := 0
	while z < Z_ENTRADA + 25.0:
		var tramo: Tramo = [Tramo.CANON, Tramo.SELVA, Tramo.ROCAS][tipo % 3]
		for lado in [-1.0, 1.0]:
			_pared(tramo, lado, z, z + LARGO_TRAMO)
		z += LARGO_TRAMO
		tipo += 1
	_cierre_del_fondo()
	_maleza(sotobosque, cantidad_sotobosque)


## Rectángulo que cubre el pasto (todo el pasillo y un margen a los costados).
func zona_de_pasto() -> Rect2:
	return Rect2(-MEDIO_ANCHO - 14.0, Z_FONDO - 14.0, (MEDIO_ANCHO + 14.0) * 2.0, Z_ENTRADA - Z_FONDO + 44.0)


# --- Sendero -------------------------------------------------------------------------

## Tierra pisada en el medio y un borde de pasto gastado alrededor.
func _sendero() -> void:
	add_child(_cinta(3.6, 0.012, Color(0.45, 0.4, 0.24)))
	add_child(_cinta(2.4, 0.016, Color(0.6, 0.48, 0.32)))


func _cinta(ancho: float, altura: float, color: Color) -> MeshInstance3D:
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := Z_FONDO - 6.0
	while z < Z_ENTRADA + 30.0:
		var a := punto_en_sendero(z)
		var b := punto_en_sendero(z + 2.0)
		# El ancho varía un poco, como un sendero de verdad.
		var ancho_a := ancho * (1.0 + 0.12 * sin(z * 0.3))
		var ancho_b := ancho * (1.0 + 0.12 * sin((z + 2.0) * 0.3))
		var esquinas := [a + Vector3(-ancho_a / 2.0, altura, 0), a + Vector3(ancho_a / 2.0, altura, 0),
			b + Vector3(-ancho_b / 2.0, altura, 0), b + Vector3(ancho_b / 2.0, altura, 0)]
		for indice in [0, 2, 1, 1, 2, 3]:
			superficie.set_normal(Vector3.UP)
			superficie.add_vertex(esquinas[indice])
		z += 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instancia := MeshInstance3D.new()
	instancia.mesh = superficie.commit()
	instancia.material_override = material
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instancia


# --- Barreras invisibles -------------------------------------------------------------

func _barreras(navegacion: NavigationRegion3D) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Barreras"
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 0
	navegacion.add_child(cuerpo)
	var largo := Z_ENTRADA - Z_FONDO + 2.0
	var centro_z := (Z_ENTRADA + Z_FONDO) / 2.0
	for lado in [-1.0, 1.0]:
		_caja_invisible(cuerpo, Vector3(1, 6, largo), Vector3(lado * (MEDIO_ANCHO + 0.5), 3, centro_z))
	for z in [Z_ENTRADA + 0.5, Z_FONDO - 0.5]:
		_caja_invisible(cuerpo, Vector3(MEDIO_ANCHO * 2.0 + 2.0, 6, 1), Vector3(0, 3, z))


func _caja_invisible(cuerpo: StaticBody3D, medidas: Vector3, posicion: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = medidas
	var colision := CollisionShape3D.new()
	colision.shape = forma
	colision.position = posicion
	cuerpo.add_child(colision)


# --- Paredes ---------------------------------------------------------------------------

## Un tramo de pared de un costado ("lado" -1 = izquierda, 1 = derecha), entre z1 y z2.
func _pared(tramo: Tramo, lado: float, z1: float, z2: float) -> void:
	var E := FabricaFlora.Especie
	var borde := MEDIO_ANCHO + 0.6  # justo detrás de la barrera invisible
	match tramo:
		Tramo.CANON:
			# Cañón: dos hileras de bloques de piedra enormes, la de atrás más alta.
			var z := z1
			while z < z2:
				_roca(Vector3(lado * (borde + randf_range(1.5, 3.0)), 0, z), Vector3(randf_range(4, 6), randf_range(5, 9), randf_range(4, 6)))
				_roca(Vector3(lado * (borde + randf_range(5.0, 8.0)), 0, z + 1.5), Vector3(randf_range(6, 9), randf_range(10, 16), randf_range(6, 9)))
				z += randf_range(2.5, 3.5)
			# Algunas plantas que crecen entre las piedras.
			for i in 4:
				_arbusto(Vector3(lado * (borde - randf_range(0.2, 1.2)), 0, randf_range(z1, z2)), [E.HELECHO, E.CARAGUATA].pick_random())
		Tramo.SELVA:
			# Selva cerrada: árboles grandes apretados, palmeras y helechos arborescentes en el
			# borde, y arbustos tapando los huecos.
			var z := z1
			while z < z2:
				_arbol(Vector3(lado * (borde + randf_range(2.0, 9.0)), 0, z), [E.PALO_ROSA, E.TIMBO, E.LAPACHO].pick_random())
				_arbol(Vector3(lado * (borde + randf_range(0.6, 1.8)), 0, z + 2.0), [E.PINDO, E.CHACHI, E.CHACHI].pick_random())
				for i in 2:
					_arbusto(Vector3(lado * (borde + randf_range(-1.0, 3.0)), 0, z + randf_range(0, 4)), [E.ARBUSTO, E.TACUARA, E.HELECHO].pick_random())
				z += randf_range(3.5, 5.0)
		Tramo.ROCAS:
			# Rocas grandes al borde y árboles grandes detrás.
			var z := z1
			while z < z2:
				_roca(Vector3(lado * (borde + randf_range(0.8, 2.0)), 0, z), Vector3(randf_range(2.5, 4.5), randf_range(2.5, 5.0), randf_range(2.5, 4.5)))
				_arbol(Vector3(lado * (borde + randf_range(5.0, 10.0)), 0, z + 2.0), [E.PALO_ROSA, E.TIMBO].pick_random())
				_arbusto(Vector3(lado * (borde - randf_range(0.0, 1.0)), 0, z + randf_range(0, 3)), [E.ARBUSTO, E.CARAGUATA].pick_random())
				z += randf_range(4.0, 6.0)


## Fondo del pasillo (hacia donde se escapa): lo cierra una pared de piedra.
func _cierre_del_fondo() -> void:
	var x := -MEDIO_ANCHO - 6.0
	while x < MEDIO_ANCHO + 6.0:
		_roca(Vector3(x, 0, Z_FONDO - randf_range(2.0, 4.0)), Vector3(randf_range(5, 7), randf_range(8, 13), randf_range(5, 7)))
		x += 3.0


## Arbustos, helechos y caraguatás a los costados del sendero (sirven para esconderse).
func _maleza(sotobosque: Node3D, cantidad: int) -> void:
	var E := FabricaFlora.Especie
	var plantadas := 0
	for intento in cantidad * 20:
		if plantadas >= cantidad:
			break
		var punto := Vector3(randf_range(-MEDIO_ANCHO, MEDIO_ANCHO), 0, randf_range(Z_FONDO + 2.0, Z_ENTRADA - 2.0))
		if en_sendero(punto, 0.6):
			continue
		_arbusto(punto, [E.ARBUSTO, E.HELECHO, E.HELECHO, E.CARAGUATA, E.TACUARA].pick_random(), sotobosque)
		Mundo.registrar_cobertura(punto)
		plantadas += 1


# --- Piezas ----------------------------------------------------------------------------

func _arbol(punto: Vector3, especie: FabricaFlora.Especie) -> void:
	var arbol := ESCENA_ARBOL.instantiate()
	arbol.especie = especie
	arbol.variante = randi() % FabricaFlora.VARIANTES
	arbol.position = punto
	arbol.rotation.y = randf() * TAU
	add_child(arbol)


func _arbusto(punto: Vector3, especie: FabricaFlora.Especie, contenedor: Node3D = null) -> void:
	var arbusto := ESCENA_ARBUSTO.instantiate()
	arbusto.especie = especie
	arbusto.variante = randi() % FabricaFlora.VARIANTES
	arbusto.position = punto
	arbusto.rotation.y = randf() * TAU
	arbusto.scale = Vector3.ONE * randf_range(0.9, 1.4)
	(contenedor if contenedor else self).add_child(arbusto)


## Roca grande: la piedra de río de FabricaFlora, agrandada.
func _roca(punto: Vector3, escala: Vector3) -> void:
	var roca := MeshInstance3D.new()
	roca.mesh = FabricaFlora.planta(FabricaFlora.Especie.PIEDRA, randi() % FabricaFlora.VARIANTES).malla
	roca.position = punto
	roca.rotation.y = randf() * TAU
	roca.scale = escala
	add_child(roca)
