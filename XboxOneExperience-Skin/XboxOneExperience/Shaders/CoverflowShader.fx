//--------------------------------------------------------------------------------------
//  Filename:       CoverflowShader.fx
//  Author:         Phoenix
//  Date:           July 1, 2014
//  Description:    HLSL Pixel and Vertex Shader for Aurora's coverflow rendering
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Global Matrices
//--------------------------------------------------------------------------------------
float4x4 g_mWorldViewProjection;						// World View Projection Matrix
float4x4 g_mWorldInverseTranspose;						// World Inverse Transpose Matrix
float4x4 g_mWorld;										// World Matrix
float4x4 g_mView;										// View Matrix
float4x4 g_mProjection;									// Projection Matrix
float4x4 g_mViewProjection;								// View Projection Matrix

//--------------------------------------------------------------------------------------
// Global Camera Properties
//--------------------------------------------------------------------------------------
float3 g_fCameraPositionW;								// Camera position in world space
float3 g_fCameraDirectionW;								// Camera direction in world space

//--------------------------------------------------------------------------------------
// Global Light Properties
//--------------------------------------------------------------------------------------
float3 g_fLightPositionW;								// Light position in world space
float3 g_fLightDirectionW;								// Light direction in world space
float3 g_fLightAttenuation;								// Light attenuation factors
float3 g_fLightSpotPower;								// Light spot power

//--------------------------------------------------------------------------------------
// Global Material Properties
//--------------------------------------------------------------------------------------
float3 g_fAmbientMaterial	= { 0.40f, 0.40f, 0.40f };	// Ambient Material (Intensity)
float3 g_fAmbientColor		= { 1.00f, 1.00f, 1.00f };	// Ambient Light Color
float3 g_fDiffuseMaterial	= { 0.75f, 0.75f, 0.75f };	// Diffuse Material (Intensity)
float3 g_fDiffuseColor		= { 1.00f, 1.00f, 1.00f };	// Diffuse Light Color
float3 g_fSpecularMaterial	= { 0.00f, 0.00f, 0.00f };	// Specular Material (Intensity)
float3 g_fSpecularColor		= { 1.00f, 1.00f, 1.00f };	// Specular Light Color
float  g_fSpecularPower		= 0.0f;						// Specular Power Factor

//--------------------------------------------------------------------------------------
// Global Variables 
//--------------------------------------------------------------------------------------
float g_fApplicationTime;								// Total application run-time (seconds)
float g_fElapsedTime;									// Elapsed application run-time (seconds)
int	  g_iCurrentSubsetId;								// Mesh subset of current case
int	  g_iCurrentObjectId;								// Cover Index of current case
int	  g_iCenterObjectId;								// Cover Index of center case (for comparison to current)
int   g_iCoverSubsetId = 1;								// Cover subset index (for comparison to current)
int   g_iCaseSubsetId = 0;								// Case subset index (for comparison to current)
bool  g_bContentEnabled		= true;						// Flag to determine if current case is 'enabled'
bool  g_bContentHidden		= false;					// Flag to determine if current case is 'hidden'
bool  g_bContentFavorite	= false;					// Flag to determine if the current case is 'favorite'


//--------------------------------------------------------------------------------------
// Global Texture Samplers
//--------------------------------------------------------------------------------------
texture inputTexture0;
sampler TextureSampler = sampler_state
{
	Texture = (inputTexture0);
	MinFilter = Anisotropic;
	MagFilter = Anisotropic;
	MaxAnisotropy = 16;
};

//--------------------------------------------------------------------------------------
// Global Vertex/Pixel Shader Structs
//--------------------------------------------------------------------------------------
struct VERTEX_IN
{
	float3 Position		: POSITION0;
	float3 Normal		: NORMAL0;
	float2 TexCoords	: TEXCOORD0;
};

struct VERTEX_TO_PIXEL
{
	float4 Position		: POSITION;
	float4 Lights		: COLOR0;
	float2 TexCoords	: TEXCOORD0;
	float3 PositionL	: TEXCOORD1;
	float3 PositionW	: TEXCOORD2;
};

//--------------------------------------------------------------------------------------
// Function - Make Greyscale
//--------------------------------------------------------------------------------------
inline float4 MakeGreyscale( float3 inputColor, float inputAlpha )
{
	float3 greyscale = dot( inputColor.rgb, float3( 0.3f, 0.59f, 0.11f ) );
	return float4( greyscale.rgb * 0.25f, inputAlpha * 0.98f );
}

//--------------------------------------------------------------------------------------
// Coverflow - Normal/Mirror - Vertex Shader
//--------------------------------------------------------------------------------------
VERTEX_TO_PIXEL CoverflowNormal_VS( VERTEX_IN Input )
{
	// Initialize the output struct
	VERTEX_TO_PIXEL Output = (VERTEX_TO_PIXEL)0;

	// Transform vertex into screen space using WVP matrix
	Output.Position = mul( float4( Input.Position, 1.0f ), g_mWorldViewProjection );

	// Calculate normal unit vector for vertex using World Inverse Transpose matrix
	float3 normalW = mul( float4( Input.Normal, 0.0f ), g_mWorldInverseTranspose).xyz;
	normalW = normalize(normalW);

	// Transform vertex into world space using world matrix
	float3 posW = mul( float4( Input.Position, 1.0f ), g_mWorld ).xyz;

	// Calculate the world space light vector using light position and vertex position
	float3 lightVecW = normalize(g_fLightPositionW - posW);

	// Calculate the ambient light contribution
	float3 ambient = (g_fAmbientMaterial * g_fAmbientColor).rgb;

	// Calculate the diffuse light contribution
	float3 s = saturate(dot(lightVecW, normalW));
	float3 diffuse = s * (g_fDiffuseMaterial * g_fDiffuseColor).rgb;

	// Calculate the specular light contribution
	float3 toEyeW = normalize( g_fCameraPositionW - posW );
	float3 reflectW = reflect( -lightVecW, normalW );
	float t = pow(max(dot(reflectW, toEyeW), 0.0f), g_fSpecularPower );
	float3 spec = t * (g_fSpecularMaterial * g_fSpecularColor ).rgb;

	// Calculate the attenuation factor
	float d = distance( g_fLightPositionW, posW );
	float A = g_fLightAttenuation.x + g_fLightAttenuation.y*d + g_fLightAttenuation.z*d*d;

	// Calculate the spot light factor
	float spot = pow(max(dot(-lightVecW, g_fLightDirectionW), 0.0f ), g_fLightSpotPower );

	// Calculate the final light contribution
	float3 color = spot * (ambient + ((diffuse + spec) / A ));

	// Complete the Output structure for the vertex shader
	Output.Lights = float4( color, 1.0f );
	Output.PositionL = Input.Position;
	Output.PositionW = posW;
	Output.TexCoords = Input.TexCoords;

	// Return results for pixel shader
	return Output;
}

//--------------------------------------------------------------------------------------
// Coverflow - Normal - Pixel Shader
//--------------------------------------------------------------------------------------
float4 CoverflowNormal_PS( VERTEX_TO_PIXEL Input ) : COLOR
{
	// Retrieve color sample from texture
	float4 baseColor = tex2D( TextureSampler, Input.TexCoords );

	// Calculate our final color
	float colorFactor = 1.3f;
	float3 finalColor = ( baseColor.rgb * Input.Lights.rgb * colorFactor );
	float finalAlpha = 1.0f;

	// Adjust color for disabled content
	if( g_bContentEnabled == false ) 
	{
		finalColor = MakeGreyscale( finalColor, finalAlpha );
	}

	// Adjust color for hidden content
	if( g_bContentHidden == true )
	{
		finalAlpha = finalAlpha * 0.65f;
	}

	if( g_iCurrentSubsetId == g_iCaseSubsetId && g_bContentFavorite == true ) 
	{
		finalColor = finalColor + 0.125f * sin( g_fApplicationTime * 3.5f );
	}

	// Return final results
	return float4( finalColor.rgb, finalAlpha );
}

//--------------------------------------------------------------------------------------
// Coverflow - Mirror - Pixel Shader
//--------------------------------------------------------------------------------------
float4 CoverflowMirror_PS( VERTEX_TO_PIXEL Input ) : COLOR
{
	// Retrieve color sample from texture
	float4 baseColor = tex2D( TextureSampler, Input.TexCoords );

	// Create fade on the mirror
	float height = Input.PositionW.y + 0.42f;
	float alphaFactor = saturate(0.50f - abs(height)) ;

	// Calculate our final color
	float colorFactor = 0.975f;
	float3 finalColor = ( baseColor.rgb * Input.Lights.rgb * colorFactor );
	float finalAlpha = alphaFactor;

	// Adjust color for disabled content
	if( g_bContentEnabled == false ) 
	{
		finalColor = MakeGreyscale( finalColor, finalAlpha );
	}

	// Adjust color for hidden content
	if( g_bContentHidden == true )
	{
		finalAlpha = finalAlpha * 0.65f;
	}

	// Return final results
	return float4( finalColor.rgb, finalAlpha );
}

//--------------------------------------------------------------------------------------
// Technique - Normal - Render Coverflow normally
//--------------------------------------------------------------------------------------
technique RenderCover
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 CoverflowNormal_VS();
        PixelShader  = compile ps_2_0 CoverflowNormal_PS();
    }
}

//--------------------------------------------------------------------------------------
// Technique - Mirror - Render Coverflow Reflection
//--------------------------------------------------------------------------------------
technique RenderMirror
{
    pass Pass0
    {
        VertexShader = compile vs_2_0 CoverflowNormal_VS();
        PixelShader  = compile ps_2_0 CoverflowMirror_PS();
    }
}
