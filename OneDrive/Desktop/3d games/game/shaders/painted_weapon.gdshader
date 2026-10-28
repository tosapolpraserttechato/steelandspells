shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// A clean, hand-painted look for the weapons. The shapes stay simple; the paint adds the details:
//  - each part is recognised from the model's own colour (steel, dark iron, wood, leather, brass, bone, enchanted gem) and painted in one tidy palette,
//  - steel shades from dark at the guard to bright at the tip, with a fine engraved line down the middle of the blade (a glowing line on magic weapons),
//  - grips and shafts get wrapped bands, brass gets a warm gradient,
//  - gems and crystals glow in the weapon's element colour, and everything gets a soft rim light.

uniform sampler2D src_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 src_col = vec4(1.0);
uniform bool use_tex = false;
uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform vec3 glow_color = vec3(1.0, 0.5, 0.2);   // sRGB
uniform float glow_strength = 0.0;      // 0 = plain weapon, 1 = strongly enchanted
uniform vec3 steel_tint = vec3(0.5, 0.52, 0.55);   // sRGB, a faint element tint for the steel
uniform float unit = 1.0;               // longest side of the model
uniform vec3 ax_long = vec3(0.0, 1.0, 0.0);
uniform vec3 ax_width = vec3(1.0, 0.0, 0.0);
uniform vec3 center = vec3(0.0);
uniform bool crystal = false;           // orbs: a glowing crystal instead of a painted object
uniform vec3 skin_tint = vec3(1.0);        // a skin pasted over the weapon (sRGB colour) and how much of the metal it covers
uniform float skin_mix = 0.0;
uniform float wear = 0.0;                  // an old, worn weapon: rust, dull metal, no glow (0 = as new)

varying vec3 obj_pos;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 src = src_col.rgb;
	if (use_tex) {
		src *= texture(src_tex, UV).rgb;
	}
	vec3 hsv = rgb2hsv(src);
	float h = hsv.x;
	float s = hsv.y;
	float v = hsv.z;
	vec3 p = (obj_pos - center) / max(unit, 0.001);
	float along = dot(p, ax_long);        // -0.5 .. 0.5 from one end to the other
	float across = dot(p, ax_width);
	float soft = texture(noise_a, p.xy * 1.3 + p.yz * 0.7).r;   // very soft blotches, a hint of brush work

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	if (crystal) {
		vec3 c = glow_color * (0.55 + 0.25 * soft);
		ALBEDO = lin(c);
		ROUGHNESS = 0.1;
		METALLIC = 0.0;
		float pulse = 0.5 + 0.5 * sin(TIME * 1.6);
		EMISSION = lin(glow_color) * (0.55 + 0.35 * pulse) + lin(mix(glow_color, vec3(1.0), 0.6)) * fres * 0.9;
	} else {
		// ---- what is it made of? (weights from the source colour)
		float grey = 1.0 - smoothstep(0.12, 0.26, s);
		float w_steel = grey * smoothstep(0.5, 0.66, v);
		float w_iron = grey * (1.0 - smoothstep(0.5, 0.66, v));
		float warm = smoothstep(0.2, 0.34, s) * (1.0 - smoothstep(0.1, 0.13, h)) * smoothstep(0.0, 0.03, h);   // orange-brown
		float w_wood = warm * smoothstep(0.34, 0.5, v) * (1.0 - smoothstep(0.78, 0.9, v));
		float w_leather = warm * (1.0 - smoothstep(0.34, 0.5, v));
		float w_gold = smoothstep(0.28, 0.42, s) * smoothstep(0.09, 0.12, h) * (1.0 - smoothstep(0.17, 0.2, h)) * smoothstep(0.55, 0.7, v);
		float w_bone = smoothstep(0.08, 0.14, s) * (1.0 - smoothstep(0.26, 0.34, s)) * smoothstep(0.7, 0.8, v) * smoothstep(0.07, 0.1, h) * (1.0 - smoothstep(0.15, 0.2, h));
		float w_gem = smoothstep(0.45, 0.6, s) * (1.0 - warm) * (1.0 - w_gold);
		float tot = w_steel + w_iron + w_wood + w_leather + w_gold + w_bone + w_gem;
		if (tot < 0.05) {
			w_iron = 1.0;
			tot = 1.0;
		}
		w_steel /= tot; w_iron /= tot; w_wood /= tot; w_leather /= tot; w_gold /= tot; w_bone /= tot; w_gem /= tot;

		// ---- palette (sRGB): clean and a little dark
		float grad = clamp(along + 0.5, 0.0, 1.0);   // 0 at the pommel end, 1 at the tip
		vec3 steel = mix(vec3(0.5, 0.54, 0.62), vec3(0.84, 0.88, 0.95), smoothstep(0.15, 0.95, grad));
		steel = mix(steel, steel * (steel_tint * 2.0), 0.18);
		steel *= 0.94 + 0.1 * soft;
		vec3 iron = mix(vec3(0.3, 0.32, 0.4), vec3(0.5, 0.53, 0.62), grad * 0.7 + soft * 0.2);
		vec3 gold = mix(vec3(0.68, 0.46, 0.14), vec3(0.98, 0.8, 0.34), 0.5 + 0.5 * soft);
		vec3 wood = mix(vec3(0.66, 0.46, 0.27), vec3(0.5, 0.33, 0.19), 0.5 + 0.5 * sin(across * 30.0 + soft * 4.0));
		vec3 leather = vec3(0.5, 0.26, 0.19);
		vec3 bone = mix(vec3(0.82, 0.76, 0.62), vec3(0.62, 0.55, 0.44), soft);
		vec3 gem = src * mix(0.62, 1.1, smoothstep(0.1, 0.95, grad));

		// wrapped bands on grips and shafts
		float bands = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(along * 330.0));
		leather = mix(leather, leather * 0.55, bands);
		wood = mix(wood, wood * 0.82, bands * 0.35);

		vec3 albedo = steel * w_steel + iron * w_iron + wood * w_wood + leather * w_leather + gold * w_gold + bone * w_bone + gem * w_gem;
		albedo *= mix(0.88, 1.12, v);   // keep a little of the model's own light/dark pattern
		if (skin_mix > 0.0) {
			float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
			vec3 painted = skin_tint * (0.42 + 1.15 * lum);
			float part = clamp(w_steel + w_iron + 0.75 * w_gold + 0.5 * w_bone + 0.45 * (w_wood + w_leather), 0.0, 1.0);
			albedo = mix(albedo, painted, skin_mix * part);
		}
		if (wear > 0.0) {
			float rn = texture(noise_a, p.xy * 3.1 + p.zx * 2.3).r;
			float rpatch = smoothstep(0.36, 0.6, rn + 0.15 * soft);
			vec3 rust = mix(vec3(0.33, 0.17, 0.08), vec3(0.55, 0.3, 0.12), soft);
			float rpart = clamp(w_steel + w_iron + 0.6 * w_gold + 0.4 * w_bone, 0.0, 1.0);
			albedo = mix(albedo * vec3(0.8, 0.74, 0.68), rust, clamp(wear * (0.18 + 0.75 * rpatch) * rpart + wear * 0.1, 0.0, 1.0));
		}
		float metal = (0.4 * w_steel + 0.35 * w_iron + 0.5 * w_gold + 0.1 * w_gem) * (1.0 - 0.6 * wear);
		float rough = 0.36 * w_steel + 0.5 * w_iron + 0.78 * (w_wood + w_leather) + 0.4 * w_gold + 0.7 * w_bone + 0.15 * w_gem;
		rough = mix(rough, 0.93, wear * 0.85);

		// ---- the engraved line down the middle (a glowing inlay on magic weapons)
		float line = 1.0 - smoothstep(0.004, 0.012, abs(across));
		float line_on = line * (w_steel + 0.6 * w_iron) * smoothstep(-0.05, 0.1, along);
		albedo *= 1.0 - 0.28 * line_on * (1.0 - glow_strength);

		// ---- enchantment
		float pulse = 0.88 + 0.12 * sin(TIME * 2.2 + along * 8.0);
		vec3 emit = lin(mix(src * 1.25, glow_color, 0.3 + 0.5 * glow_strength)) * w_gem * (0.9 + 1.0 * glow_strength) * pulse;
		emit += lin(glow_color) * line_on * glow_strength * 2.2 * pulse;
		emit += lin(glow_color) * fres * glow_strength * 0.15;
		emit += lin(vec3(0.55, 0.65, 0.9)) * fres * 0.05;

		ALBEDO = clamp(lin(albedo), vec3(0.0), vec3(1.0));
		METALLIC = clamp(metal, 0.0, 1.0);
		ROUGHNESS = clamp(rough, 0.05, 1.0);
		EMISSION = emit * (1.0 - 0.9 * wear);
	}
}
