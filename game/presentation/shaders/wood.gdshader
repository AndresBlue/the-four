shader_type spatial;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=sin(wp.y*95.0+sin((wp.x+wp.z)*7.0)*2.0);float wear=sin(wp.x*3.0+wp.z*4.0)*sin(wp.y*6.0);ALBEDO=vec3(0.24,0.145,0.085)*(0.95+grain*0.07+wear*0.08);ROUGHNESS=0.72+wear*0.1;}
