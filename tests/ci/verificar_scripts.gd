extends SceneTree
## Pipeline, paso 2: carga todos los scripts (.gd), escenas (.tscn) y recursos (.tres)
## del proyecto y verifica que compilen y se puedan instanciar.
## Uso: godot --headless --path . -s res://tests/ci/verificar_scripts.gd

const EXTENSIONES := ["gd", "tscn", "tres"]
const CARPETAS_IGNORADAS := ["res://.godot", "res://.github", "res://.git"]

var revisados := 0
var fallos := 0


func _initialize() -> void:
	_revisar_carpeta("res://")
	print("Archivos revisados: %d | con errores: %d" % [revisados, fallos])
	quit(1 if fallos > 0 or revisados == 0 else 0)


func _revisar_carpeta(carpeta: String) -> void:
	for subcarpeta in DirAccess.get_directories_at(carpeta):
		var ruta := carpeta.path_join(subcarpeta)
		if ruta not in CARPETAS_IGNORADAS:
			_revisar_carpeta(ruta)
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.get_extension() in EXTENSIONES:
			_revisar_archivo(carpeta.path_join(archivo))


func _revisar_archivo(ruta: String) -> void:
	revisados += 1
	# Carga normal (con caché): recargar este mismo script mientras se ejecuta haría fallar a Godot.
	var recurso := ResourceLoader.load(ruta)
	var problema := ""
	if recurso == null:
		problema = "no se pudo cargar"
	elif recurso is GDScript and not (recurso as GDScript).can_instantiate():
		problema = "el script tiene errores"
	elif recurso is PackedScene and not (recurso as PackedScene).can_instantiate():
		problema = "la escena no se puede instanciar"

	if problema.is_empty():
		print("  OK     ", ruta)
	else:
		fallos += 1
		printerr("  FALLO  %s: %s" % [ruta, problema])
