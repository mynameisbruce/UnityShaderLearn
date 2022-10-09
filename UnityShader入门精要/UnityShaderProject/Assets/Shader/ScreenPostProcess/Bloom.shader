// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Bloom" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Bloom ("Bloom (RGB)", 2D) = "black" {}
		_LuminanceThreshold ("Luminance Threshold", Float) = 0.5
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _Bloom;
		float _LuminanceThreshold;
		float _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION; 
			half2 uv : TEXCOORD0;
		};	
		
		v2f vertExtractBright(appdata_img v) {
			v2f o;
			
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
					 
			return o;
		}
		
		// 计算灰度值
		fixed luminance(fixed4 color) {
			return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
		}
		
		// 将采样得到的亮度值减去阈值
		fixed4 fragExtractBright(v2f i) : SV_Target {
			fixed4 c = tex2D(_MainTex, i.uv);
			fixed val = clamp(luminance(c) - _LuminanceThreshold, 0.0, 1.0); // clamp(x, start, end), 把x值限制在起始值start和结束值end之间
			
			return c * val;
		}
		
		struct v2fBloom {
			float4 pos : SV_POSITION; 
			half4 uv : TEXCOORD0;
		};
		
		v2fBloom vertBloom(appdata_img v) {
			v2fBloom o;
			
			o.pos = UnityObjectToClipPos (v.vertex);
			o.uv.xy = v.texcoord;	// 将纹理坐标存到xy和zw
			o.uv.zw = v.texcoord;
			
			// 对坐标进行平台差异化处理
			// 在Direct3D平台下，如果我们开启了抗锯齿，则xxx_TexelSize.y会变成负值，好让我们能够正确的进行采样。 
			// 所以if (_MainTex_TexelSize.y < 0)的作用就是判断我们当前是否开启了抗锯齿。
			#if UNITY_UV_STARTS_AT_TOP			
			if (_MainTex_TexelSize.y < 0.0)
				o.uv.w = 1.0 - o.uv.w;
			#endif
				        	
			return o; 
		}
		
		fixed4 fragBloom(v2fBloom i) : SV_Target {
			return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom, i.uv.zw);	//模糊后的高亮纹理和原纹理混合
		} 
		
		ENDCG
		
		// 后处理标配
		ZTest Always Cull Off ZWrite Off
		
		// 取出高亮值
		Pass {  
			CGPROGRAM  
			#pragma vertex vertExtractBright  
			#pragma fragment fragExtractBright  
			
			ENDCG  
		}
		
		//对高亮区域进行竖直方向的高斯模糊
		UsePass "MyShaders/Gaussian Blur/GAUSSIAN_BLUR_VERTICAL"
		//对高亮区域进行水平方向的高斯模糊
		UsePass "MyShaders/Gaussian Blur/GAUSSIAN_BLUR_HORIZONTAL"
		

		// 混合
		Pass {  
			CGPROGRAM  
			#pragma vertex vertBloom  
			#pragma fragment fragBloom  
			
			ENDCG  
		}
	}
	FallBack Off
}
