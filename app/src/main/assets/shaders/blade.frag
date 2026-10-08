#version 310 es
precision mediump float;
in vec4 vColor;
in vec2 vUV;
out vec4 FragColor;
void main(){
float t=vUV.y;
vec3 c=vColor.rgb*(0.7+0.3*t);
FragColor=vec4(c,1.0);
}
