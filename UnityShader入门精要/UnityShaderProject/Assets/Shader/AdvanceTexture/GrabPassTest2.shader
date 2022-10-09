Shader "MyShaders/GrabPassTest2"{
    Properties{
        _Color("Color Hint", Color) = (1,1,1,1)
    }
    SubShader{
        // 注意一点，使用GrabPass的时候，我们需要小心渲染队列的设置，GrabPass一般是用于透明的物体。所以渲染队列要设置为Transparent。
        // 这样摄像机抓屏幕的时候就不会把使用该Shader的模型拍进去
        Tags{"Queue"="Transparent" "RenderType"="Opaque"}

        GrabPass{"_GrabPassTexture"}

        pass{
            //不论什么情况下，这个pass总会被绘制
            Tags{"LightMode" = "Always"}

            CGPROGRAM
            #pragma vertex Vertex
            #pragma fragment Pixel
            #include "UnityCG.cginc"

            fixed3 _Color;
            sampler2D _GrabPassTexture;

            struct v2f{
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
            };

            v2f Vertex(appdata_base v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeGrabScreenPos(o.pos);
                return o;
            }

            fixed4 Pixel(v2f i):SV_TARGET{
                // 对屏幕坐标进行其次除法
                fixed3 color = tex2D(_GrabPassTexture, i.scrPos.xy / i.scrPos.w).xyz * _Color.xyz;
                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
}