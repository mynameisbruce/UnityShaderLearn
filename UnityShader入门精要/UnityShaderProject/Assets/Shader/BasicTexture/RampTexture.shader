// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述使用渐变纹理
Shader "MyShaders/Ramp Texture" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)	// 设定材质颜色
		_RampTex ("Ramp Tex", 2D) = "white" {}		// 渐变纹理
		_Specular ("Specular", Color) = (1, 1, 1, 1)	// 高光颜色
		_Gloss ("Gloss", Range(8.0, 256)) = 20	// 光泽度，值越大亮点区域越小
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _RampTex;
			float4 _RampTex_ST;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 uv : TEXCOORD2;
			};
			
			v2f vert(a2v v) {
				v2f o;
				// 顶点转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 法线变换到世界空间
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				// 顶点变换到世界空间
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uv = TRANSFORM_TEX(v.texcoord, _RampTex);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// 将世界空间下的法线归一化
				fixed3 worldNormal = normalize(i.worldNormal);
				// 将世界空间下的光照方向归一化
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				
				// 环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// Use the texture to sample the diffuse color
				// 使用半兰伯特部分halfLambert(范围是[0,1])构建一个纹理坐标，使用这个纹理坐标对渐变纹理进行采样
				fixed halfLambert  = 0.5 * dot(worldNormal, worldLightDir) + 0.5;
				fixed3 diffuseColor = tex2D(_RampTex, fixed2(halfLambert, halfLambert)).rgb * _Color.rgb;
				
				// 漫反射颜色 = 光照颜色 * 上一步采样的渐变颜色
				fixed3 diffuse = _LightColor0.rgb * diffuseColor;
				
				// 使用世界空间下的光照方向、视角方向和法向量来计算高光反射
				fixed3 halfDir = normalize(worldLightDir + worldViewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
