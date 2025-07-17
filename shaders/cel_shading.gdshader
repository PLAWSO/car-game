shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float threshold = 0.2;

uniform int steps = 1; // number of brightness bands

//void fragment() {
    //vec3 color = texture(screen_texture, SCREEN_UV).rgb;
    //float intensity = dot(color, vec3(0.299, 0.587, 0.114));
    //float band = floor(intensity * float(steps)) / float(steps);
    //float scale = band / max(intensity, 0.001);
    //COLOR = vec4(color * scale, 1.0);
//}

void fragment() {
    vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(color, 1.0);
}

//void fragment() {
	//float r = floor(color.r / threshold) * threshold;
	//float g = floor(color.g / threshold) * threshold;
	//float b = floor(color.b / threshold) * threshold;
	//
	//COLOR = vec4(r, g, b, 1.0);
//}
