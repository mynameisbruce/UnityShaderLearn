// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述遮罩纹理
Shader "MyShaders/Mask Texture" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)		// 设定材质颜色
		_MainTex ("Main Tex", 2D) = "white" {}			// 纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}			// 法线贴图
		_BumpScale("Bump Scale", Float) = 1.0			// 用于控制凹凸程度
		_SpecularMask ("Specular Mask", 2D) = "white" {}	// 高光反射遮罩纹理
		_SpecularScale ("Specular Scale", Float) = 1.0		// 控制遮罩影响度系数
		_Specular ("Specular", Color) = (1, 1, 1, 1)		// 高光颜色
		_Gloss ("Gloss", Range(8.0, 256)) = 20				// 光泽度，值越大亮点区域越小
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float _BumpScale;
			sampler2D _SpecularMask;
			float _SpecularScale;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 lightDir: TEXCOORD1;
				float3 viewDir : TEXCOORD2;
			};
			
			v2f vert(a2v v) {
				v2f o;
				// 顶点转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;

				// 构造一个矩阵，将点/向量从切线空间转换到世界空间
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  // 将顶点法线转换到世界空间
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  // 将顶点切线转换到世界空间
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 	// 在世界空间中计算副切线，tangent.w分量用来决定副切线的方向性
				// 世界空间转切线空间矩阵 = 切线空间转世界空间的逆矩阵 = 切线空间转世界空间的矩阵的转置(前提是正交矩阵，也就是模型没缩放)
				float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

				// 将光照方向和视角方向通过 世界空间转切线空间矩阵 转到切线空间
				o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
				o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// 将切线空间下的光照方向和视角方向归一化	
			 	fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);

				// 采样获取法线纹理的纹素
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
				tangentNormal.xy *= _BumpScale;		// 对xy做了缩放处理，所以z分量需要重新计算
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

				// 反射率 = 采样获取纹理的纹素 * 设定材质颜色
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				// 环境光 = 全局设定的环境光 * 反射率
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 使用世界空间下的法向量和光照方向来计算漫反射
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));
				
			 	fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
			 	// Get the mask value
				// 这里只用到了遮罩纹理中的r分量
			 	fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
			 	// Compute specular term with the specular mask
				 // 使用世界空间下的光照方向、视角方向和法向量来计算高光反射，并最后与上一步的遮罩mask相乘得到最终的高光反射强度
			 	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;
			
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
