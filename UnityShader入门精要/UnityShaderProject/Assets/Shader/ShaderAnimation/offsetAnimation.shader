Shader "MyShaders/offsetAnimation"{
    Properties{
        _MainTex("Main Texture", 2D) = "white"{}    // 用于uv偏移动画的贴图
        _XSpeed("X Axis Speed", Float) = 1.0    // x轴速度
        _YSpeed("Y Axis Speed", Float) = 1.0    // y轴速度
    }
    SubShader{
        pass{
            // 设置渲染路径
            Tags{"LightMode"="ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f{
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _XSpeed;
            float _YSpeed;

            v2f vert(appdata_base v){

                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            // 原理是基于图片的Repeat，不断偏移uv的采样坐标，但是还是由于Repeat的特性，它还是会回滚
            fixed4 frag(v2f i) : SV_TARGET{
                // 根据time和水平和纵向的偏移速度计算出x和y轴的偏移
                // float2 offset = float2(_Time.y * _XSpeed, _Time.y * _YSpeed);
                float2 offset = float2(0, _Time.y * _YSpeed);

                //设置偏移
                i.uv += offset;
                
                //采样
                return tex2D(_MainTex,i.uv);
            }
            ENDCG
        }
    }

}