shader_type spatial;
uniform float motion=1.0;
void vertex(){VERTEX.z+=sin(TIME*0.7+VERTEX.x*8.0)*0.035*motion*(1.0-UV.y);}
void fragment(){ALBEDO=vec3(0.26,0.19,0.13)*(0.85+0.15*sin(UV.x*90.0));ROUGHNESS=0.95;}
