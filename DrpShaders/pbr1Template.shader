Shader "Hidden/pbr1Template"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("_Color",color)=(1,1,1,1)
        _NormalMap("_NormalMap",2d)="bump"{}
        _NormalScale("_NormalScale",range(0,5))=1

        _PbrMask("_PbrMask",2d)="white"{}
        _Metallic("_Metallic",range(0,1))=0
        _Smoothness("_Smoothness",range(0,1)) = 0
        _Occlusion("_Occlusion",range(0,1)) = 0

    }

    CGINCLUDE
        #include "UnityCG.cginc"
        #include "UnityStandardUtils.cginc"
        #include "AutoLight.cginc"

        half4 _LightColor0;
        #define _MainLightColor _LightColor0

        // float4 _WorldSpaceLightPos0;
        #define _MainLightPosition _WorldSpaceLightPos0

        #define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= 0.0 || shadowCoord.z >= 1.0

        
        float GetShadowFade(float3 positionWS)
        {
            // float3 camToPixel = positionWS - _WorldSpaceCameraPos;
            // float distanceCamToPixel2 = dot(camToPixel, camToPixel);

            // float fade = saturate(distanceCamToPixel2 * _LightShadowData.z + _LightShadowData.w);
            // return fade;
            float zDist = dot(_WorldSpaceCameraPos-positionWS,UNITY_MATRIX_V[2].xyz);
            float fadeDist = UnityComputeShadowFadeDistance(positionWS,zDist);
            float fade = UnityComputeShadowFade(fadeDist);
            return fade;
        }

        half CalcMainLightShadow(float4 shadowCoord,float3 worldPos){
            half shadow = 1.0;
            #if defined(SHADOWS_SCREEN)
                shadow = unitySampleShadow(shadowCoord);
                shadow = BEYOND_SHADOW_FAR(shadowCoord) ? 1 : shadow;
                float shadowFade = GetShadowFade(worldPos);
                return lerp(shadow,1,shadowFade);
            #endif
            return shadow;
        }
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // #pragma  multi_compile_fwdbase
            // #pragma multi_compile _ SHADOWS_SCREEN
            // make fog work
            #pragma multi_compile_fog
            #pragma target 3.0


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 tSpace0:TEXCOORD2;
                float4 tSpace1:TEXCOORD3;
                float4 tSpace2:TEXCOORD4;
                SHADOW_COORDS(5)
                // float4 _ShadowCoord:TEXCOORD5;
            };

            sampler2D _MainTex;
            sampler2D _PbrMask;
            sampler2D _NormalMap;
CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half _Metallic,_Smoothness,_Occlusion;
            half _NormalScale;
            half4 _Color;
CBUFFER_END
            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.pos);

                float3 n = UnityObjectToWorldNormal(v.normal);
                float3 t = UnityObjectToWorldDir(v.tangent.xyz);
                half sign = v.tangent.w * unity_WorldTransformParams.w;
                float3 b = normalize(cross(n,t)) * sign;
                float3 worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.tSpace0 = float4(t.x,b.x,n.x,worldPos.x);
                o.tSpace1 = float4(t.y,b.y,n.y,worldPos.y);
                o.tSpace2 = float4(t.z,b.z,n.z,worldPos.z);
                TRANSFER_SHADOW(o);
                // o._ShadowCoord = mul(unity_WorldToShadow[0],float4(worldPos,1));
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 pbrMask = tex2D(_PbrMask,i.uv);

                float metallic = pbrMask.x * _Metallic;
                float smoothness = pbrMask.y * _Smoothness;
                float occlusion = lerp(1,pbrMask.z , _Occlusion);

                float rough = 1-smoothness;
                float a = max(rough*rough,1e-4);
                float a2 = max(a*a,1e-6);

                float3 tn = UnpackScaleNormal(tex2D(_NormalMap,i.uv),_NormalScale);
                float3 n = normalize(float3(
                    dot(i.tSpace0.xyz,tn),
                    dot(i.tSpace1.xyz,tn),
                    dot(i.tSpace2.xyz,tn)
                ));
                // vertex normal
                // n = normalize(float3(i.tSpace0.z,i.tSpace1.z,i.tSpace2.z));

                float3 worldPos = float3(i.tSpace0.w,i.tSpace1.w,i.tSpace2.w);
                float3 v = normalize(_WorldSpaceCameraPos - worldPos);
                float3 l = normalize(_MainLightPosition.xyz);
                float3 h = normalize(l+v);

                float nl = saturate(dot(n,l));
                float nv = saturate(dot(n,v));
                float nh = saturate(dot(n,h));
                float lh = saturate(dot(l,h));

                // sample the texture
                half4 mainTex = tex2D(_MainTex, i.uv) * _Color; // to linear

                half3 albedo = mainTex.xyz;
                half alpha = mainTex.w;

                // gamma linear version
                half oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a - unity_ColorSpaceDielectricSpec.a * metallic;
                half3 diffColor = oneMinusReflectivity * albedo;
                half3 specColor = lerp(unity_ColorSpaceDielectricSpec.xyz,albedo,metallic);

                // linear version only
                // half3 diffColor = albedo  * (1-metallic);
                // half3 specColor = lerp(0.04,albedo,metallic);

                // gi
                half3 sh = ShadeSH9(float4(n,1));
                half3 giDiff = sh * diffColor;

                half mip = (1.7-0.7*rough)*6*rough;
                float3 reflectDir = reflect(-v,n);
                half4 envColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,reflectDir,mip);
                envColor.xyz = DecodeHDR(envColor,unity_SpecCube0_HDR);

                half surfaceReduction = lerp(1,0.5,a2);
                half fresnelTerm = pow(1-nv,4);
                half grazingTerm = saturate(smoothness+metallic);
                half3 giSpec = envColor.xyz * surfaceReduction * lerp(specColor,grazingTerm,fresnelTerm);
                half4 col = 0;
                col.xyz += (giDiff + giSpec) * occlusion;
// return diffColor.xyzx;
                //
                // lighting
                // half shadowAtten = SHADOW_ATTENUATION(i);
                half shadowAtten = 1;
                #if defined(SHADOWS_SCREEN)
                    shadowAtten = CalcMainLightShadow(i._ShadowCoord,worldPos);
                #endif
// return shadowAtten;
                float radiance = nl * shadowAtten;
                float d = nh*nh*(a2-1)+1;
                float specTerm = a2/(d*d* max(.0001,lh*lh) * (4*a+2));
                #if defined(UNITY_COLORSPACE_GAMMA)
                    specTerm = sqrt(max(1e-4,specTerm));
                #endif

                col.xyz += (diffColor + specColor * specTerm) * _MainLightColor * radiance;
                col.w = alpha;

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }

    }
    FallBack "VertexLit"
}
