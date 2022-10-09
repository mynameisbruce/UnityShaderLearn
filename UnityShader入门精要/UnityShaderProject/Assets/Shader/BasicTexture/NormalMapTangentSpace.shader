// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述在切线空间下使用法线纹理来计算光照
Shader "MyShaders/Normal Map In Tangent Space" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)	// 设定颜色
		_MainTex ("Main Tex", 2D) = "white" {}	// 纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}	// 法线纹理
		_BumpScale ("Bump Scale", Float) = 1.0	// 用于控制凹凸程度
		_Specular ("Specular", Color) = (1, 1, 1, 1)	// 高光颜色
		_Gloss ("Gloss", Range(8.0, 256)) = 20	// 光泽度，值越大亮点区域越小
	}
	SubShader {
		// Tags { "RenderType"="Opaque" "Queue"="Geometry"}

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
			float4 _BumpMap_ST;
			float _BumpScale;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				// 注意：和法线方向normal不同，tangent的类型是float4，不是float3，因为我们需要使用tangent.w分量来决定切线空间中的第三个坐标轴--副切线的方向性
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 lightDir: TEXCOORD1;
				float3 viewDir : TEXCOORD2;
			};

			// Unity doesn't support the 'inverse' function in native shader
			// so we write one by our own
			// Note: this function is just a demonstration, not too confident on the math or the speed
			// Reference: http://answers.unity3d.com/questions/218333/shader-inversefloat4x4-function.html
			// Unity已经不支持计算逆矩阵的inverse函数，所以这个是手写的
			float4x4 inverse(float4x4 input) {
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
				
				float4x4 cofactors = float4x4(
				     minor(_22_23_24, _32_33_34, _42_43_44), 
				    -minor(_21_23_24, _31_33_34, _41_43_44),
				     minor(_21_22_24, _31_32_34, _41_42_44),
				    -minor(_21_22_23, _31_32_33, _41_42_43),
				    
				    -minor(_12_13_14, _32_33_34, _42_43_44),
				     minor(_11_13_14, _31_33_34, _41_43_44),
				    -minor(_11_12_14, _31_32_34, _41_42_44),
				     minor(_11_12_13, _31_32_33, _41_42_43),
				    
				     minor(_12_13_14, _22_23_24, _42_43_44),
				    -minor(_11_13_14, _21_23_24, _41_43_44),
				     minor(_11_12_14, _21_22_24, _41_42_44),
				    -minor(_11_12_13, _21_22_23, _41_42_43),
				    
				    -minor(_12_13_14, _22_23_24, _32_33_34),
				     minor(_11_13_14, _21_23_24, _31_33_34),
				    -minor(_11_12_14, _21_22_24, _31_32_34),
				     minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

			v2f vert(a2v v) {
				v2f o;
				// 顶点转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 将纹理和法线纹理进行平铺偏移处理后存入uv的xy和zw分量
				// 出于减少插值寄存器的使用数量的目的，往往只存储一个纹理坐标即可
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				///
				/// Note that the code below can handle both uniform and non-uniform scales
				/// 注意，下面的代码可以处理统一和非统一缩放
				///

				// Construct a matrix that transforms a point/vector from tangent space to world space
				// 构造一个矩阵，将点/向量从切线空间转换到世界空间
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  // 将顶点法线转换到世界空间
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  // 将顶点切线转换到世界空间
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 	// 在世界空间中计算副切线，tangent.w分量用来决定副切线的方向性

				/*
				float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
												   worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
												   worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
												   0.0, 0.0, 0.0, 1.0);
				// The matrix that transforms from world space to tangent space is inverse of tangentToWorld
				float3x3 worldToTangent = inverse(tangentToWorld);
				*/
				
				//wToT = the inverse of tToW = the transpose of tToW as long as tToW is an orthogonal matrix.
				// 世界空间转切线空间矩阵 = 切线空间转世界空间的逆矩阵 = 切线空间转世界空间的矩阵的转置(前提是正交矩阵，也就是模型没缩放)
				float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

				// Transform the light and view dir from world space to tangent space
				// 将光照方向和视角方向通过 世界空间转切线空间矩阵 转到切线空间
				o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
				o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

				///
				/// Note that the code below can only handle uniform scales, not including non-uniform scales
				/// 注意，下面的代码只能处理统一缩放，不能处理非统一缩放
				/// 

				// Compute the binormal
//				float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w;
//				// Construct a matrix which transform vectors from object space to tangent space
//				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				// Or just use the built-in macro
//				TANGENT_SPACE_ROTATION;
//				
//				// Transform the light direction from object space to tangent space
//				o.lightDir = mul(rotation, normalize(ObjSpaceLightDir(v.vertex))).xyz;
//				// Transform the view direction from object space to tangent space
//				o.viewDir = mul(rotation, normalize(ObjSpaceViewDir(v.vertex))).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {		
				// 将切线空间下的光照方向和视角方向归一化		
				fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);
				
				// Get the texel in the normal map
				// 采样获取法线纹理的纹素
				fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
				fixed3 tangentNormal;
				// If the texture is not marked as "Normal map"
				// 如果 _BumpMap 的纹理类型不是 Normal Map 类型，那么直接映射就可以了(packedNormal.xy * 2 - 1)
//				tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
//				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				// Or mark the texture as "Normal map", and use the built-in funciton
				// 如果 _BumpMap 的纹理类型是 Normal Map 类型，使用内置的UnpackNormal函数，里面会包含对压缩后的法线纹理的处理
				tangentNormal = UnpackNormal(packedNormal);
				tangentNormal.xy *= _BumpScale;		// 对xy做了缩放处理，所以z分量需要重新计算
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				// 反射率 = 采样获取纹理的纹素 * 设定颜色
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				// 环境光 = 全局设定的环境光 * 反射率
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 使用切线空间下的法向量和光照方向来计算漫反射
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				// 使用切线空间下的光照方向、视角方向和法向量来计算高光反射
				fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
