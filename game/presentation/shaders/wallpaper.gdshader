shader_type spatial;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float stripe=step(0.82,fract((wp.x+wp.z)*3.0));float age=sin(wp.x*1.8+wp.z*2.7)*sin(wp.y*3.7)*0.025;
ALBEDO=vec3(0.58,0.53,0.40)*(1.0-stripe*0.07)+age;ROUGHNESS=0.92;}
