// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Edge Detection" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
	}
	SubShader {
		Pass {  
			// 屏幕后处理所需设置
			ZTest Always Cull Off ZWrite Off
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			
			#pragma vertex vert  
			#pragma fragment fragSobel
			
			sampler2D _MainTex;  
			uniform half4 _MainTex_TexelSize;	//_MainTex 的纹素( 1/纹理宽，1/纹理高，纹理宽，纹理高)
			fixed _EdgeOnly;					// float,half,fixed三种精度类型, float 32位; half 16位; fixed 11位;
			fixed4 _EdgeColor;
			fixed4 _BackgroundColor;
			
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv[9] : TEXCOORD0;	//使用Sobel边缘检测算子需要九个邻域纹理坐标(此处使用了九个插值器)
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				half2 uv = v.texcoord;
				
				// 通过把计算采样纹理坐标的代码从片元着色器转移到了顶点着色器中，可减少运算，提高性能。
				// 由于从顶点着色器到片元着色器的插值是线性的，所以转移不会影响纹理坐标计算结果。
				o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
				o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
				o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
				o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
				o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
				o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
				o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
				o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
				o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);
						 
				return o;
			}
			
			// 计算灰度值
			// 使用的是RGB转YUV的BT709明亮度转换公式，是基于人眼感知的图像灰度处理公式
			fixed luminance(fixed4 color) {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
			}
			
			// 计算当前像素的梯度值
			half Sobel(v2f i) {
				
				const half Gx[9] = {-1,  0,  1,		// 水平方向的卷积核
									-2,  0,  2,
									-1,  0,  1};

				const half Gy[9] = {-1, -2, -1,		// 竖直方向的卷积核(上一个卷积核的翻转)
									 0,  0,  0,
									 1,  2,  1};		
				
				half texColor;
				half edgeX = 0;	// 横向梯度值（如果左右两侧灰度变化比较大，那计算得到的梯度值的绝对值就越大，为负则表明左侧颜色深，为正则表明右侧颜色比较深；反之同理） 
				half edgeY = 0;	// 纵向梯度值（如果上下两边灰度变化比较大，那计算得到的梯度值的绝对值就越大，为负则表明上边颜色深，为正则表明下边颜色比较深；反之同理）
				for (int it = 0; it < 9; it++) {
					texColor = luminance(tex2D(_MainTex, i.uv[it]));
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}
				
				half edge = 1 - (abs(edgeX) + abs(edgeY)); // 出于性能考虑使用绝对值操作代替开根号
				
				// abs(edgeX) + abs(edgeY)的值越大越可能是边缘点
				// 所以edge越小越可能是边缘点
				return edge;
			}
			
			fixed4 fragSobel(v2f i) : SV_Target {
				half edge = Sobel(i);
				
				fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge); 	// 使用边缘因子对边缘颜色和图像颜色做插值
				fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);	// 使用边缘因子对边缘颜色和背景颜色做插值
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);	// 使用传入的边缘线强度来控制显示 图像+边缘 和 背景+边缘色
 			}
			
			ENDCG
		} 
	}
	FallBack Off
}
