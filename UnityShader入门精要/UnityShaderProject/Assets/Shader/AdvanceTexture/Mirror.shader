// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Mirror" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}	// 对应的是摄像机渲染得到的渲染纹理
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass {

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			
			sampler2D _MainTex;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv = v.texcoord;
				// Mirror needs to filp x
				// 镜子里显示的图像都是左右相反的，所以翻转x分量
				o.uv.x = 1 - o.uv.x;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				return tex2D(_MainTex, i.uv);
			}
			
			ENDCG
		}
	} 

	// 在上面的实现中，我们把渲染纹理的分辨率大小设置为256*256。有时这样的分辨率会模糊不清，我们可以使用更高的分辨率或更多的抗锯齿采样
	// 但需注意的是，更高的分辨率会影响带宽和性能，应当尽量使用较小的分辨率。

 	FallBack Off
}
