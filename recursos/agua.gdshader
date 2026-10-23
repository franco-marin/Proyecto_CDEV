// Shader del agua del río: ondas animadas, transparencia según lo sucia que esté
// y manchas de espuma o suciedad flotando (niveles 2 y 3).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color_agua : source_color = vec4(0.32, 0.7, 0.86, 1.0);
// 0 = agua limpia y transparente, 1 = turbia y opaca.
uniform float turbidez = 0.15;
// Cantidad de espuma o suciedad flotando (0 = nada).
uniform float espuma = 0.0;
uniform vec4 color_espuma : source_color = vec4(0.82, 0.8, 0.68, 1.0);

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ondas(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 1.6) * 0.5 + sin(p.y * 1.7 - t * 1.2) * 0.5 + sin((p.x + p.y) * 0.6 + t * 0.8);
}

// Ruido suave (para las manchas de espuma).
float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1, 0)), u.x), mix(azar(i + vec2(0, 1)), azar(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = posicion_mundo.xz;
	float t = TIME;

	// Normal de las ondas (se calcula comparando la altura de puntos vecinos).
	float paso = 0.2;
	float h = ondas(p, t);
	float hx = ondas(p + vec2(paso, 0.0), t);
	float hz = ondas(p + vec2(0.0, paso), t);
	vec3 normal_mundo = normalize(vec3(h - hx, paso * 8.0, h - hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);

	vec3 color = color_agua.rgb;
	float manchas = espuma * smoothstep(0.55, 0.75, ruido(p * 0.7 + vec2(t * 0.15, t * 0.05)));
	color = mix(color, color_espuma.rgb, manchas);

	ALBEDO = color;
	ROUGHNESS = mix(0.05, 0.5, turbidez);
	SPECULAR = 0.6;
	// Bordes más transparentes para que el agua se funda con la orilla.
	float borde = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALPHA = mix(0.55, 0.97, turbidez) * borde;
}
