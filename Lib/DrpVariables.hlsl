#if !defined(DRP_VARIABLES_HLSL)
#define DRP_VARIABLES_HLSL

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityShadowLibrary.cginc"

half4 _MainLightPosition;
// half4 _MainLightColor;

// sampler2D _MainLightShadowmapTexture;
float4x4  _MainLightWorldToShadow[5];
half4 _MainLightShadowParams; // (x: shadowStrength, y: 1.0 if soft shadows, 0.0 otherwise, z: main light fade scale, w: main light fade bias)
float4 _ShadowBias; // x: depth bias, y: normal bias

#define _WorldSpaceLightPos0 _MainLightPosition
#define _LightColor0 _MainLightColor
#define _ShadowMapTexture _MainLightShadowmapTexture
#define unity_WorldToShadow _MainLightWorldToShadow
#define _LightShadowData _MainLightShadowParams
#define unity_LightShadowBias _ShadowBias

#define unitySampleShadow unitySampleShadow1
    UNITY_DECLARE_SHADOWMAP(_MainLightShadowmapTexture);
    #define TRANSFER_SHADOW(a) a._ShadowCoord = mul( unity_WorldToShadow[0], mul( unity_ObjectToWorld, v.vertex ) );
    inline half unitySampleShadow1 (unityShadowCoord4 shadowCoord)
    {
        #if defined(SHADOWS_NATIVE)
            half shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, shadowCoord.xyz);
            return lerp(1,shadow,_LightShadowData.x);
        #else
            unityShadowCoord dist = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, shadowCoord.xy);
            // tegra is confused if we use _LightShadowData.x directly
            // with "ambiguous overloaded function reference max(mediump float, float)"
            unityShadowCoord lightShadowDataX = _LightShadowData.x;
            unityShadowCoord threshold = shadowCoord.z;
            return max(dist > threshold, lightShadowDataX);
        #endif
    }

    #define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
    #define SHADOW_ATTENUATION(a) unitySampleShadow(a._ShadowCoord)

//-------------- shadow caster

#define UnityApplyLinearShadowBias UnityApplyLinearShadowBias1
    float4 UnityApplyLinearShadowBias1(float4 clipPos)
    {
        // For point lights that support depth cube map, the bias is applied in the fragment shader sampling the shadow map.
        // This is because the legacy behaviour for point light shadow map cannot be implemented by offseting the vertex position
        // in the vertex shader generating the shadow map.
    #if !(defined(SHADOWS_CUBE) && defined(SHADOWS_CUBE_IN_DEPTH_TEX))
        #if defined(UNITY_REVERSED_Z)
            // We use max/min instead of clamp to ensure proper handling of the rare case
            // where both numerator and denominator are zero and the fraction becomes NaN.
            clipPos.z += max(-1, min(unity_LightShadowBias.x / clipPos.w, 0));
        #else
            clipPos.z += saturate(unity_LightShadowBias.x/clipPos.w);
        #endif
    #endif

    #if defined(UNITY_REVERSED_Z)
        float clamped = min(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
    #else
        float clamped = max(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
    #endif
        clipPos.z = lerp(clipPos.z, clamped, unity_LightShadowBias.y);
        return clipPos;
    }
#endif //DRP_VARIABLES_HLSL