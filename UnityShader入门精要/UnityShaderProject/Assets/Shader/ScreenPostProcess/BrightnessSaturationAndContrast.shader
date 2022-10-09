// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Brightness Saturation And Contrast" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Brightness ("Brightness", Float) = 1	// 亮度
		_Saturation("Saturation", Float) = 1	// 饱和度
		_Contrast("Contrast", Float) = 1		// 对比度
	}
	SubShader {
		Pass {
			// 屏幕后处理实际上是在场景中绘制一个和屏幕同高同宽的四边形面片
			// 关闭了深度写入是为了防止它"挡住"后面被渲染的物体。
			// 例如，如果当前的OnRenderImage函数是在所有不透明的Pass执行完之后立即调用，不关闭深度写入会影响后面透明的Pass的渲染
			// 使用该shader的物体都会一直绘制在最前面
			ZTest Always 	// 深度测试总是通过(也就是一定会绘制的意思)
			Cull Off 		// 关闭剔除(节省cull的开销，因为后处理是一定是正对相机的，不需要剔除)
			ZWrite Off		// 不需要深度写入(避免影响后续渲染)
			
			CGPROGRAM  
			#pragma vertex vert  
			#pragma fragment frag  
			  
			#include "UnityCG.cginc"  
			  
			sampler2D _MainTex;  
			half _Brightness;	// float,half,fixed三种精度类型, float 32位; half 16位; fixed 11位;
			half _Saturation;
			half _Contrast;
			  
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv: TEXCOORD0;
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 纹理坐标直接传入片元着色器，因为不会缩放和偏移
				o.uv = v.texcoord;
						 
				return o;
			}
		
			// 亮度调整是对图片的rgb通道的值进行缩放
			// 饱和度和对比度是对图片的rgb与设定的值进行插值
			fixed4 frag(v2f i) : SV_Target {
				fixed4 renderTex = tex2D(_MainTex, i.uv);  
				  
				// Apply brightness
				// 亮度调整
				fixed3 finalColor = renderTex.rgb * _Brightness;
				
				// Apply saturation
				// 饱和度调整   使用的是RGB转YUV的BT709明亮度转换公式，是基于人眼感知的图像灰度处理公式
				// YUV:  Y表示明亮度(Luminance/Luma), 也称灰度值(灰阶值). UV表示色度(Chrominance/Chroma)
				fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
				fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
				finalColor = lerp(luminanceColor, finalColor, _Saturation);

				// Apply contrast
				// 对比度调整
				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
				finalColor = lerp(avgColor, finalColor, _Contrast);
				
				return fixed4(finalColor, renderTex.a);  

				// CG中的lerp函数和GLSL中的mix函数相同
				// lerp为线性插值函数，lerp(a, b, w) ==> return a * (1 - w) + b * w
			}
			  
			ENDCG
		}  
	}
	
	// 关闭Fallback，SubShader不支持渲染则不渲染
	Fallback Off
}
