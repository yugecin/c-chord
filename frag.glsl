#version 430
#define debugmov 1
#define shadertoy 0
#define doAA 0
#define partialrender 0
#define iTime fpar[0].x
layout (location=0) uniform vec4 fpar[2];
layout (location=2) uniform vec4 debug[2]; //noexport
layout (location=4) uniform sampler2D tex;
#define PI 3.14159265359
#define HALFPI 1.5707963268
#define MAT_BG 1
#define MAT_BLACK 2
#define MAT_WHITE 3
int i;
vec3 gHitPosition = vec3(0);

mat2 rot2(float a){float s=sin(a),c=cos(a);return mat2(c,s,-s,c);}

// https://iquilezles.org/articles/distfunctions/
float ss(float a, float b, float k)
{
	float h = clamp(0.5 - 0.5*(b+a)/k, 0.0, 1.0);
	return mix(b, -a, h) + k*h*(1.0-h);
}

vec4 opElongate(vec3 p, vec3 h)
{
	return vec4(p-clamp(p,-h,h),.0);
}

float sdCappedCylinder(vec3 p, vec2 h)
{
	vec2 d = abs(vec2(length(p.xy),p.z)) - h;
	return min(max(d.x,d.y),.0) + length(max(d,.0));
}

vec2 m(vec2 b, vec2 a){return a.x<b.x?a:b;}

float key(vec3 p)
{
	vec4 w = opElongate(p, vec3(1., 7.6, 0.));
	float top = w.w + sdCappedCylinder(w.xyz - vec3(0., 0., -1.05), vec2(.1, .1));
	top = max(top, -(length(max(abs(p) - vec3(1.1, 10., 9.), 0.))));
	return min(
		length(max(abs(p) - vec3(1.1, 7.5, 1.), 0.)), // base
		top
	) - .03;
}

vec2 map(vec3 p)
{
	p.y += 10.;
	float ground = dot(p,normalize(vec3(0.,0.,-1.)));
	vec2 r = vec2(9e9, MAT_BLACK);
	p.z += 2.;
	/*
	this crashes something :D
	float x = 0.;
	//for (float x = -5.; x < 5.; x += 1.) {
		vec3 q = p;
		q.x += x * .23;
		vec2 key = vec2(length(max(abs(q) - vec3(.22, 1.50, .2), 0.)), MAT_WHITE);
		r = (m, key);
	//}
	*/
	//r = m(r, keys(p));
	vec3 offs = vec3(2.3,0.,0.);
	float w = key(p - offs*2.);
	w = min(w, key(p - offs));
	w = min(w, key(p));
	w = min(w, key(p + offs));
	w = min(w, key(p + offs*2.));

	r = m(r, vec2(w, MAT_WHITE));
	if (ground < r.x) return vec2(ground, MAT_BG);
	return r;
}

vec3 norm(vec3 p, float dist_to_p)
{
	vec2 e=vec2(.0035,-.0035);
	return normalize(e.xyy*map(p+e.xyy).x+e.yyx*map(p+e.yyx).x+e.yxy*map(p+e.yxy).x+e.xxx*map(p+e.xxx).x);
}

// x=hit y=dist_to_p z=dist_to_ro w=material(if hit)
vec4 march(vec3 ro, vec3 rd, int maxSteps)
{
	vec4 r = vec4(0);
	for (i = 0; i < maxSteps && r.z < 350.; i++){
		gHitPosition = ro + rd * r.z;
		vec2 m = map(gHitPosition);
		float dist = m.x;
		if (dist < .0001) {
			r.x = float(i)/float(maxSteps);
			r.y = dist;
			r.w = m.y;
			break;
		}
		r.z += dist;
	}
	return r;
}

float calcAO(vec3 pos, vec3 nor )
{
	float occ = 0.0;
	float sca = 1.0;
	for( int i=0; i<5; i++ ) {
		float h = 0.001 + 0.15*float(i)/4.0;
		float d = map( pos + h*nor ).x;
		occ += (h-d)*sca;
		sca *= 0.95;
	}
	return clamp( 1.0 - 1.5*occ, 0.0, 1.0 );
}

float softshadow(vec3 ro, vec3 rd)
{
	float res = 1.0;
	float ph = 9e9;
	for(float dist = 0.01; dist < 40.; ) {
		float h = map(ro + rd*dist).x;
		if (h<0.001) {
			return 0.0;
		}
		float y = h*h/(2.0*ph);
		float d = sqrt(h*h-y*y);
		res = min(res, 6.*d/max(0.0,dist-y));
		ph = h;
		dist += h;
	}
	return res;
}

vec3 getmat(float m)
{
	switch (int(m)) {
	case MAT_BG: return vec3(.53,.23,.09);
	case MAT_BLACK: return vec3(.0);
	case MAT_WHITE: return vec3(1.);
	}
	return vec3(0., 1., 0.);
}

vec3 colorHit(vec4 result, vec3 rd, vec3 normal, vec3 mat)
{
	// key light
	vec3 lig = normalize(vec3(.3, -0.1, -0.6));
	vec3 hal = normalize(lig-rd);
	float dif = clamp(dot(normal, lig), .0, 1.) * softshadow(gHitPosition, lig);

	float spe = pow(clamp(dot(normal, hal), .0, 1. ),16.0)* dif *
	(0.04 + 0.96*pow(clamp(1.0+dot(hal,rd),.0,1.), 5.0));

	vec3 col = mat * 3.0*dif;
	col += 12.0*spe*vec3(1.00,0.70,0.5);

	// ambient light
	float occ = calcAO(gHitPosition, normal);
	float amb = clamp(0.5+0.5*normal.y, 0.0, 1.0 );
	col += mat*amb*occ*vec3(.1);

	// fog
	float t = result.z;
	col *= exp(-0.000007*t*t*t);
	//col *= exp(-0.00007*t);
        //col *= exp(-0.0005*t*t*t);
	return col;
}

out vec4 c;
in vec2 v;
void main()
{
	vec2 normuv = (v + 1.) / 2;
#if partialrender == 1
	vec2 from = fpar[0].zw;
	if (!(normuv.x < from.x && from.x < normuv.x + .11 &&
		normuv.y < from.y && from.y < normuv.y + .11))
	{
		c = vec4(texture(tex,normuv).xyz, 1.);
		return;
	}
#endif


	//vec3 ro = vec3(3, 14, -12) * 1.3;
	//vec3 at = vec3(1, 0, -8);
	vec3 ro = vec3(-3, -11, -3.2) * 1.27;
	vec3 at = vec3(0,-11.9,-.4);

#if debugmov //noexport
	ro = debug[0].xyz/20.; //noexport
	float vertAngle = debug[1].y/20.; //noexport
	float horzAngle = debug[1].x/20.; //noexport
	if (abs(vertAngle) < .001) { //noexport
		vertAngle = .001; //noexport
	} //noexport
	float xylen = sin(vertAngle); //noexport
	vertAngle = cos(vertAngle); //noexport
	at.x = ro.x + cos(horzAngle) * xylen; //noexport
	at.y = ro.y + sin(horzAngle) * xylen; //noexport
	at.z = ro.z + vertAngle; //noexport
#endif //noexport

        vec3	cf = normalize(at-ro),
		cl = normalize(cross(cf,vec3(0,0,-1)));
	mat3 rdbase = mat3(cl,normalize(cross(cl,cf)),cf);

	vec3 resultcol = vec3(0.);
#if doAA == 1
	for (int aaa = 0; aaa < 2; aaa++) {
		for (int aab = 0; aab < 2; aab++) {
#else
	int aaa = 0, aab = 0;
#endif
#if shadertoy == 1
			vec2 o = v + vec2(float(aab),float(aab)) / 2. - 0.5;
			vec2 uv = (o-.5*iResolution.xy)/iResolution.y;
#else
			//vec2 uv=v;uv.y/=1.77;
			//vec2 uv=v;uv.y/=1.77;
			vec2 iResolution = fpar[0].xy;
			//vec2 o = v*iResolution + vec2(float(aaa),float(aab)) / 4. - 0.5;
			//vec2 uv = (o-.5*iResolution)/iResolution.y;
			vec2 uv = v*(iResolution + vec2(float(aaa),float(aab))/4)/iResolution;
			uv.y /= iResolution.x/iResolution.y;
#endif
			vec3 rd = rdbase*normalize(vec3(uv,1)), col = vec3(0.);

			vec4 result = march(ro, rd, 200);

			if (result.x > 0.) { // hit
				vec3 normal = norm(gHitPosition, result.y);
				vec3 mat = getmat(result.w) * .3;
				/*
				// reflexxions
				if (result.w == MAT_BG) {
					vec3 gg = gHitPosition;
					rd = reflect(rd, normal);
					gHitPosition += .001 * rd;
					vec4 nr = march(gHitPosition, rd, 200);
					if (result.x > 0.) {
						vec3 nn = norm(gHitPosition, result.y);
						vec3 m = getmat(nr.w);
						mat = mix(mat, colorHit(nr, rd, nn, m) * .3, .3);
					}
					gHitPosition = gg;
				}
				*/
				col = colorHit(result, rd, normal, mat);
			}
			resultcol += col;
#if doAA == 1
		}
	}
	resultcol /= 4.;
#endif

	c = vec4(pow(resultcol, vec3(.4545)), 1.0); // pow for gamma correction because all the cool kids do it
}