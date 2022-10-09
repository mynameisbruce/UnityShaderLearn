// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述使用透明度测试
Shader "MyShaders/Alpha Test" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)		// 设定材质颜色
		_MainTex ("Main Tex", 2D) = "white" {}			// 纹理
		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5		// 判断条件
	}
	SubShader {
		// Queue设置为渲染队列AlphaTest，半透明图片一般是设置这个渲染队列
		// IgnoreProjector 标签值为“True”，则使用此着色器的对象不会受到投影器的影响。
		// RenderType标签可以让Unity把这个Shader归入到提前定义的组，这里是TransparentCutout。此标签一般用于着色器替换功能。
		Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed _Cutoff;
			
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
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed4 texColor = tex2D(_MainTex, i.uv);
				
				// Alpha test
				// clip函数：给定参数的任何一个分量是负数，就会舍弃当前像素的输出颜色
				clip (texColor.a - _Cutoff);
				// Equal to 
				// 等同于上面的clip函数
//				if ((texColor.a - _Cutoff) < 0.0) {
//					discard;
//				}
				
				// 下面四行是计算环境光和漫反射光的通常处理
				fixed3 albedo = texColor.rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				return fixed4(ambient + diffuse, 1.0);
			}
			
			ENDCG
		}
	} 

	// 保证使用该Shader的物体可以正确地向其他物体投射阴影
	FallBack "Transparent/Cutout/VertexLit"
}
