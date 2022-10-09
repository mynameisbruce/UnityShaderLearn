// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShaders/Dissolve" {
	Properties {
		_BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0			// 控制消融程度，当值为0时为正常效果，当值为1时物体完全消融
		_LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1		// 控制模拟烧焦效果时的线宽，它的值越大，消融范围越广
		_MainTex ("Base (RGB)", 2D) = "white" {}					// 物体的纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}						// 物体的法线纹理
		_BurnFirstColor("Burn First Color", Color) = (1, 0, 0, 1)	// 火焰边缘处的第一种颜色
		_BurnSecondColor("Burn Second Color", Color) = (1, 0, 0, 1)	// 火焰边缘处的第二种颜色
		_BurnMap("Burn Map", 2D) = "white"{}						// 噪声纹理
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }

			// 关闭剔除，因为正背面都需要被渲染
			Cull Off
			
			CGPROGRAM
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed _BurnAmount;
			fixed _LineWidth;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			fixed4 _BurnFirstColor;
			fixed4 _BurnSecondColor;
			sampler2D _BurnMap;
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _BurnMap_ST;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uvMainTex : TEXCOORD0;
				float2 uvBumpMap : TEXCOORD1;
				float2 uvBurnMap : TEXCOORD2;
				float3 lightDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
				SHADOW_COORDS(5)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				//TANGENT_SPACE_ROTATION指的就是计算切线，副切线，法线等一大堆操作。
                //由于它是一个宏，它会声明一个rotation来计算，所以我们这里引用rotation即可
                //rotation就是切线空间转换矩阵
				TANGENT_SPACE_ROTATION;

				// 将模型空间的光线向量转换到切线空间(PS:这里rotation由转换到世界空间下的法线切线构建旋转矩阵比较好，可以处理非统一缩放问题)
  				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
  				
  				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
  				
  				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// 从噪声纹理中采样颜色
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
				// 透明度测试，如果burn的r通道小于_BurnAmount则此片元会被舍弃
				clip(burn.r - _BurnAmount);
				
				float3 tangentLightDir = normalize(i.lightDir);
				// 从法线贴图取出切线空间下的法线
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));
				
				// 采样纹理得到材质反射率
				fixed3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
				
				// 计算环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 计算漫反射光(兰伯特模型)
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				// 在宽度为_LineWidth的范围内模拟一个烧焦颜色burnColor
				// 第一步使用smoothstep来计算混合系数t
				// 当t为1时为消融的边界处，当t为0时，表明该像素为正常的模型颜色，而中间的插值表示需要模拟一个烧焦效果
				fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
				// 使用t对两种火焰颜色进行插值混合
				fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
				// 使用指数来计算颜色，颜色值是[0,1]之间，burnColor以指数级减弱
				burnColor = pow(burnColor, 5);
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				// 使用t对正常的光照颜色和烧焦颜色进行混合
				// step(0.0001, _BurnAmount)用来控制_BurnAmount = 0时确保能完全显示正常的光照颜色
				fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, t * step(0.0001, _BurnAmount));
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
		
		// Pass to render object as a shadow caster
		// 自定义一个用于投射阴影的Pass
		Pass {
			Tags { "LightMode" = "ShadowCaster" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"
			
			fixed _BurnAmount;
			sampler2D _BurnMap;
			float4 _BurnMap_ST;
			
			struct v2f {
				V2F_SHADOW_CASTER;	// 定义阴影投射需要的变量
				float2 uvBurnMap : TEXCOORD1;
			};
			
			v2f vert(appdata_base v) {
				v2f o;
				
				// 计算阴影投射时需要的各种变量
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				
				// 使用纹理属性对顶点纹理坐标进行变换，得到最终的纹理坐标
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				// 从噪声纹理中采样颜色
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
				// 一样进行透明度测试
				clip(burn.r - _BurnAmount);
				
				// 完成投射阴影的部分
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
