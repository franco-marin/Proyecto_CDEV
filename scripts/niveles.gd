class_name Niveles
extends RefCounted
## Configuración de cada nivel. Del 1 al 3 la selva se va degradando: menos árboles,
## maleza, animales y pájaros, más árboles talados, cazadores, basura y trampas, y el río
## cada vez más sucio.

const CANTIDAD := 3

const DATOS := [
	{
		"nombre": "Nivel 1: Selva intacta",
		"presas_para_ganar": 2,
		# Selva: árboles del dosel, palmeras pindó, helechos chachí y árboles fuera del
		# límite del mapa. "talados" son tocones y árboles caídos (la deforestación).
		"arboles_grandes": 155,
		"palmeras": 38,
		"helechos_arborescentes": 70,
		"arboles_decorativos": 80,
		"talados": 0,
		"pajaros": 14,
		"sotobosque": 1400,
		"frutas": 28,
		"termiteros": 18,
		"cazadores": 0,
		# A cuántos metros del yaguareté aparecen los cazadores al empezar: el SDD pide que
		# aumenten "en número y cercanía" nivel a nivel.
		"distancia_cazadores": 45.0,
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
		# Densidad de la niebla volumétrica (la humedad de la selva, ver main.gd).
		"niebla_volumetrica": 0.018,
		"luz": 1.3,
		# Sonido de la selva: los pájaros se van callando nivel a nivel (en el 2 hay menos y
		# en el 3 ya no se oyen animales). El volumen está en dB.
		"sonido_ambiente": "res://sonidos/sonido_naturaleza.wav",
		"volumen_ambiente": 0.0,
	},
	{
		"nombre": "Nivel 2: Selva amenazada",
		"presas_para_ganar": 2,
		"arboles_grandes": 115,
		"palmeras": 28,
		"helechos_arborescentes": 50,
		"arboles_decorativos": 60,
		"talados": 35,
		"pajaros": 6,
		"sotobosque": 900,
		"frutas": 20,
		"termiteros": 12,
		"cazadores": 2,
		"distancia_cazadores": 40.0,
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
		"niebla_volumetrica": 0.022,
		"luz": 1.15,
		"sonido_ambiente": "res://sonidos/sonido_ambiente_nivel_2.wav",
		"volumen_ambiente": 0.0,
	},
	{
		"nombre": "Nivel 3: Selva degradada",
		"presas_para_ganar": 2,
		"arboles_grandes": 70,
		"palmeras": 16,
		"helechos_arborescentes": 28,
		"arboles_decorativos": 40,
		"talados": 80,
		"pajaros": 2,
		"sotobosque": 550,
		"frutas": 14,
		"termiteros": 8,
		"cazadores": 3,
		"distancia_cazadores": 22.0,
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
		"niebla_volumetrica": 0.028,
		"luz": 0.95,
		"sonido_ambiente": "res://sonidos/sonido_ambiente_nivel_3.wav",
		"volumen_ambiente": 0.0,
	},
]


static func datos(nivel: int) -> Dictionary:
	return DATOS[clampi(nivel, 1, CANTIDAD) - 1]
