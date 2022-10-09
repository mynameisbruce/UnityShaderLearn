Shader "MyShaders/frameAnimation"{
    Properties{
        _MainTex ("Animation Texture", 2D) = "white" {}     // 帧纹理
        _BaseColor ("BaseColor", Color) = (1.0, 1.0, 1.0, 1.0)  // 基础颜色
        _XCount ("XCount", Int) = 1     // 水平方向关键帧图像个数
        _YCount ("YCount", Int) = 1     // 竖直方向关键帧图像个数
        _Speed ("Speed", Range(1, 100)) = 30    // 控制播放速度
    }
    SubShader{
        // 由于该序列帧图像包含了透明通道，所以Queue(渲染队列)和RenderType(渲染类型)都设置成Transparent
        // IgnoreProjector设置成True，意味者不会受到投影器(Projector)的影响
        Tags{"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}

        pass{
            // 设置渲染路径
            Tags{"LightMode"="ForwardBase"}

            ZWrite Off                          // 关闭深度写入
            Blend SrcAlpha OneMinusSrcAlpha     // 开启混合

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
            fixed4 _BaseColor;
            int _XCount;
            int _YCount;
            float _Speed;

            v2f vert(appdata_base v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }
            
            fixed4 frag(v2f i) : SV_TARGET{
                // 将时间乘上我们指定的缩放，这样就可以控制播放速度了
                float time = floor(_Time.y * _Speed);
                
                //计算出在time时刻的行索引与列索引
                float ypos = floor(time / _XCount);    
                float xpos = time - ypos * _XCount;

                //根据我们刚才计算出来的公式进行uv坐标的偏移和缩放
                i.uv.x = (i.uv.x + xpos) / _XCount;
                i.uv.y = 1 - (ypos + 1 - i.uv.y) / _YCount;

                fixed4 c = tex2D(_MainTex, i.uv);
                return c * _BaseColor;

                // 推演一下
                /* 若time = 30, _XCount = 8, _YCount = 8
                   则ypos = floor(30 / 8) = 3, xpos = 30 - 3 * 8 = 6
                   i.uv.x 未计算前是[0,1]范围的，计算后是[6/8,7/8]范围内
                   i.uv.y 未计算前是[0,1]范围的，计算后是[1 - 4/8,1 - 3/8] = [3/8, 4/8]范围
                   通过i.uv采样_MainTex上的帧图片块

                   注意：如果time较大，比如是90，求出ypos超过8，那么就会取得ypos=11, 由于帧图片设置Wrap Mode为Repeat, 
                   所以采样超过范围会取到重复的纹理，所以和ypos=3的效果是一样的
                */
            }
            ENDCG
        }
    }
}