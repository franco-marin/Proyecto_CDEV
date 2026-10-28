class_name FabricaFlora
extends RefCounted
## Construye por código las plantas de la selva paranaense (Misiones), el hábitat
## del yaguareté en Argentina:
##   - Árboles del dosel: palo rosa, timbó y lapacho (20 a 30 m en la realidad).
##   - Estrato medio: palmera pindó y helecho arborescente chachí.
##   - Sotobosque (0 a 5 m): tacuaras, helechos, caraguatás y arbustos.
## Cada planta se arma con piezas simples (cilindros, cajas, esferas) que se combinan
## en UNA sola malla con SurfaceTool. Cada especie tiene unas pocas variantes que se
## generan una sola vez y se reutilizan: todos los "palo rosa variante 2" comparten malla.

enum Especie { PALO_ROSA, TIMBO, LAPACHO, PINDO, CHACHI, TACUARA, HELECHO, CARAGUATA, ARBUSTO, PIEDRA }

const VARIANTES := 4
const SHADER := preload("res://recursos/vegetacion.gdshader")

## Colores de cada material, tomados de fotos de la selva misionera.
const COLORES := {
	"corteza": Color(0.36, 0.31, 0.25),
	"musgo": Color(0.33, 0.45, 0.17),
	"copa_oscura": Color(0.12, 0.29, 0.11),
	"copa_clara": Color(0.21, 0.41, 0.14),
	"flor_lapacho": Color(0.86, 0.43, 0.66),
	"liana": Color(0.27, 0.23, 0.13),
	"tronco_pindo": Color(0.55, 0.53, 0.47),
	"hoja_palmera": Color(0.26, 0.45, 0.16),
	"tronco_chachi": Color(0.17, 0.11, 0.07),
	"fronda": Color(0.27, 0.5, 0.19),
	"cana": Color(0.5, 0.57, 0.25),
	"hoja_cana": Color(0.31, 0.5, 0.17),
	"helecho": Color(0.24, 0.49, 0.18),
	"caraguata": Color(0.34, 0.47, 0.21),
	"caraguata_centro": Color(0.78, 0.15, 0.16),
	"arbusto": Color(0.16, 0.35, 0.13),
	"piedra": Color(0.46, 0.45, 0.42),
}

## Materiales del sotobosque: se recortan alrededor del jugador ("moverse entre la maleza").
const MATERIALES_SOTOBOSQUE := ["cana", "hoja_cana", "helecho", "caraguata", "caraguata_centro", "arbusto"]

static var _plantas := {}
static var _materiales := {}


## Devuelve la malla y los datos de una planta: {malla, radio_tronco, posado}.
## "posado" es un punto (relativo a la planta) donde se pueden posar los pájaros.
static func planta(especie: Especie, variante: int) -> Dictionary:
	var clave := "%d_%d" % [especie, variante % VARIANTES]
	if not _plantas.has(clave):
		_plantas[clave] = _construir(especie, variante % VARIANTES)
	return _plantas[clave]


static func es_sotobosque(especie: Especie) -> bool:
	return especie in [Especie.TACUARA, Especie.HELECHO, Especie.CARAGUATA, Especie.ARBUSTO]


static func material(nombre: String) -> ShaderMaterial:
	if not _materiales.has(nombre):
		var nuevo := ShaderMaterial.new()
		nuevo.shader = SHADER
		nuevo.set_shader_parameter("color", COLORES[nombre])
		nuevo.set_shader_parameter("recorte_cercano", 1.0 if nombre in MATERIALES_SOTOBOSQUE else 0.0)
		_materiales[nombre] = nuevo
	return _materiales[nombre]


static func _construir(especie: Especie, variante: int) -> Dictionary:
	# Semilla fija: la misma variante siempre sale igual.
	var azar := RandomNumberGenerator.new()
	azar.seed = especie * 1000 + variante
	var piezas := Piezas.new()
	var datos := {"radio_tronco": 0.3, "posado": Vector3(0, 3, 0)}
	match especie:
		Especie.PALO_ROSA:
			_arbol_del_dosel(piezas, azar, datos, azar.randf_range(20, 25), azar.randf_range(5.5, 7.0), "copa_oscura", 0.0)
		Especie.TIMBO:
			_arbol_del_dosel(piezas, azar, datos, azar.randf_range(16, 20), azar.randf_range(7.0, 8.5), "copa_clara", 0.0)
		Especie.LAPACHO:
			_arbol_del_dosel(piezas, azar, datos, azar.randf_range(17, 22), azar.randf_range(5.5, 7.0), "copa_oscura", 0.45)
		Especie.PINDO:
			_palmera_pindo(piezas, azar, datos)
		Especie.CHACHI:
			_helecho_arborescente(piezas, azar, datos)
		Especie.TACUARA:
			_tacuara(piezas, azar)
		Especie.HELECHO:
			_helecho(piezas, azar)
		Especie.CARAGUATA:
			_caraguata(piezas, azar)
		Especie.ARBUSTO:
			_arbusto(piezas, azar)
		Especie.PIEDRA:
			_piedra(piezas, azar)
	datos["malla"] = piezas.construir()
	return datos


# --- Especies -----------------------------------------------------------------------

## Árbol grande del dosel: tronco recto con aletones en la base, musgo, ramas que se
## abren arriba, una copa ancha hecha de varias "nubes" de hojas, lianas y bromelias.
static func _arbol_del_dosel(piezas: Piezas, azar: RandomNumberGenerator, datos: Dictionary,
		altura: float, radio_copa: float, color_copa: String, proporcion_flores: float) -> void:
	var radio := azar.randf_range(0.45, 0.7)
	var inicio_copa := altura * azar.randf_range(0.6, 0.68)
	datos["radio_tronco"] = radio + 0.25

	# Tronco (más fino arriba).
	piezas.agregar(_cilindro(radio * 0.7, radio, inicio_copa), _en(Vector3(0, inicio_copa / 2.0, 0)), "corteza")
	# Aletones: raíces tabulares típicas de los árboles de la selva.
	for i in 4:
		var angulo := i * TAU / 4.0 + azar.randf_range(-0.4, 0.4)
		var lado := Vector3(sin(angulo), 0, cos(angulo))
		var base := Transform3D(Basis(Vector3.UP, angulo), lado * (radio + 0.35) + Vector3(0, 0.55, 0))
		piezas.agregar(_caja(Vector3(0.14, 1.1, 0.9)), base.rotated_local(Vector3.RIGHT, -0.5), "corteza")
	# Manchas de musgo sobre el tronco.
	for i in 4:
		var angulo := azar.randf() * TAU
		var lado := Vector3(sin(angulo), 0, cos(angulo))
		var alto := azar.randf_range(1.0, inicio_copa * 0.8)
		var mancha := Transform3D(Basis(Vector3.UP, angulo), lado * radio * 0.8 + Vector3(0, alto, 0))
		piezas.agregar(_caja(Vector3(radio * 0.9, azar.randf_range(0.6, 1.5), 0.12)), mancha, "musgo")

	# Ramas que se abren y "nubes" de hojas en sus puntas.
	var cantidad_ramas := azar.randi_range(4, 6)
	var cima := Vector3(0, inicio_copa, 0)
	for i in cantidad_ramas:
		var angulo := i * TAU / cantidad_ramas + azar.randf_range(-0.3, 0.3)
		var direccion := Vector3(sin(angulo) * 0.8, azar.randf_range(0.55, 0.9), cos(angulo) * 0.8).normalized()
		var largo := radio_copa * azar.randf_range(0.7, 0.95)
		var punta := cima + direccion * largo
		piezas.agregar(_cilindro(radio * 0.2, radio * 0.4, largo), _segmento(cima, punta), "corteza")
		var radio_nube := radio_copa * azar.randf_range(0.6, 0.75)
		var color := "flor_lapacho" if azar.randf() < proporcion_flores else color_copa
		piezas.agregar(_esfera(), _escalado(punta + Vector3(0, radio_nube * 0.2, 0),
			Vector3(radio_nube, radio_nube * 0.5, radio_nube)), color)
		# Una nube más baja y hacia afuera para cerrar el dosel.
		var afuera := cima + Vector3(sin(angulo + 0.5), 0, cos(angulo + 0.5)) * radio_copa * 0.85 \
			+ Vector3(0, largo * 0.5, 0)
		piezas.agregar(_esfera(), _escalado(afuera, Vector3(radio_nube, radio_nube * 0.4, radio_nube) * 0.85), color_copa)
		if i == 0:
			datos["posado"] = cima + direccion * largo * 0.35 + Vector3(0, 0.15, 0)
		# Bromelias (epífitas) sobre algunas ramas.
		if i % 2 == 1:
			var apoyo := cima + direccion * largo * 0.4
			piezas.agregar(_esfera(), _escalado(apoyo + Vector3(0, 0.2, 0), Vector3(0.4, 0.25, 0.4)), "caraguata")
			piezas.agregar(_esfera(), _escalado(apoyo + Vector3(0, 0.35, 0), Vector3(0.12, 0.15, 0.12)), "caraguata_centro")
		# Lianas que cuelgan hasta el suelo.
		if i < 2:
			var desde := cima + direccion * largo * 0.6
			var hasta := Vector3(desde.x * 1.15 + azar.randf_range(-1, 1), 0, desde.z * 1.15 + azar.randf_range(-1, 1))
			piezas.agregar(_cilindro(0.04, 0.05, desde.distance_to(hasta)), _segmento(desde, hasta), "liana")

	# Nube central, la más alta.
	var radio_central := radio_copa * 0.65
	piezas.agregar(_esfera(), _escalado(Vector3(0, altura - radio_central * 0.3, 0),
		Vector3(radio_central, radio_central * 0.45, radio_central)), color_copa)


## Palmera pindó: tronco fino, gris y anillado, con un penacho de hojas plumosas caídas.
static func _palmera_pindo(piezas: Piezas, azar: RandomNumberGenerator, datos: Dictionary) -> void:
	var altura := azar.randf_range(9.0, 14.0)
	datos["radio_tronco"] = 0.3
	datos["posado"] = Vector3(0, altura - 0.3, 0)
	piezas.agregar(_cilindro(0.15, 0.2, altura), _en(Vector3(0, altura / 2.0, 0)), "tronco_pindo")
	for i in 5:  # anillos de las hojas que se cayeron
		var alto := altura * (0.2 + i * 0.15)
		piezas.agregar(_cilindro(0.2, 0.2, 0.06), _en(Vector3(0, alto, 0)), "corteza")
	var cantidad := azar.randi_range(11, 14)
	for i in cantidad:
		var angulo := i * TAU / cantidad + azar.randf_range(-0.2, 0.2)
		_fronda(piezas, Vector3(0, altura, 0), angulo, azar.randf_range(-1.1, -0.6),
			azar.randf_range(3.0, 3.8), 0.75, 0.42, 4, "hoja_palmera")


## Helecho arborescente (chachí): tronco oscuro y fibroso de 2 a 5 m y una roseta de
## frondas largas que se arquean hacia abajo.
static func _helecho_arborescente(piezas: Piezas, azar: RandomNumberGenerator, datos: Dictionary) -> void:
	var altura := azar.randf_range(2.5, 4.5)
	datos["radio_tronco"] = 0.3
	datos["posado"] = Vector3(0, altura + 0.1, 0)
	piezas.agregar(_cilindro(0.2, 0.28, altura), _en(Vector3(0, altura / 2.0, 0)), "tronco_chachi")
	var cantidad := azar.randi_range(11, 14)
	for i in cantidad:
		var angulo := i * TAU / cantidad + azar.randf_range(-0.15, 0.15)
		_fronda(piezas, Vector3(0, altura, 0), angulo, azar.randf_range(-0.9, -0.5),
			azar.randf_range(2.2, 2.8), 0.65, 0.38, 4, "fronda")


## Tacuara: mata de cañas finas y altas que se abren, con hojas angostas en la parte alta.
static func _tacuara(piezas: Piezas, azar: RandomNumberGenerator) -> void:
	var cantidad := azar.randi_range(10, 15)
	for i in cantidad:
		var angulo := azar.randf() * TAU
		var afuera := Vector3(sin(angulo), 0, cos(angulo))
		var base := afuera * azar.randf_range(0.0, 0.5)
		var altura := azar.randf_range(2.8, 4.8)
		var inclinacion := azar.randf_range(0.1, 0.45)
		var medio := base + afuera * altura * 0.5 * sin(inclinacion) + Vector3(0, altura * 0.5, 0)
		var punta := medio + afuera * altura * 0.5 * sin(inclinacion * 2.2) + Vector3(0, altura * 0.45, 0)
		piezas.agregar(_cilindro(0.03, 0.04, base.distance_to(medio)), _segmento(base, medio), "cana")
		piezas.agregar(_cilindro(0.02, 0.03, medio.distance_to(punta)), _segmento(medio, punta), "cana")
		for j in 5:  # hojas
			var sobre_cana := medio.lerp(punta, j / 5.0)
			var giro := azar.randf() * TAU
			var hoja := Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.5), sobre_cana)
			piezas.agregar(_caja(Vector3(0.06, 0.015, 0.45)), hoja.translated_local(Vector3(0, 0, 0.22)), "hoja_cana")


## Helecho del suelo: roseta de frondas que se arquean.
static func _helecho(piezas: Piezas, azar: RandomNumberGenerator) -> void:
	var cantidad := azar.randi_range(9, 13)
	for i in cantidad:
		var angulo := i * TAU / cantidad + azar.randf_range(-0.2, 0.2)
		_fronda(piezas, Vector3(0, 0.1, 0), angulo, azar.randf_range(-1.2, -0.8),
			azar.randf_range(1.0, 1.5), 0.35, 0.4, 3, "helecho")


## Caraguatá (bromelia terrestre): roseta de hojas largas, angostas y rígidas con el
## centro rojo.
static func _caraguata(piezas: Piezas, azar: RandomNumberGenerator) -> void:
	var cantidad := azar.randi_range(14, 18)
	for i in cantidad:
		var angulo := i * TAU / cantidad + azar.randf_range(-0.2, 0.2)
		_fronda(piezas, Vector3(0, 0.05, 0), angulo, azar.randf_range(-1.3, -0.6),
			azar.randf_range(0.9, 1.3), 0.13, 0.25, 2, "caraguata")
	piezas.agregar(_esfera(), _escalado(Vector3(0, 0.25, 0), Vector3(0.18, 0.3, 0.18)), "caraguata_centro")


## Piedra de río: uno a tres bloques redondeados y facetados, con algo de musgo arriba.
static func _piedra(piezas: Piezas, azar: RandomNumberGenerator) -> void:
	for i in azar.randi_range(1, 3):
		var radio := azar.randf_range(0.25, 0.6) / (1.0 + i * 0.4)
		var centro := Vector3(azar.randf_range(-0.35, 0.35) * i, radio * 0.35, azar.randf_range(-0.35, 0.35) * i)
		var roca := _esfera()
		roca.radial_segments = 6
		roca.rings = 3
		piezas.agregar(roca, _escalado(centro, Vector3(radio * 1.2, radio * 0.7, radio)), "piedra")
		if azar.randf() < 0.5:
			piezas.agregar(_esfera(), _escalado(centro + Vector3(0, radio * 0.45, 0), Vector3(radio * 0.7, radio * 0.12, radio * 0.6)), "musgo")


## Arbusto denso del sotobosque (corta la visión a la altura del yaguareté).
static func _arbusto(piezas: Piezas, azar: RandomNumberGenerator) -> void:
	for i in azar.randi_range(4, 6):
		var angulo := azar.randf() * TAU
		var radio := azar.randf_range(0.6, 1.0)
		var centro := Vector3(sin(angulo), 0, cos(angulo)) * azar.randf_range(0.0, 0.8) \
			+ Vector3(0, azar.randf_range(0.6, 1.5), 0)
		piezas.agregar(_esfera(), _escalado(centro, Vector3(radio, radio * 0.85, radio)),
			"arbusto" if i % 3 != 2 else "helecho")


## Hoja larga y curva (de palmera, helecho o caraguatá): una cadena de tramos planos
## que se va doblando hacia abajo. "inclinacion" negativa = arranca apuntando hacia arriba.
static func _fronda(piezas: Piezas, origen: Vector3, angulo: float, inclinacion: float,
		largo: float, ancho: float, curvatura: float, tramos: int, nombre_material: String) -> void:
	var tramo := largo / tramos
	var actual := Transform3D(Basis(Vector3.UP, angulo) * Basis(Vector3.RIGHT, inclinacion), origen)
	for i in tramos:
		var ancho_tramo := ancho * (1.0 - 0.6 * float(i) / tramos)
		piezas.agregar(_caja(Vector3(ancho_tramo, 0.02, tramo * 1.05)),
			actual.translated_local(Vector3(0, 0, tramo / 2.0)), nombre_material)
		actual = actual.translated_local(Vector3(0, 0, tramo)).rotated_local(Vector3.RIGHT, curvatura)


# --- Piezas básicas -----------------------------------------------------------------

static func _cilindro(radio_arriba: float, radio_abajo: float, altura: float) -> CylinderMesh:
	var malla := CylinderMesh.new()
	malla.top_radius = radio_arriba
	malla.bottom_radius = radio_abajo
	malla.height = altura
	malla.radial_segments = 7
	malla.rings = 1
	return malla


static func _caja(medidas: Vector3) -> BoxMesh:
	var malla := BoxMesh.new()
	malla.size = medidas
	return malla


## Esfera de radio 1: se le da su tamaño (y se aplasta) con _escalado().
static func _esfera() -> SphereMesh:
	var malla := SphereMesh.new()
	malla.radius = 1.0
	malla.height = 2.0
	malla.radial_segments = 9
	malla.rings = 5
	return malla


static func _en(posicion: Vector3) -> Transform3D:
	return Transform3D(Basis(), posicion)


static func _escalado(posicion: Vector3, escala: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(escala), posicion)


## Transformación que coloca un cilindro (eje Y) entre dos puntos.
static func _segmento(desde: Vector3, hasta: Vector3) -> Transform3D:
	var eje_y := (hasta - desde).normalized()
	var eje_x := eje_y.cross(Vector3.FORWARD)
	if eje_x.length() < 0.01:
		eje_x = eje_y.cross(Vector3.RIGHT)
	eje_x = eje_x.normalized()
	var eje_z := eje_x.cross(eje_y)
	return Transform3D(Basis(eje_x, eje_y, eje_z), (desde + hasta) / 2.0)


## Junta las piezas agrupadas por material y arma una sola malla (una superficie por material).
class Piezas:
	var _por_material := {}

	func agregar(primitiva: PrimitiveMesh, transformacion: Transform3D, nombre_material: String) -> void:
		if not _por_material.has(nombre_material):
			var nueva := SurfaceTool.new()
			nueva.begin(Mesh.PRIMITIVE_TRIANGLES)
			_por_material[nombre_material] = nueva
		(_por_material[nombre_material] as SurfaceTool).append_from(primitiva, 0, transformacion)

	func construir() -> ArrayMesh:
		var malla := ArrayMesh.new()
		for nombre in _por_material:
			(_por_material[nombre] as SurfaceTool).commit(malla)
			malla.surface_set_material(malla.get_surface_count() - 1, FabricaFlora.material(nombre))
		return malla
