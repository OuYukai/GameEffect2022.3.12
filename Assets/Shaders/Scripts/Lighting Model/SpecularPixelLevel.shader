﻿Shader "Custom/SpecularPixelLevel"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(8.0, 256)) = 20
    }
    
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "Lighting.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos   : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(a2v v)
            {
                v2f o;

                //  Transform the vertex from object space to projection space
                o.pos = UnityObjectToClipPos(v.vertex);

                //  Transform the normal from object space to world space
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);

                //  Transform the vertex from object space to world space
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //  Get ambient term
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                //  Get normal in world space
                fixed3 worldNormal = normalize(i.worldNormal);

                //  Get the light direction in world space
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);

                //  Compute diffuse term
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));

                //  Get reflect direction in world space
                fixed3 reflectDir = normalize(reflect(-worldLight, worldNormal));

                //  Get the view direction in world space
                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);

                // Compute specular term
                fixed3 specular = _LightColor0 * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                fixed3 color = ambient + diffuse + specular;
                    
                return fixed4(color, 1.0);
            }
            
            ENDCG
        }
    }
    FallBack "Diffuse"
}