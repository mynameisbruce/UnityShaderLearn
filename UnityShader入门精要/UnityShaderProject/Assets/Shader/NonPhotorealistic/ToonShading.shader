// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 此文件用于描述卡通风格的渲染
Shader "MyShaders/Toon Shading" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)			
		_MainTex ("Main Tex", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {}
		_Outline ("Outline", Range(0, 1)) = 0.1
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01
	}
    SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		// 第一个Pass渲染背面作为边框
		Pass {
			NAME "OUTLINE"
			
			// 剔除正面
			Cull Front
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			float _Outline;
			fixed4 _OutlineColor;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			}; 
			
			struct v2f {
			    float4 pos : SV_POSITION;
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				// 将顶点转换到视角空间
				// float4 pos = mul(UNITY_MATRIX_MV, v.vertex); 
				float4 pos = float4(UnityObjectToViewPos(v.vertex), 1.0); 
				// 将法线转换到视角空间
				float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);  
				// 直接使用顶点进行法线方向的扩张，对于一些内凹的模型，就可能发生正面面片被背面面片遮挡的情况，
				// 为了尽可能的防止这种情况的出现，在扩张背面的顶点之前，我们必须先对顶点法线的z分量进行处理，使它等于一个定值
				normal.z = -0.5;

				// 对法线归一化后，进行扩张
				pos = pos + float4(normalize(normal), 0) * _Outline;

				// 将视角空间的顶点转到投影空间
				o.pos = mul(UNITY_MATRIX_P, pos);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target {
				return float4(_OutlineColor.rgb, 1);               
			}
			
			ENDCG
		}
		
		// 第二个Pass用于渲染正面
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			// 剔除背面
			Cull Back
		
			CGPROGRAM
		
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_fwdbase
		
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			fixed4 _Specular;
			fixed _SpecularScale;
		
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			}; 
		
			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos( v.vertex);
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target { 
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
				
				// 采样纹理和设定颜色相乘
				fixed4 c = tex2D (_MainTex, i.uv);
				fixed3 albedo = c.rgb * _Color.rgb;
				
				// 使用上一步得到的结果计算环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				// 计算半兰伯特系数
				fixed diff =  dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;
				
				// 使用半兰伯特系数对渐变纹理进行采样，将结果与反射率和光照颜色相乘作为最后的漫反射
				fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;
				
				fixed spec = dot(worldNormal, worldHalfDir);

				// fwidth函数可以得到邻域像素之间的近似导数值
				fixed w = fwidth(spec) * 2.0;

				// smoothstep函数接受两个阈值-w和w, 如果(spec + _SpecularScale - 1)小于-w，那么为0，如果大于w，则为1，否则在0和1之间进行插值。
				fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
		
			ENDCG
		}
	}
	FallBack "Diffuse"
}
