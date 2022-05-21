#if !defined(DRP_VARIABLES_HLSL)
#define DRP_VARIABLES_HLSL

#if defined(URP)
    half4 _MainLightPosition,_MainLightColor;
    float4 _LightColor0;
    
sampler2D _MainLightShadowmapTexture;
// sampler2D _ShadowMapTexture;
float4x4  _MainLightWorldToShadow[5];
// float4x4 unity_WorldToShadow[5];

    #define _WorldSpaceLightPos0 _MainLightPosition
    #define _LightColor0 _MainLightColor
    #define _ShadowMapTexture _MainLightShadowmapTexture
    #define unity_WorldToShadow _MainLightWorldToShadow
#endif

#endif //DRP_VARIABLES_HLSL