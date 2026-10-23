class_name Niveles
extends RefCounted
## Configuración de cada nivel. Del 1 al 3 la selva se va degradando: menos maleza y
## menos animales, más cazadores, basura y trampas, y el río cada vez más sucio.

const CANTIDAD := 3

const DATOS := [
	{
		"nombre": "Nivel 1: Selva intacta",
		"presas_para_ganar": 3,
		"sotobosque": 1400,
		"frutas": 28,
		"termiteros": 18,
		"cazadores": 0,
		"basura": 0,
		"trampas": 0,
		# Animales de la selva paranaense. Los pecaríes andan en manadas.
		"animales": {"tapir": 3, "pecari": 10, "corzuela": 7, "carpincho": 5,
			"oso_hormiguero": 3, "ocelote": 3, "yacare": 3},
		"tamano_manada": 5,
		"rio_color": Color(0.32, 0.7, 0.86),
		"rio_turbidez": 0.15,
		"rio_espuma": 0.0,
		"botellas_en_rio": 0,
		"niebla": Color(0.42, 0.52, 0.42),
		"luz": 1.3,
	},
	{
		"nombre": "Nivel 2: Selva amenazada",
		"presas_para_ganar": 3,
		"sotobosque": 900,
		"frutas": 20,
		"termiteros": 12,
		"cazadores": 2,
		"basura": 25,
		"trampas": 0,
		"animales": {"tapir": 2, "pecari": 6, "corzuela": 5, "carpincho": 3,
			"oso_hormiguero": 2, "ocelote": 3, "yacare": 2},
		"tamano_manada": 6,
		"rio_color": Color(0.34, 0.52, 0.3),
		"rio_turbidez": 0.6,
		"rio_espuma": 0.2,
		"botellas_en_rio": 12,
		"niebla": Color(0.45, 0.5, 0.42),
		"luz": 1.15,
	},
	{
		"nombre": "Nivel 3: Selva degradada",
		"presas_para_ganar": 3,
		"sotobosque": 550,
		"frutas": 14,
		"termiteros": 8,
		"cazadores": 5,
		"basura": 50,
		"trampas": 12,
		"animales": {"tapir": 1, "pecari": 4, "corzuela": 3, "carpincho": 2,
			"oso_hormiguero": 1, "ocelote": 2, "yacare": 1},
		"tamano_manada": 4,
		"rio_color": Color(0.36, 0.32, 0.23),
		"rio_turbidez": 0.92,
		"rio_espuma": 0.5,
		"botellas_en_rio": 25,
		"niebla": Color(0.5, 0.5, 0.47),
		"luz": 0.95,
	},
]


static func datos(nivel: int) -> Dictionary:
	return DATOS[clampi(nivel, 1, CANTIDAD) - 1]
