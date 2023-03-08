#version 430
#define debugmov 0
#define shadertoy 0 //noexport
#define doAA 1
#define partialrender 1
layout (location=0) uniform vec4 fpar[2];
layout (location=2) uniform vec4 debug[2]; //noexport
layout (location=4) uniform sampler2D tex;
#define MAT_KEY_BLACK 0
#define MAT_KEY_WHITE 1
#define MAT_BLACK_NOISE 2
#define MAT_BLACK_SHINY 3
#define ROUNDING .1
int i;
vec3 gHitPosition = vec3(0);

float rand(vec2 p){return fract(sin(dot(p.xy,vec2(12.9898,78.233)))*43758.5453);}
mat2 rot2(float a){float s=sin(a),c=cos(a);return mat2(c,s,-s,c);}

// https://iquilezles.org/articles/distfunctions/

vec4 opElongate(vec3 p, vec3 h)
{
	return vec4(p-clamp(p,-h,h),.0);
}

float sdCappedCylinder(vec3 p, vec2 h)
{
	vec2 d = abs(vec2(length(p.xy),p.z)) - h;
	return min(max(d.x,d.y),.0) + length(max(d,.0));
}

// better box that works for subtraction //noexport
float box(vec3 p, vec3 b)
{
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec2 m(vec2 b, vec2 a){return a.x<b.x?a:b;}

// sizes are cm (div 2 ofc because abs) //noexport

// rounding-adjusted vec3 //noexport
vec3 rndav3(float x, float y, float z)
{
	return vec3(x,y,z)-ROUNDING;
}

float key(vec3 p)
{
	vec3 topoff = vec3(0., 0., -1.05);
	vec4 w = opElongate(p, rndav3(1., 7.6, 0.));
	float top = w.w + sdCappedCylinder(w.xyz - topoff, vec2(.1, .1));
	return min(
		length(max(abs(p) - rndav3(1.1, 7.5, 1.12), 0.)), // base
		max(top, -box(p-topoff-vec3(0.,0.,1.-ROUNDING), vec3(4., 10., 1.)))
	) - .03;
}

float bkey(vec3 p)
{
	vec3 q = p;
	q.y -= 3.93;
	q.z += .086;
	vec3 r = q;
	r.yz *= rot2(.9);
	r.y -= .31;
	float k = min(
		length(max(abs(p + vec3(0.,0.2,0.)) - rndav3(.5, 4.7, 1.), 0.)),
		length(max(abs(r) - rndav3(.5, .75, .98), 0.))
	);
	k = min(k, length(max(abs(q-vec3(0.,0.,1.006)) - rndav3(.5, 1.385, .9), 0.)));
	// TODO: do this or not?, top rounding is cool but it messes with the side rounding
#if 1
	k = max(k, min(
		length(p.yz-vec2(4.09,-.3)) - .65,
		min(
			dot(p+vec3(0.,0.,.7),vec3(0.,0.,-1.)),
			dot(p+vec3(0.,-4.,0.),vec3(0.,1.,0.))
		)
	));
#endif
	return k;
}

vec2 map(vec3 p)
{
	p.xz *= rot2(-.06);
	float ground = dot(p,vec3(0.,0.,-1.));
	p.y += 10.;
	vec2 r = vec2(9e9, MAT_BLACK_SHINY);
	p.z += 2.;
	vec3 f = p; // p but rotated for the pressed keys
	f.y -= 5.;
	f.yz *= rot2(.07);
	f.y += 5.;
	f.z -= .8;
	vec3 o = vec3(2.3,0.,0.);
	float w = 9e9;

	float b = 9e9;
	// q = position adjusted for black keys //noexport
	vec3 q = p + vec3(0.,2.8,1.4);
//#define k(o) b=min(b, bkey(q+o));w=max(w,-(length(max(abs(q) - vec3(3.), 0.))))
#define k(o) b=min(b, bkey(q+o));w=max(w,-box(q+o, vec3(.75, 5.55, 2.)))

	for (int i = -1; i < 3; i++) {
		vec3 oo = o * (i - 1) * 7;
		vec3 m = i == 1 ? f : p;
		w = min(w, key(oo + p - o*2.));
		w = min(w, key(oo + p - o));
		w = min(w, key(oo + m));
		w = min(w, key(oo + p + o));
		w = min(w, key(oo + m + o*2.));
		w = min(w, key(oo + p + o*3.));
		w = min(w, key(oo + m + o*4.));

		k(oo + -o*1.6);
		k(oo + -o*.5);
		k(oo + o*.6);
		k(oo + o*2.45);
		k(oo + o*3.55);
	}

	r = m(r, vec2(w - ROUNDING, MAT_KEY_WHITE));
	r = m(r, vec2(b - ROUNDING, MAT_KEY_BLACK));
	r = m(r, vec2(length(max(abs(p.yz-vec2(8.1,2.4)) - vec2(.4,2.), 0.)) - .1, MAT_BLACK_NOISE));
	r = m(r, vec2(length(max(abs(p.yz-vec2(-10.7,0.)) - vec2(3.,3.), 0.)) - .1, MAT_BLACK_NOISE));
	// more backside for more shiny shit
	r = m(r, vec2(length(max(abs(p.yz-vec2(-9.7,0.)) - vec2(2.05,2.85), 0.)) - .1, MAT_KEY_BLACK));
	if (ground < r.x) return vec2(ground, MAT_BLACK_SHINY);
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
		res = min(res, 18.*d/max(0.0,dist-y));
		ph = h;
		dist += h;
	}
	return res;
}

// w component is amount of reflection mix //noexport
vec4 getmat(vec4 r)
{
	switch (int(r.w)) {
	case MAT_KEY_BLACK: return vec4(.007,.007,.007,.4);
	case MAT_KEY_WHITE: return vec4(vec3(218.,216.,227.)/255., .6);
	case MAT_BLACK_NOISE: return vec4(vec3(.05+.05*rand(mod(vec2(r.z,r.y),10))), 0.);
	case MAT_BLACK_SHINY: return vec4(0.);
	}
	return vec4(0., 1., 0., 3.);
}

vec3 colorHit(vec4 result, vec3 rd, vec3 normal, vec3 mat)
{
	// key light
	vec3 lig = normalize(vec3(-.2, -0.1, -0.6));
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

	vec3 ro = vec3(-13., 1., -11.);
	vec3 at = vec3(-5., -10., 0.);

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
#if shadertoy == 1 //noexport
			vec2 o = v + vec2(float(aab),float(aab)) / 2. - 0.5; //noexport
			vec2 uv = (o-.5*iResolution.xy)/iResolution.y; //noexport
#else //noexport
			vec2 iResolution = fpar[0].xy;
			vec2 uv = v*(iResolution + vec2(float(aaa),float(aab))/4)/iResolution;
			uv.y /= iResolution.x/iResolution.y;
#endif //noexport
			vec3 rd = rdbase*normalize(vec3(uv,1)), col = vec3(0.);

			vec4 result = march(ro, rd, 200);

			if (result.x > 0.) { // hit
				vec3 normal = norm(gHitPosition, result.y);
				vec4 mat = getmat(result) * .3;
				// reflexxions
				if (mat.w > .0001) {
					vec3 gg = gHitPosition;
					rd = reflect(rd, normal);
					gHitPosition += .001 * rd;
					vec4 nr = march(gHitPosition, rd, 200);
					if (result.x > 0.) {
						vec3 nn = norm(gHitPosition, result.y);
						vec3 m = getmat(nr).xyz;
						vec3 nc = colorHit(nr, rd, nn, m);
						mat.xyz = mix(mat.xyz, nc * mat.w, mat.w);
					}
					gHitPosition = gg;
				}
				col = colorHit(result, rd, normal, mat.xyz);
			}
			resultcol += col;
#if doAA == 1
		}
	}
	resultcol /= 4.;
#endif

	c = vec4(pow(resultcol, vec3(.4545)), 1.0); // pow for gamma correction because all the cool kids do it
}
