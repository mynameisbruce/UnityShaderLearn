// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Motion Blur With Depth Texture" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}	// 输入的渲染纹理
		_BlurSize ("Blur Size", Float) = 1.0		// 模糊图像参数
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture;		// Unity传递的深度纹理
		float4x4 _CurrentViewProjectionInverseMatrix;	// 当前帧的视角*投影逆矩阵
		float4x4 _PreviousViewProjectionMatrix;			// 上一帧的视角*投影矩阵
		half _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
			half2 uv_depth : TEXCOORD1;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			// 对深度纹理的采样坐标进行平台差异化处理
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
					 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {
			// Get the depth buffer value at this pixel.
			// 对深度纹理进行采样取得深度值(SAMPLE_DEPTH_TEXTURE用于平台差异化下的采样)
			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
			// H is the viewport position at this pixel in the range -1 to 1.
			// H是该像素处的NDC坐标，范围为-1到1
			float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);
			// Transform by the view-projection inverse.
			// 通过当前帧的视角*投影的逆矩阵可以得出坐标D
			float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
			// Divide by w to get the world position. 
			// 需要对坐标D除以w分量得到世界空间下的坐标
			float4 worldPos = D / D.w;
			
			// Current viewport position 
			// 当前NDC坐标
			float4 currentPos = H;
			// Use the world position, and transform by the previous view-projection matrix.  
			// 使用前一帧的视角*投影的矩阵把前面求出的世界坐标变换为视角坐标
			float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
			// Convert to nonhomogeneous points [-1,1] by dividing by w.
			// 齐次除法得到前一帧的NDC坐标
			previousPos /= previousPos.w;
			
			// Use this frame's position and last frame's to compute the pixel velocity.
			// 使用这一帧的NDC坐标和前一帧的NDC坐标计算处速度
			float2 velocity = (currentPos.xy - previousPos.xy)/2.0f;
			
			// 使用该速度值对它的邻域像素进行采样，相加后取平均值得到一个模糊效果
			// 采样时使用_BlurSize来控制采样距离
			float2 uv = i.uv;
			float4 c = tex2D(_MainTex, uv);
			uv += velocity * _BlurSize;
			for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
				float4 currentColor = tex2D(_MainTex, uv);
				c += currentColor;
			}
			c /= 3;
			
			return fixed4(c.rgb, 1.0);
		}
		
		ENDCG
		
		Pass {      
			ZTest Always Cull Off ZWrite Off
			    	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
	} 

	// 这种实现会在片元着色器中进行矩阵乘法的操作，通常会影响游戏性能。

	FallBack Off
}
