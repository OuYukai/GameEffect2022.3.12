Shader "Custom/Shadow"
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
            //  Pass for ambient light & first pixel light (directional light)
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM

            //  Apparently need to add this declaration
            #pragma multi_compile_fwdbase
            
            #pragma vertex vert
            #pragma fragment frag
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

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
                SHADOW_COORDS(2)
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

                //  Pass shadow cordinates to pixel shader
                TRANSFER_SHADOW(o)
                
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
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLight));

                //  Get reflect direction in world space
                fixed3 reflectDir = normalize(reflect(-worldLight, worldNormal));

                //  Get the view direction in world space
                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);

                //  Get the half direction in world space
                fixed3 halfDir = normalize(worldLight + viewDir);

                // Compute specular term
                fixed3 specular = _LightColor0.rbg * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                // Use shadow coordinates to sample shadow map
                fixed shadow = SHADOW_ATTENUATION(i);

                // The attenuation of directional light is always 1
                fixed atten = 1;
                
                fixed3 color = ambient + (diffuse + specular) * atten * shadow;
                    
                return fixed4(color, 1.0);
            }
            
            ENDCG
        }

        Pass
        {
            //  Pass for other pixel lights 
            Tags { "LightMode" = "ForwardAdd" }
            
            Blend One One
            
            CGPROGRAM

            //  Apparently need to add this declaration
            #pragma multi_compile_fwdadd
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

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
                //  Get normal in world space
                fixed3 worldNormal = normalize(i.worldNormal);

                //  Get the light direction in world space
                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif

                //  Compute diffuse term
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLight));

                //  Get reflect direction in world space
                fixed3 reflectDir = normalize(reflect(-worldLight, worldNormal));

                //  Get the view direction in world space
                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);

                //  Get the half direction in world space
                fixed3 halfDir = normalize(worldLight + viewDir);

                // Compute specular term
                fixed3 specular = _LightColor0.rbg * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                // The attenuation of directional light is always 1
                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed atten = 1;
                #else
                    float3 lightCoord = mul(unity_WorldToShadow[0], float4(i.worldPos, 1)).xyz;
                    fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                #endif
                
                fixed3 color = (diffuse + specular) * atten;
                    
                return fixed4(color, 1.0);
            }
            
            ENDCG
        }
    }
    FallBack "Specular"
}
