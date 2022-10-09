Shader "MyShaders/GrabPassTest"{
    Properties{

    }
    SubShader{
        // 注意一点，使用GrabPass的时候，我们需要小心渲染队列的设置，GrabPass一般是用于透明的物体。所以渲染队列要设置为Transparent。
        // 这样摄像机抓屏幕的时候就不会把使用该Shader的模型拍进去
        Tags{"Queue"="Transparent" "RenderType"="Opaque"}

        GrabPass{"_GrabPassTexture"}

        pass{
            //不论什么情况下，这个pass总会被绘制
            Tags{"LightMode"="Always"}

            CGPROGRAM
            #pragma vertex Vertex
            #pragma fragment Pixel
            #include "UnityCG.cginc"

            sampler2D _GrabPassTexture;

            struct v2f{
                float4 pos : SV_POSITION;
                float2 uv :TEXCOORD0;
            };

            v2f Vertex(appdata_base v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            }

            fixed4 Pixel(v2f i):SV_TARGET{
                // 将抓取到的屏幕显示
                return tex2D(_GrabPassTexture, i.uv);
            }
            ENDCG
        }
    }
}