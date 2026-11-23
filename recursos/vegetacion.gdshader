// Shader de la vegetación de la selva.
// Además del color, "recorta" (no dibuja) la vegetación en dos zonas para que el
// yaguareté se vea al moverse entre la maleza:
//   1) Un cilindro alrededor del jugador (solo para plantas del sotobosque).
//   2) En tercera persona, un círculo en la pantalla alrededor del jugador, solo para
//      lo que está entre la cámara y él.
// Los datos del jugador llegan como "uniforms globales" (Proyecto > Configuración >
// Shader Globals), que main.gd actualiza en cada frame.
shader_type spatial;

uniform vec4 color : source_color = vec4(0.2, 0.45, 0.18, 1.0);
uniform float aspereza = 0.9;
// 1 = esta planta se recorta en el cilindro alrededor del jugador (sotobosque).
uniform float recorte_cercano = 0.0;

// Variación de color por planta (la pone main.gd con set_instance_shader_parameter).
instance uniform vec3 tinte = vec3(1.0);

global uniform vec3 jugador_posicion;
global uniform float maleza_radio;
global uniform vec2 jugador_pantalla;
global uniform float circulo_radio;
global uniform float jugador_distancia_camara;

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Tramado ordenado (Bayer 4x4): en vez de transparencia, el borde del recorte se
// disuelve en un patrón de puntos, que es mucho más barato de dibujar.
float umbral_tramado(vec2 pixel) {
	const float matriz[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	return (matriz[y * 4 + x] + 0.5) / 16.0;
}

void fragment() {
	ALBEDO = color.rgb * tinte;
	ROUGHNESS = aspereza;

	float visible = 1.0;

	// 1) Cilindro alrededor del jugador: el sotobosque cercano desaparece.
	if (recorte_cercano > 0.5) {
		float distancia = distance(posicion_mundo.xz, jugador_posicion.xz);
		visible = min(visible, smoothstep(maleza_radio * 0.6, maleza_radio, distancia));
	}

	// 2) Círculo en pantalla (tercera persona): lo que tapa al jugador desaparece.
	if (circulo_radio > 0.0) {
		vec2 desde_centro = (SCREEN_UV - jugador_pantalla) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float en_circulo = smoothstep(circulo_radio * 0.7, circulo_radio, length(desde_centro));
		// VERTEX está en espacio de cámara: su largo es la distancia a la cámara.
		float delante_del_jugador = step(length(VERTEX), jugador_distancia_camara - 0.8);
		visible = min(visible, mix(1.0, en_circulo, delante_del_jugador));
	}

	if (visible < 0.999 && visible < umbral_tramado(FRAGCOORD.xy)) {
		discard;
	}
}
