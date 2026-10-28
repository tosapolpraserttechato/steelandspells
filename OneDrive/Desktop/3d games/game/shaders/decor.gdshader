shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Small scattered decorations (flowers, grass, mushrooms, crystals...). The mesh vertex colour holds each part's own shade; its alpha is a tint mask.
// Where the mask is 1 the part takes the colour of the instance (MultiMesh custom data rgb), so one mesh can be any colour. Custom data alpha is a random
// number per instance: it varies the greens a little, sets the phase of the sway in the wind and the pulse of glowing kinds.

uniform float sway = 0.06;          // how much the top bends in the wind (m per m of height squared)
uniform float glow = 0.0;           // emission strength of the tinted parts (glowing flowers, mushrooms, crystals)
uniform float roughness = 0.75;
uniform float tint_boost = 1.0;

varying vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
	float h = max(VERTEX.y, 0.0);
	float ph = inst.a * 6.2831 + TIME * 1.7;
	VERTEX.x += sin(ph + VERTEX.z * 3.0) * sway * h * h;
	VERTEX.z += cos(ph * 0.83 + VERTEX.x * 3.0) * sway * 0.6 * h * h;
}

void fragment() {
	float mask = COLOR.a;
	float v = fract(inst.a * 7.13);
	vec3 lin = pow(COLOR.rgb, vec3(2.2));
	vec3 own = lin * (0.88 + 0.24 * v);
	vec3 tinted = inst.rgb * (0.42 + 0.78 * COLOR.r) * tint_boost;
	ALBEDO = mix(own, tinted, mask);
	ROUGHNESS = roughness;
	if (glow > 0.0) {
		float pulse = 0.82 + 0.18 * sin(TIME * 2.0 + inst.a * 6.2831);
		EMISSION = inst.rgb * mask * glow * pulse * (0.5 + 0.5 * COLOR.r);
	}
}
