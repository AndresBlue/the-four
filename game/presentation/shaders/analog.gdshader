shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vhs=0.18;
uniform float grain=0.12;
uniform float chromatic=0.08;
void fragment(){vec2 uv=SCREEN_UV;
float n=fract(sin(dot(uv+fract(TIME),vec2(12.9898,78.233)))*43758.5453);uv.x+=sin(uv.y*450.0+TIME*2.0)*vhs*0.0004;vec3 c=texture(screen_texture,uv).rgb;c.r=texture(screen_texture,uv+vec2(chromatic*0.001,0.0)).r;c.b=texture(screen_texture,uv-vec2(chromatic*0.001,0.0)).b;c+=(n-0.5)*grain*0.12;
c*=1.0-vhs*0.12*(0.5+0.5*sin(uv.y*850.0));COLOR=vec4(c,1.0);}
