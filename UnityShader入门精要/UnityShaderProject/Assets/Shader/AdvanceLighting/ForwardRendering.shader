// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 这个文件是描述前向渲染
Shader "MyShaders/Forward Rendering" {
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)	// 漫反射颜色
		_Specular ("Specular", Color) = (1, 1, 1, 1)	// 高光颜色
		_Gloss ("Gloss", Range(8.0, 256)) = 20	// 光泽度，值越大亮点区域越小
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		
		Pass {
			// Pass for ambient light & first pixel light (directional light)
			// 这个Pass用于环境光和第一个逐像素光照(也就是平行光)
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			// Apparently need to add this declaration 
			#pragma multi_compile_fwdbase	
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
			 	fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

			 	fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
			 	fixed3 halfDir = normalize(worldLightDir + viewDir);
			 	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

				fixed atten = 1.0;
				
				return fixed4(ambient + (diffuse + specular) * atten, 1.0);
			}
			
			ENDCG
		}
	
		Pass {
			// Pass for other pixel lights
			// 这个Pass用于显示其他的逐像素光照
			Tags { "LightMode"="ForwardAdd" }
			
			// 设置 Additional Pass 与 Base Pass 的混合方式   常见的还有 Blend SrcAlpha One
			// 一定要开启混合，设置线性混合，不然其他光源的光不能附加
			Blend One One
		
			CGPROGRAM
			
			// Apparently need to add this declaration
			// 一定要有这个编译指令, 保证获取的光照衰减等光照变量可以被正确赋值
			#pragma multi_compile_fwdadd
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"		// 包含unity_WorldToLight
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);

				// 如果是平行光，光源方向直接由_WorldSpaceLightPos0.xyz得到
				// 如果是点光源或聚光灯，_WorldSpaceLightPos0.xyz表示世界空间下的光源位置，光源方向是光源位置减去顶点位置
				// 此处直接用unity的UnityWorldSpaceLightDir代替
				// #ifdef USING_DIRECTIONAL_LIGHT
				// 		fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				// #else
				// 		fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				// #endif
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));
				
				// 视角方向是摄像机的位置减去顶点位置
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				// 计算光照衰减
				// 如果是平行光，那么不会衰减，值为1.0
				// 如果为其它光源类型，计算光照衰减往往涉及大量计算，因此unity选择了使用一张纹理作为查找表以在片源着色器中得到光源的衰减。只需要得到光源空间下的坐标，然后使用该坐标对衰减纹理采样即可得到衰减值
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed atten = 1.0;
				#else
					#if defined (POINT)		// 点光源
						// 把点坐标转换到点光源的坐标空间中
						// 经过unity_WorldToLight变换(包含对点光源范围的计算)后，在点光源中心处lightCoord为(0, 0, 0)，在点光源的范围边缘处lightCoord模为1
				        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
						// 使用点到光源中心距离的平方dot(lightCoord, lightCoord)构成二维采样坐标，对衰减纹理_LightTexture0采样
						// UNITY_ATTEN_CHANNEL是衰减值所在的纹理通道，可以在内置的HLSLSupport.cginc文件中查看。一般PC和主机平台的话UNITY_ATTEN_CHANNEL是r通道，移动平台的话是a通道
				        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #elif defined (SPOT)	// 聚光灯
						// 把点坐标转换到聚光灯的坐标空间中
						// 经过unity_WorldToLight变换(包含对聚光灯范围的计算)后，在聚光灯光源中心处或聚光灯范围外的lightCoord为(0, 0, 0)，在聚光灯的范围边缘处lightCoord模为1
				        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
						// 与点光源不同，由于聚光灯有更多的角度等要求，因此为了得到衰减值，除了需要对衰减纹理采样外，还需要对聚光灯的范围、张角和方向进行判断
						// 此时衰减纹理存储到了_LightTextureB0中，这张纹理和点光源中的_LightTexture0是等价的
						// 聚光灯的_LightTexture0存储的不再是基于距离的衰减纹理，而是一张基于张角范围的衰减纹理
				        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #else
				        fixed atten = 1.0;
				    #endif

					// // 先计算距离
					// float _distance = distance(_WorldSpaceLightPos0.xyz, i.worldPos);
					// // 通过反比例函数计算衰减
					// fixed atten = 1.0 / _distance;
				#endif

				return fixed4((diffuse + specular) * atten, 1.0);
			}

			/*
				上面采样衰减纹理的地方，dot(lightCoord, lightCoord).rr中dot(lightCoord, lightCoord)计算出来是一个模的平方的值，设为result = ｜lightCoord｜^2
				然后.rr的操作是shader中的swizzling操作，会变成float2(result, result)
				综上：使用距离的平方（避免开方）对衰减纹理采样，得到衰减值
				
				注意：点光源的衰减纹理存储在_LightTexture0；而聚光灯的衰减纹理存储在_LightTextureB0，聚光灯的光照cookie(阴影贴图)储存在_LightTexture0

				上面采样聚光灯的地方(lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * ...
				(lightCoord.z > 0)的判断式自己测试出来的结果是如果是true就是1，如果是false就是0
				(lightCoord.z > 0)代表的意思是光源坐标系中，lightCoord的z值大于0才会显示，通过测试得知lightCoord的z值是个比例值(0-1之间)，如果设置成>0.5就说明大于聚光灯范围值的一半才会显示
				tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w这个是采样光照cookie, 具体逻辑分析有待思考

				QUESTION
				对衰减纹理的采样，用到的uv坐标是float2(result, result)，这个是属于对对角线进行采样。
				然后这个衰减纹理只是在横轴上有变换，采样的时候为什么要使用对角线采样，而不是直接只使用横轴坐标采样呢？( 比如直接横坐标轴采样tex2D(_LightTexture0, float2(result, 0)) )
				网上搜索答案是 “因为对角线要比横轴要长，理论上，对对角线进行采样的话，会得到一个更加平滑的过渡”
				但我个人看法是其实tex2D(_LightTexture0, float2(result, result))和tex2D(_LightTexture0, float2(result, 0))没区别(坐等以后更新知识)
				我觉得是替换横纵轴都会变化的衰减纹理(或者之前的渐变纹理)的时候就是用对角线采样，所以一步写好不用去改代码
			*/
			
			ENDCG
		}
	}
	FallBack "Specular"
}
