Shader "MyShaders/vertexAnimation"{
    Properties{
        _MainTex("Main Texture", 2D) = "white"{}    // 用于顶点偏移动画的贴图
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
            float _XSpeed;
            float _YSpeed;

            v2f vert(appdata_base v){

                v2f o;
                // // 根据时间变化计算出顶点y轴的偏移
                // v.vertex.y += sin(_Time.y);   
                // // 根据时间变化和顶点x值与速度乘积计算出顶点y值的偏移
                // v.vertex.y += sin(_Time.y + v.vertex.x * _XSpeed);
                // // 根据时间变化和顶点x、z值与速度乘积计算出顶点y值的偏移
                v.vertex.y += sin(_Time.y + v.vertex.x * _XSpeed + v.vertex.z * _YSpeed);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

            fixed4 frag(v2f i):SV_TARGET{

                return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
    }

}