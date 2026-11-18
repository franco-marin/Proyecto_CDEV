// Shader del pasto corto: las briznas son más oscuras abajo y más claras en la punta,
// se mecen con el viento (la punta se mueve, la base queda fija) y el tono varía un
// poco de una zona a otra para que el suelo no se vea uniforme.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color_base : source_color = vec4(0.16, 0.28, 0.09, 1.0);
uniform vec4 color_punta : source_color = vec4(0.42, 0.58, 0.2, 1.0);
uniform float viento = 0.05;

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UV.y es 0 en la base de la brizna y 1 en la punta.
	float altura = UV.y;
	VERTEX.x += sin(TIME * 1.6 + posicion_mundo.x * 0.7 + posicion_mundo.z * 0.5) * viento * altura;
	VERTEX.z += cos(TIME * 1.3 + posicion_mundo.z * 0.6) * viento * altura * 0.6;
}

void fragment() {
	float zona = fract(sin(dot(floor(posicion_mundo.xz * 0.4), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 color = mix(color_base.rgb, color_punta.rgb, UV.y);
	ALBEDO = color * mix(0.85, 1.1, zona);
	ROUGHNESS = 0.9;
}
