// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述在世界空间下使用法线纹理来计算光照
Shader "MyShaders/Normal Map In World Space" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)	// 设定颜色
		_MainTex ("Main Tex", 2D) = "white" {}	// 纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}	// 法线纹理
		_BumpScale ("Bump Scale", Float) = 1.0	// 用于控制凹凸程度
		_Specular ("Specular", Color) = (1, 1, 1, 1)	// 高光颜色
		_Gloss ("Gloss", Range(8.0, 256)) = 20		// 光泽度，值越大亮点区域越小
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
				// 依次存储了切线空间到世界空间的变换矩阵的每一行，由于对方向矢量的变换只需要使用3x3大小的矩阵，所以每一行只需使用float3,
				// 为了充分利用插值寄存器的存储空间，我们把世界空间下的顶点位置存储到每一行的第四个位置，也就是w分量中
				float4 TtoW0 : TEXCOORD1;  
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3; 
			};
			
			v2f vert(a2v v) {
				v2f o;
				// 顶点转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 将纹理和法线纹理进行平铺偏移处理后存入uv的xy和zw分量
				// 出于减少插值寄存器的使用数量的目的，往往只存储一个纹理坐标即可
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
				
				// 使用unity_ObjectToWorld计算世界空间下的顶点坐标
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				// 计算世界空间下的法线、切线，并使用叉乘计算出世界空间下的副切线, tangent.w分量用来决定副切线的方向性
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// Compute the matrix that transform directions from tangent space to world space
				// Put the world position in w component for optimization
				// 将世界空间下的法线、切线和副切线坐标按列存储在TtoW0、TtoW1和TtoW2中，并把世界空间下的顶点位置的xyz分量存储在每一行的w分量中
				// 按列排列会构建切线空间转世界空间的矩阵
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// Get the position in world space		
				// 获取世界空间下的顶点坐标
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				// Compute the light and view dir in world space
				// 计算世界空间下的光照方向和视角方向
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
				// 通过内置函数UnpackNormal来解码采样而来的法线向量
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
				bump.xy *= _BumpScale;	// 对xy做了缩放处理，所以z分量需要重新计算
				bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy)));

				// Transform the normal from tangent space to world space
				// 使用切线空间转世界空间的矩阵来计算世界空间下的法线
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				
				// 反射率 = 采样获取纹理的纹素 * 设定颜色
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				// 环境光 = 全局设定的环境光 * 反射率
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 使用世界空间下的法向量和光照方向来计算漫反射
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(bump, lightDir));

				// 使用世界空间下的光照方向、视角方向和法向量来计算高光反射
				fixed3 halfDir = normalize(lightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
