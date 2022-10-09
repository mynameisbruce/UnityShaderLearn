// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Glass Refraction" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}						// MainTex是玻璃的纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}						// 玻璃的法线纹理
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}		// 玻璃的立方体纹理
		_Distortion ("Distortion", Range(0, 100)) = 10				// 变形系数, 控制法线的凹凸程度
		_RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0	// 折射系数, 用于控制折射的强度
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		// 注意一点，使用GrabPass的时候，我们需要小心渲染队列的设置，GrabPass一般是用于透明的物体。所以渲染队列要设置为Transparent。
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _GrabPassTex
		// GrabPass会把模型后面的内容捕捉，塞进一张纹理中。我们只需要指定纹理的变量名即可，这里指定为_RefractionTex
		GrabPass { "_GrabPassTex" }
		
		Pass {		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
			float _Distortion;
			fixed _RefractAmount;
			sampler2D _GrabPassTex;
			float4 _RefractionTex_TexelSize;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
			    float4 TtoW1 : TEXCOORD3;  
			    float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert (a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 计算模型的屏幕空间的采样位置
				// 计算采样一个GrabPass所需要的纹理坐标，输入是模型的裁剪空间坐标([-1,1]映射到[0,1])
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
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
			
			fixed4 frag (v2f i) : SV_Target {		
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
				// 在切线空间下获取法线贴图中的法线
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));	
				
				// Compute the offset in tangent space
				// 对玻璃的采样坐标进行扭曲
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
				// 对扭曲后的坐标通过透视除法得到视口坐标，再用视口坐标采样抓取的渲染纹理，得到模拟的折射颜色
				fixed3 refrCol = tex2D(_GrabPassTex, i.scrPos.xy / i.scrPos.w).rgb;
				
				// Convert the normal to world space
				// 使用切线空间转世界空间的矩阵来计算世界空间下的法线
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				
				// 通过法线和视角向量得到反射方向
				fixed3 reflDir = reflect(-worldViewDir, bump);

				// 将玻璃纹理颜色和反射方向采样得到的立方体纹理进行混合
				fixed4 texColor = tex2D(_MainTex, i.uv.xy);
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb; // * texColor.rgb;
				
				// 使用_RefractAmount对反射颜色和折射颜色进行插值
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	
	// GrabPass{}，不指定纹理变量名称的话，会把屏幕内容抓取到一个叫做_GrabTexture中的纹理中，恐怖的是_GrabTexture被引用了多少次，它就会抓取多少次，是一种非常耗费性能的做法，目前出现这种做法的理由不明。
	// GrabPass{"TextureName"} 指定纹理变量名称的话，会把屏幕内容抓取到我们指定的纹理变量中，无论我们调用多少次，它都抓取一次。
	FallBack "Diffuse"
}
