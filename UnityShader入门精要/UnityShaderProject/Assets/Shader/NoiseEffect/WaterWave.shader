// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Water Wave" {
	Properties {
		_Color ("Main Color", Color) = (0, 0.15, 0.115, 1)		// 控制水面颜色
		_MainTex ("Base (RGB)", 2D) = "white" {}				// 水面波纹材质纹理
		_WaveMap ("Wave Map", 2D) = "bump" {}					// 由噪声纹理生成的法线纹理
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}	// 模拟反射的立方体纹理
		_WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01	// 控制法线纹理在X方向上的平移
		_WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01	// 控制法线纹理在Y方向上的平移
		_Distortion ("Distortion", Range(0, 100)) = 10					// 控制模拟折射时图像的扭曲程度
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		// 渲染队列必须设置成透明，才能在其他模型之后渲染
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		// 抓取屏幕图像
		GrabPass { "_RefractionTex" }
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WaveMap;
			float4 _WaveMap_ST;
			samplerCUBE _Cubemap;
			fixed _WaveXSpeed;
			fixed _WaveYSpeed;
			float _Distortion;	
			sampler2D _RefractionTex;
			float4 _RefractionTex_TexelSize;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
				float4 TtoW1 : TEXCOORD3;  
				float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 取得屏幕坐标偏移到[0,1]范围内并且未进行透视除法的值
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				// 将纹理和法线纹理进行平铺偏移处理后存入uv的xy和zw分量
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);
				
				// 计算世界空间下的法线、切线，并使用叉乘计算出世界空间下的副切线, tangent.w分量用来决定副切线的方向性
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

				// 将世界空间下的法线、切线和副切线坐标按列存储在TtoW0、TtoW1和TtoW2中，并把世界空间下的顶点位置的xyz分量存储在每一行的w分量中
				// 按列排列会构建切线空间转世界空间的矩阵
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// 得到世界坐标
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				// 取得世界空间下的视角向量
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

				// 通过_WaveXSpeed和_WaveYSpeed与时间变量设定速度
				float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
				
				// Get the normal in tangent space
				// 对法线纹理进行两次采样(模拟两层交叉的水面波动效果)
				fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
				fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
				// 对两次结果想加并归一化得到切线空间下的法线向量
				fixed3 bump = normalize(bump1 + bump2);
				
				// Compute the offset in tangent space
				// 对采样坐标进行扭曲
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
				// 对扭曲后的坐标通过透视除法得到视口坐标，再用视口坐标采样抓取的渲染纹理，得到模拟的折射颜色
				fixed3 refrCol = tex2D( _RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;
				
				// Convert the normal to world space
				// 使用切线空间转世界空间的矩阵来计算世界空间下的法线
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

				// 对水面波纹材质纹理也采取偏移后采样
				fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed);
				// 利用世界空间下的法线计算反射方向
				fixed3 reflDir = reflect(-viewDir, bump);
				// 通过上一步的法线方向在模拟反射的立方体纹理进行采样，并与水面波纹材质纹理颜色和设定的水面颜色进行相乘，最后得到反射颜色
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;
				
				// 计算菲涅耳系数
				fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
				// 使用菲涅耳系数对折射颜色和反射颜色进行插值混合
				fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	// Do not cast shadow
	FallBack Off
}
