//--------------------------------------------------------------------------------------
// Vertex shader constants
//--------------------------------------------------------------------------------------
uniform float4x4 g_mWorld;
uniform float g_fApplicationTime;
uniform float g_fDisplacement;

//--------------------------------------------------------------------------------------
// Pixel shader constants
//--------------------------------------------------------------------------------------
sampler2D TextureSampler : register(s0);

float randomNoise(float2 p) {
  return frac(6791.*sin(47.*p.x+p.y*9973.));
}

float smoothNoise(float2 p) {
  float2 nn = float2(p.x, p.y+1.);
  float2 ee = float2(p.x+1., p.y);
  float2 ss = float2(p.x, p.y-1.);
  float2 ww = float2(p.x-1., p.y);
  float2 cc = float2(p.x, p.y);
 
  float sum = 0.;
  sum += randomNoise(nn)/8.;
  sum += randomNoise(ee)/8.;
  sum += randomNoise(ss)/8.;
  sum += randomNoise(ww)/8.;
  sum += randomNoise(cc)/2.;
 
  return sum;
}

float interpolatedNoise(float2 p) {
  float q11 = smoothNoise(float2(floor(p.x), floor(p.y)));
  float q12 = smoothNoise(float2(floor(p.x), ceil(p.y)));
  float q21 = smoothNoise(float2(ceil(p.x), floor(p.y)));
  float q22 = smoothNoise(float2(ceil(p.x), ceil(p.y)));
 
  float2 s = smoothstep(0.0f, 1.0f, frac(p) );
 
  float r1 = lerp(q11, q21, s.x);
  float r2 = lerp(q12, q22, s.x);
 
  return lerp (r1, r2, s.y);
}

struct VERTEX_IN 
{
	float4 ObjPos 	: POSITION;
	float2 Tex		: TEXCOORD0;
};

struct VERTEX_TO_PIXEL 
{
	float4 ProjPos	: POSITION;
	float2 Tex		: TEXCOORD0;
	float3 PosL 	: TEXCOORD1;
	float3 PosW		: TEXCOORD2;
};

VERTEX_TO_PIXEL ShadeVertex ( VERTEX_IN In )
{
	VERTEX_TO_PIXEL Out;
	Out.ProjPos = mul( g_mWorld, In.ObjPos );
	Out.Tex = In.Tex;
	Out.PosL = In.ObjPos;
	Out.PosW = Out.ProjPos;

	return Out;
}

float4 ShadePixel( VERTEX_TO_PIXEL In ) : COLOR 
{
	float4 col = tex2D( TextureSampler, In.Tex );
	float2 res = float2( 1280.0f, 720.0f );
	float2 pos = In.PosL.xy / res.yy;
	pos += g_fApplicationTime * 0.125;
	float tiles = 5.;
	pos *= tiles;
	float n = saturate(interpolatedNoise(pos) + 0.5f) * 1.75f;
	return float4( n, n, n, 1.0f ) * col;
}

//--------------------------------------------------------------------------------------
// Technique - Normal - Background
//--------------------------------------------------------------------------------------
technique RenderWallpaper
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 ShadeVertex();
        PixelShader  = compile ps_2_0 ShadePixel();
    }
}