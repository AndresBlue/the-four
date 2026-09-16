shader_type spatial;
varying vec3 wp;
uniform vec4 base_color : source_color;
uniform float pattern = 1.0;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float n=fract(sin(dot(floor(wp.xz*190.0),vec2(12.9898,78.233)))*43758.5453);
float grid=step(0.92,fract(wp.x*0.65))*step(0.92,fract(wp.z*0.65));
ALBEDO=base_color.rgb*(0.88+n*0.18-grid*pattern*0.3);
ROUGHNESS=0.96;}
